unit OKHotSpt;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs;

const
    crHotSpot = -32;

type
  TOKHotSpot = class(TGraphicControl)
  protected
    procedure Paint; override;
  public
    constructor Create (AnOwner: TComponent); override;
  published
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseUp;
    property OnMouseMove;
    property OnDragDrop;
    property OnDragOver;
    property OnStartDrag;
    property OnEndDrag;
  end;

procedure Register;

implementation

{$R OKHotSpt.res}


procedure Register;
begin
  RegisterComponents('Oleg0k''s Components', [TOKHotSpot]);
end;


constructor TOKHotSpot.Create (AnOwner: TComponent);
var HotSpotCursor: HCursor;
begin
    inherited Create(AnOwner);
    ControlStyle :=
        ControlStyle + [csReplicatable, csClickEvents, csDoubleClicks];

    HotSpotCursor := LoadCursor (HInstance, '_HOTSPOT');
    if (HotSpotCursor <> 0) then begin
        Screen.Cursors[crHotSpot] := HotSpotCursor;
        Cursor := crHotSpot;
    end;//if
end;


procedure TOKHotSpot.Paint;
begin
    if csDesigning in ComponentState then
        DrawFocusRect (Canvas.Handle, ClientRect);
end;

end.
