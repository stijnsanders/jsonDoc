program jsonTests1;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  jsonT1 in 'jsonT1.pas',
  jsonDoc in '..\jsonDoc.pas';

begin
  try
    PerformJSONDocTests1;
  except
    on e:Exception do
     begin
      WriteLn(ErrOutput,'###'+e.ClassName);
      WriteLn(ErrOutput,e.Message);
      ExitCode:=1;
     end;
  end;
end.
