unit jsonT1;

interface

procedure PerformJSONDocTests1;

implementation

uses SysUtils, jsonDoc;

type
  ETestFailed=class(Exception);

procedure Expect(const r1,r2,desc:WideString);
begin
  if r1<>r2 then
   begin
    WriteLn(r1);
    WriteLn(r2);
    raise ETestFailed.Create(desc);
   end;
end;

procedure PerformJSONDocTests1;
var
  d1,d2:IJSONDocument;
  a1:IJSONDocArray;
begin
  //pre-load sub-document
  d2:=JSON(['y',1]);
  d1:=JSON(['x',d2]);
  d1.Parse('{"x":{"y":2}}');
  Expect(d2.AsString,'{"y":2}','pre-load sub-document');

  //pre-load document array
  d1:=JSON(['x',newJSONDocArray(a1)]);
  d1.Parse('{"x":[{"y":1},{"y":2}]}');
  Expect(a1.AsString,'[{"y":1},{"y":2}]','pre-load doc-array');

  a1[1]:=JSON(['y',3]);
  Expect(a1.AsString,'[{"y":1},{"y":3}]','doc-array update one element');

  //catch documents in array on several keys in a structure
  a1:=JSONDocArray;
  d1:=JSON(['a',true,'x',a1,'b',false,'y{','z',a1,'c',0.0]);

  d1.Parse('{"y":{"z":[{"cc":"C"},{"dd":"D"}]},"x":[{"aa":"A"},{"bb":"B"}]}');
  Expect(IntToStr(a1.Count),'4','catch documents in arrays on several keys');

  d1:=JSON(['x','a"b"c']);
  Expect(d1.AsString,'{"x":"a\"b\"c"}','check escaped quotes');

  a1:=JSONDocArray;
  d1:=JSON(['a',a1]);
  d1.Parse('{"a":[{"x":"a\"b\"c"}]}');
  Expect(d1.AsString,'{"a":[{"x":"a\"b\"c"}]}','check espaced quotes in doc array');

end;

end.
