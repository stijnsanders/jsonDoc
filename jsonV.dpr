program jsonV;

{$R 'jsonV_ver.res' 'jsonV_ver.rc'}

uses
  Forms,
  jsonV1 in 'jsonV1.pas' {frmJsonViewer},
  jsonDoc in 'jsonDoc.pas',
  jsonV2 in 'jsonV2.pas' {frmJsonTable};

{$R *.res}

begin
  Application.Initialize;
  Application.Title:='jsonV';
  Application.CreateForm(TfrmJsonViewer, frmJsonViewer);
  Application.Run;
end.
