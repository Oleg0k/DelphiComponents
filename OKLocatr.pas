{***************************************************************************
*                       DataBase Locator Component                         *
****************************************************************************}


unit OKLocatr;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, DB, DBTables, DBGrids,  DesignEditors, DesignIntf, Consts, Typinfo;

type
  TLocatorSearchMethod = (lsmIndex, lsmSequential, lsmBoth);
  TSearchFrom = (sfromFirst, sfromCurrent, sfromNext);

  TOKDBLocator = class(TCustomEdit)
  private
    FGrid: TDBGrid;
    FKeyField: string;
    FSearchMethod: TLocatorSearchMethod;
    Persist, GetReady: Boolean;
    SavedKeyHandler: TKeyEvent;
    SavedCharHandler: TKeyPressEvent;
    SavedDataWatcher: TDataChangeEvent;
    SavedColWatcher: TNotifyEvent;
    SavedExitWatcher: TNotifyEvent;
    procedure SetGrid (NewGrid: TDBGrid);
    procedure SetKeyField (NewKeyField: string);
    procedure SetSearchMethod (NewSearchMethod: TLocatorSearchMethod);
    procedure OurKeyHandler (Sender: TObject; var Key: Word;
                             Shift: TShiftState);
    procedure OurCharHandler (Sender: TObject; var Key: Char);
    procedure OurDataWatcher (Sender: TObject; Field: TField);
    procedure OurColWatcher (Sender: TObject);
    procedure OurExitWatcher (Sender: TObject);
    procedure CMEnter(var Message: TCMGotFocus); message CM_ENTER;
    procedure CMEnabledChanged(var Message: TMessage);
        message CM_ENABLEDCHANGED;
    procedure IndexSearch;
    procedure SequentialSearch (SearchFrom: TSearchFrom);
  public
    constructor Create (anOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Enabled;
    property Grid: TDBGrid read FGrid write SetGrid;
    property KeyField: string read FKeyField write SetKeyField;
    property SearchMethod: TLocatorSearchMethod read FSearchMethod
        write SetSearchMethod default lsmBoth;
  end;

  TKeyFieldProperty = class(TPropertyEditor)
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
    RegisterComponents('Oleg0k''s Components', [TOKDBLocator]);
    RegisterPropertyEditor(TypeInfo(string), TOKDBLocator,
                           'KeyField', TKeyFieldProperty);
end;


constructor TOKDBLocator.Create (anOwner: TComponent);
begin
    inherited Create (anOwner);
    Persist := false;
    GetReady := false;
    SavedKeyHandler := nil;
    SavedCharHandler := nil;
    SavedDataWatcher := nil;
    SavedColWatcher := nil;
    SavedExitWatcher := nil;
    FSearchMethod := lsmBoth;
    TabStop := false;
    Visible := false;
end;


{Hook some Grid's events}
procedure TOKDBLocator.SetGrid (NewGrid: TDBGrid);
begin
    FGrid := NewGrid;
    if not (csDesigning in ComponentState) then begin
        SavedKeyHandler := FGrid.OnKeyDown;
        FGrid.OnKeyDown := OurKeyHandler;
        SavedCharHandler := FGrid.OnKeyPress;
        FGrid.OnKeyPress := OurCharHandler;
        SavedDataWatcher := FGrid.DataSource.OnDataChange;
        FGrid.DataSource.OnDataChange := OurDataWatcher;
        SavedColWatcher := FGrid.OnColExit;
        FGrid.OnColExit := OurColWatcher;
        SavedExitWatcher := FGrid.OnExit;
        FGrid.OnExit := OurExitWatcher;
    end;//if
end;


procedure TOKDBLocator.SetKeyField (NewKeyField: string);
begin
    Visible := false;
    FKeyField := NewKeyField;
end;


procedure TOKDBLocator.SetSearchMethod (NewSearchMethod: TLocatorSearchMethod);
begin
    Visible := false;
    FSearchMethod := NewSearchMethod;
end;


{Don't let the focus be set on the locator}
procedure TOKDBLocator.CMEnter(var Message: TCMGotFocus);
begin
    try
        (Owner as TForm).ActiveControl := FGrid;
    except
        on EInvalidCast do
            {ignore};
    end;
    FGrid.EditorMode := true;
end;


{Go invisible when we get disabled}
procedure TOKDBLocator.CMEnabledChanged(var Message: TMessage);
begin
    if not Enabled then
        Visible := false;
end;


procedure TOKDBLocator.OurKeyHandler (Sender: TObject; var Key: Word;
                                      Shift: TShiftState);
begin
    if Assigned(SavedKeyHandler) then
        SavedKeyHandler (Sender, Key, Shift);
    GetReady := not FGrid.EditorMode and (FGrid.DataSource.State <> dsInsert);
end;


{Appear when key is pressed in the Grid and try to find the record with
 the specified value}
procedure TOKDBLocator.OurCharHandler (Sender: TObject; var Key: Char);
const SearchNextKey = Chr(14); //Ctrl-N
var OnKeyField: Boolean; SearchFrom: TSearchFrom;
begin
    if Assigned(SavedCharHandler) then
        SavedCharHandler (Sender, Key);

    if not Enabled then
        Exit;

    OnKeyField := FGrid.SelectedField.FieldName = FKeyField;

    SearchFrom := sfromCurrent;
    if not Visible then begin
        SearchFrom := sfromFirst;
        if not GetReady or ((FSearchMethod = lsmIndex) and not OnKeyField) then
            Exit;

        case Key of
        Chr(VK_RETURN), Chr(VK_ESCAPE), Chr(VK_TAB):
            Exit;
        end; {case}

        if Key <> SearchNextKey then
            Text := '';
        Visible := true;
        FGrid.EditorMode := false;
    end; {if}

    case Key of
    Chr(VK_BACK):
        if Length(Text) > 0 then begin
            Text := Copy(Text, 1, Length(Text) - 1);
        end; {if}
    Chr(VK_ESCAPE): begin
        Visible := false;
        Abort;
        end;
    Chr(VK_RETURN), Chr(VK_TAB): begin
        Visible := false;
        Exit;
        end;
    SearchNextKey:
        SearchFrom := sfromNext;
    else
        Text := Text + Key;
    end; {case}

    Persist := true;

    case FSearchMethod of
    lsmIndex:
        IndexSearch;
    lsmSequential:
        SequentialSearch (SearchFrom);
    lsmBoth:
        if OnKeyField then
            IndexSearch
        else
            SequentialSearch (SearchFrom);

    end; {case}

    Persist := false;
    FGrid.EditorMode := true;
    Abort;
end;


{Disappear when Grid cursor is moved}
procedure TOKDBLocator.OurDataWatcher (Sender: TObject; Field: TField);
begin
    if not Persist then
        Visible := false;

    if Assigned(SavedDataWatcher) then
        SavedDataWatcher (Sender, Field);
end;


procedure TOKDBLocator.IndexSearch;
begin
    with (FGrid.DataSource.DataSet as TTable) do begin
        try
            if MasterSource = nil then
                FindNearest ([Text])
            else
                FindNearest (
                    [MasterSource.DataSet.FieldByName(MasterFields).AsString,
                     Text]);
        except
            on EDataBaseError do
                {ignore};
            on EInvalidCast do
                {ignore};
        end;
    end; {with}
end;


procedure TOKDBLocator.SequentialSearch (SearchFrom: TSearchFrom);
label 1;
var OrgLocation: TBookmark;
    Pattern: string;
    SavedCursor: HCursor;
    Msg: TMsg;
begin
    Pattern := AnsiUpperCase(Text);
    with FGrid.DataSource.DataSet do begin
        OrgLocation := GetBookmark;
        DisableControls;
        SavedCursor := SetCursor(LoadCursor(0, IDC_WAIT));

        case SearchFrom of
        sfromFirst:
            First;
        sfromNext:
            Next;
        end;//case

        while not EOF do begin
            if Pos(Pattern,
                   AnsiUpperCase(FGrid.SelectedField.AsString)) = 1 then
                goto 1;

            if PeekMessage (Msg, 0, WM_KEYFIRST, WM_KEYLAST, PM_REMOVE) and
               (Msg.Message = WM_KEYDOWN) and (Msg.wParam = VK_ESCAPE) then
                Break;

            Next;
        end; {while}
        GotoBookmark (OrgLocation);

1:
        SetCursor (SavedCursor);
        EnableControls;
        FreeBookmark (OrgLocation);
    end; {with}
end;


procedure TOKDBLocator.OurColWatcher (Sender: TObject);
begin
    Visible := false;
    if Assigned(SavedColWatcher) then
        SavedColWatcher (Sender);
end;


procedure TOKDBLocator.OurExitWatcher (Sender: TObject);
begin
    Visible := false;
    if Assigned(SavedExitWatcher) then
        SavedExitWatcher (Sender);
end;


destructor TOKDBLocator.Destroy;
begin
    if not (csDesigning in ComponentState) then begin
        FGrid.OnKeyDown := SavedKeyHandler;
        FGrid.OnKeyPress := SavedCharHandler;
        FGrid.DataSource.OnDataChange := SavedDataWatcher;
        FGrid.OnColExit := SavedColWatcher;
        FGrid.OnExit := SavedExitWatcher;
    end; //if
    inherited;
end;


{"KeyField" on property editor methods}
function TKeyFieldProperty.GetAttributes: TPropertyAttributes;
begin
    Result := [paValueList];
end;

function TKeyFieldProperty.GetValue: string;
begin
    Result := GetStrValue;
end;

procedure TKeyFieldProperty.GetValues(Proc: TGetStrProc);
var I: Integer;
begin
    with TOKDBLocator(GetComponent(0)).Grid.DataSource.DataSet do
        for I := 0 to FieldCount - 1 do
            Proc(Fields[I].FieldName);
end;

procedure TKeyFieldProperty.SetValue(const Value: string);
var I: Integer;
begin
    if (Value = '') then begin
        SetStrValue('');
        Exit;
    end;

    with TOKDBLocator(GetComponent(0)).Grid.DataSource.DataSet do
        for I := 0 to FieldCount - 1 do
            if CompareText(Fields[I].FieldName, Value) = 0 then begin
                SetStrValue(Value);
                Exit;
            end;
    raise EPropertyError.Create('Invalid Property Value');
end;

end.
