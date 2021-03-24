{

jsonSet.pas

Copyright 2021 Stijn Sanders
Made available under terms described in file "LICENSE"
https://github.com/stijnsanders/jsonDoc

v1.0.0

}
unit jsonSet;

interface

uses jsonDoc;

type
  TJSONDocSet=class(TJSONDocArray)
  private
    FKeyIndex:IJSONDocument;
  public
    procedure SetDoc(const Key:WideString;Value:IJSONDocument);
    function GetDoc(const Key:WideString):IJSONDocument;
    procedure LoadDoc(const Key:WideString;Value:IJSONDocument);
    property Doc[const Key:WideString]:IJSONDocument read GetDoc write SetDoc; default;
    constructor Create;
    destructor Destroy; override;
    function AsKeyedDoc:IJSONDocument;
  end;

implementation

uses Variants;

{ TJSONDocSet }

constructor TJSONDocSet.Create;
begin
  inherited Create;
  FKeyIndex:=JSON;//TODO: better with sorted TStringList?
end;

destructor TJSONDocSet.Destroy;
begin
  FKeyIndex:=nil;
  inherited;
end;

function TJSONDocSet.GetDoc(const Key: WideString): IJSONDocument;
var
  v:Variant;
begin
  v:=FKeyIndex[Key];
  if VarIsNull(v) then Result:=nil else
   begin
    Result:=JSON;
    Result.Parse(GetJSON(v));
   end;
end;

procedure TJSONDocSet.LoadDoc(const Key: WideString; Value: IJSONDocument);
var
  v:Variant;
begin
  //IMPORTANT: caller does Value.Clear!!!
  v:=FKeyIndex[Key];
  if not(VarIsNull(v)) then Value.Parse(GetJSON(v));
end;

procedure TJSONDocSet.SetDoc(const Key: WideString; Value: IJSONDocument);
var
  v:Variant;
begin
  v:=FKeyIndex[Key];
  if VarIsNull(v) then
    FKeyIndex[Key]:=Add(Value)
  else
    Set_Item(v,Value);
end;

function TJSONDocSet.AsKeyedDoc: IJSONDocument;
var
  je:IJSONEnumerator;
begin
  Result:=JSON;
  je:=JSONEnum(FKeyIndex);
  while je.Next do
    Result[je.Key]:=Get_Item(je.Value);
end;

end.
