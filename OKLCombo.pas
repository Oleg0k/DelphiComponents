unit OKLCombo;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  DBCtrls, DB, DBTables, DesignEditors, DesignIntf, Consts, Typinfo;

type
  TOKDBLookupComboBox = class(TDBLookupComboBox)
  private
    FHintField: string;
    LDataSet: TDataSet;
    DField, HField: TField;
    SavedDataWatcher: TDataChangeEvent;
    FOnReferenceCall: TNotifyEvent;
    procedure OurDataWatcher (Sender: TObject; Field: TField);

    procedure DisplayHintField;
    procedure SetHintField (NewHintField: string);
    procedure SetHField;
  protected
    procedure Paint; override;
    procedure KeyDown (var Key: Word; Shift: TShiftState); override;
    procedure DblClick; override;
  public
    constructor Create (anOwner: TComponent); override;
    destructor Destroy; override;
  published
    property HintField: string read FHintField write SetHintField;
    property OnReferenceCall: TNotifyEvent read FOnReferenceCall
                                           write FOnReferenceCall;
  end;

  THintFieldProperty = class(TPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetValue: string; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const Value: string); override;
  end;

procedure Register;

implementation

procedure Register;
begin
    RegisterComponents('Oleg0k''s Components', [TOKDBLookupComboBox]);
    RegisterPropertyEditor(TypeInfo(string), TOKDBLookupComboBox,
                           'HintField', THintFieldProperty);
end;


constructor TOKDBLookupComboBox.Create (anOwner: TComponent);
begin
    inherited Create (anOwner);
    ControlStyle := ControlStyle + [csClickEvents, csDoubleClicks];
    SavedDataWatcher := nil;
    ShowHint := true;
    LDataSet := nil;
    DField := nil;
    HField := nil;
end;


procedure TOKDBLookupComboBox.Paint;
begin
    inherited Paint;

    if not (csDesigning in ComponentState) and
       not Assigned(SavedDataWatcher) then begin
        if Assigned(DataSource) then begin
            SavedDataWatcher := DataSource.OnDataChange;
            DataSource.OnDataChange := OurDataWatcher;
        end;//if
        SetHField;
        DisplayHintField;
    end;//if
end;


procedure TOKDBLookupComboBox.SetHintField (NewHintField: string);
begin
    FHintField := NewHintField;
end;


procedure TOKDBLookupComboBox.SetHField;
begin
    LDataSet := nil;
    DField := nil;
    HField := nil;

    if Assigned(DataSource) then begin
        try
            DField := DataSource.DataSet.FieldByName(DataField);
        except
            on EDataBaseError do Exit;
        end;

        if DField.Lookup then
            LDataSet := DField.LookupDataSet;
    end;//if

    if (LDataSet = nil) and Assigned(ListSource) then
        LDataSet := ListSource.DataSet;

    if LDataSet <> nil then
        try
            HField := LDataSet.FieldByName(FHintField);
        except
            on EDataBaseError do Exit;
        end;
end;


procedure TOKDBLookupComboBox.OurDataWatcher (Sender: TObject; Field: TField);
begin
    if Assigned(SavedDataWatcher) then
        SavedDataWatcher (Sender, Field);
    DisplayHintField;
end;


procedure TOKDBLookupComboBox.DisplayHintField;
begin
    if HField <> nil then begin
        if not LDataSet.Active then
            LDataSet.Open;

        if DField.Lookup and Assigned(DField.LookupDataSet) then
            LDataSet.Locate (DField.LookupKeyFields,
                DField.DataSet.FieldByName(DField.KeyFields).Value,
                [])
        else
            LDataSet.Locate (KeyField, DField.Value, []);
        Hint := HField.AsString;
    end;//if
end;


procedure TOKDBLookupComboBox.KeyDown (var Key: Word; Shift: TShiftState);
begin
    inherited KeyDown (Key, Shift);
    if (Key = VK_RETURN) and not ListVisible and Assigned(FOnReferenceCall) then
        FOnReferenceCall (self);
end;


procedure TOKDBLookupComboBox.DblClick;
begin
    inherited DblClick;
    if Assigned(FOnReferenceCall) then begin
        FOnReferenceCall (self);
        CloseUp (false);
    end;//if
end;


destructor TOKDBLookupComboBox.Destroy;
begin
    if not (csDesigning in ComponentState) and Assigned(DataSource) then
        DataSource.OnDataChange := SavedDataWatcher;
    inherited;
end;


{"HintField" on property editor methods}
function THintFieldProperty.GetAttributes: TPropertyAttributes;
begin
    Result := [paValueList];
end;


function THintFieldProperty.GetValue: string;
begin
    Result := GetStrValue;
end;


procedure THintFieldProperty.GetValues(Proc: TGetStrProc);
var I: Integer;
begin
    with TOKDBLookupComboBox(GetComponent(0)) do begin
        SetHField;

        if LDataSet <> nil then
            for I := 0 to LDataSet.FieldCount - 1 do
                Proc(LDataSet.Fields[I].FieldName);
    end;//with
end;

procedure THintFieldProperty.SetValue(const Value: string);
var I: Integer;
begin
    if (Value = '') then begin
        SetStrValue('');
        Exit;
    end;

    with TOKDBLookupComboBox(GetComponent(0)) do begin
        SetHField;
        if LDataSet <> nil then
            for I := 0 to LDataSet.FieldCount - 1 do
                if CompareText(LDataSet.Fields[I].FieldName,
                               Value) = 0 then begin
                    SetStrValue(Value);
                    Exit;
                end;
    end;//with

    raise EPropertyError.Create('Invalid Property Value');
//    raise EPropertyError.Create(SInvalidPropertyValue);
end;


end.
