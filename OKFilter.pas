unit OKFilter;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  DB, DBTables;

type
    TOKFCondition = class
    private
        function Check (DataSet: TDataSet): Boolean; virtual;
        procedure SetRangeStart (DataSet: TDataSet); virtual;
        procedure SetRangeEnd (DataSet: TDataSet); virtual;
        function FindRangeCondition (aFieldName: string): TOKFCondition;
            virtual;
    public
        function Copy: TOKFCondition; virtual;
    end;

    TOKFBinaryOp = class (TOKFCondition)
    private
        First, Second: TOKFCondition;
        constructor Create (theFirst, theSecond: TOKFCondition);
    public
        destructor Destroy; override;
    end;

type
    TOKFConjunction = class (TOKFBinaryOp)
    private
        function Check (DataSet: TDataSet): Boolean; override;
        function FindRangeCondition (aFieldName: string): TOKFCondition;
            override;
    public
        function Copy: TOKFCondition; override;
    end;

    function OKFAnd (First, Second: TOKFCondition): TOKFCondition;

type
    TOKFDisjunction = class (TOKFBinaryOp)
    private
        function Check (DataSet: TDataSet): Boolean; override;
    public
        function Copy: TOKFCondition; override;
    end;

    function OKFOr (First, Second: TOKFCondition): TOKFCondition;

type
    TOKFValueRestriction = class (TOKFCondition)
    private
        function Check (DataSet: TDataSet): Boolean; override;
        procedure SetRangeStart (DataSet: TDataSet); override;
        procedure SetRangeEnd (DataSet: TDataSet); override;
        function FindRangeCondition (aFieldName: string): TOKFCondition;
            override;
    public
        FieldName: string;
        Value: Variant;
        constructor Create (aFieldName: string; aValue: Variant);
        function Copy: TOKFCondition; override;
    end;

    TOKFRangeRestriction = class (TOKFCondition)
    private
        function Check (DataSet: TDataSet): Boolean; override;
        procedure SetRangeStart (DataSet: TDataSet); override;
        procedure SetRangeEnd (DataSet: TDataSet); override;
        function FindRangeCondition (aFieldName: string): TOKFCondition;
            override;
    public
        FieldName: string;
        LowLimit, HighLimit: Variant;
        constructor Create (aFieldName: string; aLowLimit, aHighLimit: Variant);
        function Copy: TOKFCondition; override;
    end;

type
    TOkDBFilter = class(TComponent)
    private
        FDataSet: TDataSet;
        FEnabled: Boolean;
        SavedFilterEvent: TFilterRecordEvent;
        FCondition: TOKFCondition;
        procedure SetDataSet (NewDataSet: TDataSet);
        procedure SetEnabled (NewState: Boolean);
        function GetCondition: TOKFCondition;
        procedure SetCondition (NewCondition: TOKFCondition);
        procedure SetRange;
        procedure OurFilterEvent (aDataSet: TDataSet; var Accept: Boolean);
    public
        constructor Create (anOwner: TComponent); override;
        destructor Destroy; override;
        procedure Clear;
        procedure Refresh;
        property Condition: TOKFCondition read GetCondition write SetCondition;
    published
        property DataSet: TDataSet read FDataSet write SetDataSet;
        property Enabled: Boolean read FEnabled write SetEnabled default true;
    end;

procedure Register;

implementation

procedure Register;
begin
    RegisterComponents('Oleg0k''s Components', [TOkDBFilter]);
end;


function TOKFCondition.Check (DataSet: TDataSet): Boolean;
begin
    Result := true;
end;


procedure TOKFCondition.SetRangeStart (DataSet: TDataSet);
begin
end;


procedure TOKFCondition.SetRangeEnd (DataSet: TDataSet);
begin
end;


function TOKFCondition.FindRangeCondition (aFieldName: string): TOKFCondition;
begin
    Result := nil;
end;


function TOKFCondition.Copy: TOKFCondition;
begin
    Result := TOKFCondition.Create;
end;


constructor TOKFBinaryOp.Create (theFirst, theSecond: TOKFCondition);
begin
    inherited Create;
    First := theFirst;
    Second := theSecond;
end;


destructor TOKFBinaryOp.Destroy;
begin
    First.Free;
    Second.Free;
    inherited Destroy;
end;


function TOKFConjunction.Check (DataSet: TDataSet): Boolean;
begin
    Result := First.Check(DataSet) and Second.Check(DataSet);
end;


function TOKFConjunction.FindRangeCondition (aFieldName: string): TOKFCondition;
begin
    Result := First.FindRangeCondition(aFieldName);
    if Result = nil then
        Result := Second.FindRangeCondition(aFieldName);
end;


function TOKFConjunction.Copy: TOKFCondition;
begin
    Result := OKFAnd (First.Copy, Second.Copy);
end;


function OKFAnd (First, Second: TOKFCondition): TOKFCondition;
begin
    Result := TOKFConjunction.Create (First, Second);
end;


function TOKFDisjunction.Check (DataSet: TDataSet): Boolean;
begin
    Result := First.Check(DataSet) or Second.Check(DataSet);
end;


function TOKFDisjunction.Copy: TOKFCondition;
begin
    Result := OKFOr (First.Copy, Second.Copy);
end;


function OKFOr (First, Second: TOKFCondition): TOKFCondition;
begin
    Result := TOKFDisjunction.Create (First, Second);
end;


constructor TOKFValueRestriction.Create (aFieldName: string; aValue: Variant);
begin
    inherited Create;
    FieldName := aFieldName;
    Value := aValue;
end;


function TOKFValueRestriction.Check (DataSet: TDataSet): Boolean;
var Field: TField;
begin
    Field := DataSet.FieldByName(FieldName);
    case Field.DataType of
    ftInteger, ftSmallInt, ftWord, ftAutoInc:
        Result := Field.AsInteger = Value;
    ftString, ftMemo, ftFmtMemo:
        Result := Field.AsString = Value;
    ftBoolean:
        Result := Field.AsBoolean = Value;
    ftFloat, ftBCD:
        Result := Field.AsFloat = Value;
    ftCurrency:
        Result := Field.AsCurrency = Value;
    ftDate, ftTime, ftDateTime:
        Result := Field.AsDateTime = Value;
    else
        Result := true;
    end;//case
end;


procedure TOKFValueRestriction.SetRangeStart (DataSet: TDataSet);
var Field: TField;
begin
    Field := DataSet.FieldByName(FieldName);
    case Field.DataType of
    ftInteger, ftSmallInt, ftWord, ftAutoInc:
        Field.AsInteger := Value;
    ftString:
        Field.AsString := Value;
    ftBoolean:
        Field.AsBoolean := Value;
    ftFloat, ftBCD:
        Field.AsFloat := Value;
    ftCurrency:
        Field.AsCurrency := Value;
    ftDate, ftTime, ftDateTime:
        Field.AsDateTime := Value;
    end;//case
end;


procedure TOKFValueRestriction.SetRangeEnd (DataSet: TDataSet);
begin
    SetRangeStart (DataSet);
end;


function TOKFValueRestriction.FindRangeCondition (aFieldName: string):
    TOKFCondition;
begin
    if CompareText(FieldName, aFieldName) = 0 then
        Result := self
    else
        Result := nil;
end;


function TOKFValueRestriction.Copy: TOKFCondition;
begin
    Result := TOKFValueRestriction.Create (FieldName, Value);
end;


constructor TOKFRangeRestriction.Create (aFieldName: string;
                                         aLowLimit, aHighLimit: Variant);
begin
    inherited Create;
    FieldName := aFieldName;
    LowLimit := aLowLimit;
    HighLimit := aHighLimit;
end;


function TOKFRangeRestriction.Check (DataSet: TDataSet): Boolean;
var Field: TField;
begin
    Field := DataSet.FieldByName(FieldName);
    case Field.DataType of
    ftInteger, ftSmallInt, ftWord, ftAutoInc:
        Result := (Field.AsInteger >= LowLimit) and
                  (Field.AsInteger <= HighLimit);
    ftString, ftMemo, ftFmtMemo:
        Result := (Field.AsString >= LowLimit) and
                  (Field.AsString <= HighLimit);
    ftBoolean:
        Result := (Field.AsBoolean >= LowLimit) and
                  (Field.AsBoolean <= HighLimit);
    ftFloat, ftBCD:
        Result := (Field.AsFloat >= LowLimit) and
                  (Field.AsFloat <= HighLimit);
    ftCurrency:
        Result := (Field.AsCurrency >= LowLimit) and
                  (Field.AsCurrency <= HighLimit);
    ftDate, ftTime, ftDateTime:
        Result := (Field.AsDateTime >= LowLimit) and
                  (Field.AsDateTime <= HighLimit);
    else
        Result := true;
    end;//case
end;


procedure TOKFRangeRestriction.SetRangeStart (DataSet: TDataSet);
var Field: TField;
begin
    Field := DataSet.FieldByName(FieldName);
    case Field.DataType of
    ftInteger, ftSmallInt, ftWord, ftAutoInc:
        Field.AsInteger := LowLimit;
    ftString:
        Field.AsString := LowLimit;
    ftBoolean:
        Field.AsBoolean := LowLimit;
    ftFloat, ftBCD:
        Field.AsFloat := LowLimit;
    ftCurrency:
        Field.AsCurrency := LowLimit;
    ftDate, ftTime, ftDateTime:
        Field.AsDateTime := LowLimit;
    end;//case
end;


procedure TOKFRangeRestriction.SetRangeEnd (DataSet: TDataSet);
var Field: TField;
begin
    Field := DataSet.FieldByName(FieldName);
    case Field.DataType of
    ftInteger, ftSmallInt, ftWord, ftAutoInc:
        Field.AsInteger := HighLimit;
    ftString:
        Field.AsString := HighLimit;
    ftBoolean:
        Field.AsBoolean := HighLimit;
    ftFloat, ftBCD:
        Field.AsFloat := HighLimit;
    ftCurrency:
        Field.AsCurrency := HighLimit;
    ftDate, ftTime, ftDateTime:
        Field.AsDateTime := HighLimit;
    end;//case
end;


function TOKFRangeRestriction.FindRangeCondition (aFieldName: string):
    TOKFCondition;
begin
    if CompareText(FieldName, aFieldName) = 0 then
        Result := self
    else
        Result := nil;
end;


function TOKFRangeRestriction.Copy: TOKFCondition;
begin
    Result := TOKFRangeRestriction.Create (FieldName, LowLimit, HighLimit);
end;


constructor TOkDBFilter.Create (anOwner: TComponent);
begin
    inherited Create (anOwner);
    FDataSet := nil;
    SavedFilterEvent := nil;
    FCondition := nil;
    FEnabled := true;
end;


procedure TOkDBFilter.SetDataSet (NewDataSet: TDataSet);
begin
    FDataSet := NewDataSet;
    if not (csDesigning in ComponentState) then begin
        SavedFilterEvent := FDataSet.OnFilterRecord;
        FDataSet.OnFilterRecord := OurFilterEvent;
    end;//if
end;


procedure TOkDBFilter.SetEnabled (NewState: Boolean);
begin
    FEnabled := NewState;
    if not (csDesigning in ComponentState) then
        Refresh;
end;


procedure TOkDBFilter.OurFilterEvent (aDataSet: TDataSet; var Accept: Boolean);
begin
    Accept := true;
    if Assigned(SavedFilterEvent) then
        SavedFilterEvent (aDataSet, Accept);
    if not Accept then
        Exit;
    if FEnabled and (FCondition <> nil) then
        Accept := FCondition.Check(FDataSet);
end;


procedure TOkDBFilter.Clear;
begin
    if FCondition <> nil then
        FCondition.Free;
    FCondition := nil;

    if FDataSet is TTable then
        TTable(FDataSet).CancelRange;

    FDataSet.Refresh;
end;


function TOkDBFilter.GetCondition: TOKFCondition;
begin
    Result := FCondition;
end;


procedure TOkDBFilter.SetCondition (NewCondition: TOKFCondition);
begin
    if FCondition <> nil then
        FCondition.Free;
    FCondition := NewCondition;

    if FEnabled and (FDataSet is TTable) then
        SetRange;

    FDataSet.Refresh;
end;


procedure TOkDBFilter.Refresh;
begin
    if not Assigned(FDataSet) then
        Exit;

    if FDataSet is TTable then begin
        TTable(FDataSet).CancelRange;
        if FEnabled then
            SetRange;
    end;//if

    FDataSet.Refresh;
end;


procedure TOkDBFilter.SetRange;
var I: Integer; RangeCondition: TOKFCondition;
begin
    if FCondition = nil then
        Exit;

    TTable(FDataSet).SetRangeStart;
    for I := 0 to TTable(FDataSet).IndexFieldCount - 1 do begin
        RangeCondition := FCondition.FindRangeCondition(
            TTable(FDataSet).IndexFields[I].FieldName);
        if RangeCondition = nil then
            Break;
        RangeCondition.SetRangeStart(FDataSet);
    end;//do

    if I = 0 then begin
        TTable(FDataSet).CancelRange;
        Exit;
    end;

    TTable(FDataSet).KeyExclusive := false;
    TTable(FDataSet).SetRangeEnd;

    for I := 0 to TTable(FDataSet).IndexFieldCount - 1 do begin
        RangeCondition := FCondition.FindRangeCondition(
            TTable(FDataSet).IndexFields[I].FieldName);
        if RangeCondition <> nil then
            RangeCondition.SetRangeEnd(FDataSet)
        else
            with TTable(FDataSet).IndexFields[I] do
                case DataType of
                ftInteger, ftAutoInc:
                    AsInteger := High(Integer);
                ftSmallInt:
                    AsInteger := High(SmallInt);
                ftWord:
                    AsInteger := High(Word);
                ftString:
                    AsString := High(Char) + High(Char) + High(Char);
                ftBoolean:
                    AsBoolean := High(Boolean);
                ftFloat, ftBCD:
                    AsFloat := High(Integer);
                ftCurrency:
                    AsCurrency := High(Integer);
                ftDate, ftTime, ftDateTime:
                    AsDateTime := EncodeDate(9999, 12, 31);
                end;//case
    end;//do

    TTable(FDataSet).KeyExclusive := false;
    TTable(FDataSet).ApplyRange;
end;


destructor TOkDBFilter.Destroy;
begin
    if not (csDesigning in ComponentState) then
        FDataSet.OnFilterRecord := SavedFilterEvent;
    FCondition.Free;
    inherited;
end;

end.
