unit jsonFile;

interface

uses jsonDoc;

function LoadJSON(const FilePath: string; Data: IJSONDocument = nil): IJSONDocument;
procedure SaveJSON(const FilePath: string; Data: IJSONDocument);

implementation

uses SysUtils, Classes;

{$IF not Declared(UTF8ToWideString)}
function UTF8ToWideString(const s: UTF8String): WideString;
begin
  Result:=UTF8Decode(s);
end;
{$IFEND}

const
  Utf8ByteOrderMark:array[1..3] of AnsiChar=#$EF#$BB#$BF;
  UTF16LEByteOrderMark:array[1..2] of AnsiChar=#$FF#$FE;

function LoadJSON(const FilePath: string; Data: IJSONDocument): IJSONDocument;
var
  v:AnsiString;
  w:WideString;
  i:integer;
  f:TFileStream;
begin
  f:=TFileStream.Create(FilePath,fmOpenRead or fmShareDenyWrite);
  try
    i:=f.Size;
    SetLength(v,i);
    if i<>f.Read(v[1],i) then RaiseLastOSError;
    if (i>=3)
      and (v[1]=Utf8ByteOrderMark[1])
      and (v[2]=Utf8ByteOrderMark[2])
      and (v[3]=Utf8ByteOrderMark[3])
      then
      w:=UTF8ToWideString(PAnsiChar(@v[4]))
    else
    if (i>=2)
      and (v[1]=UTF16LEByteOrderMark[1])
      and (v[2]=UTF16LEByteOrderMark[2])
      then
     begin
      dec(i,2);
      SetLength(w,i div 2);
      Move(v[3],w[1],i);
     end
    else
      w:=v;
  finally
    f.Free;
  end;
  if Data=nil then Result:=JSON else Result:=Data;
  Result.Parse(w);
end;

procedure SaveJSON(const FilePath: string; Data: IJSONDocument);
var
  v:AnsiString;
  f:TFileStream;
begin
  v:=Utf8ByteOrderMark+UTF8Encode(Data.ToString);
  f:=TFileStream.Create(FilePath,fmCreate);
  try
    f.Write(v[1],Length(v));
  finally
    f.Free;
  end;
end;

end.