{

mustache.pas

Copyright 2015 Stijn Sanders
Made available under terms described in file "LICENSE"

https://github.com/stijnsanders/jsonDoc
https://mustache.github.io/

}
unit mustache;

interface

uses jsonDoc, SysUtils;

type
  TMustacheTranslator=function(const x:UTF8String):UTF8String;
  EMustacheError=class(Exception);

threadvar
  MustacheDefaultEncode:TMustacheTranslator;
  MustachePartials:TMustacheTranslator;

function ApplyMustache(const Template:UTF8String;Data:IJSONDocument):UTF8String;

implementation

uses Variants;

function FindNext(const Delimiter,Data:UTF8String;Start,DataSize:cardinal):cardinal; //inline;
var
  i,dl,ds:cardinal;
begin
  Result:=Start;
  dl:=Length(Delimiter);
  ds:=DataSize-dl+1;
  i:=0;
  while (Result<=ds) and (i<dl) do
   begin
    i:=0;
    while (i<dl) and (Data[Result+i]=Delimiter[i+1]) do inc(i);
    if i<dl then inc(Result);
   end;
  if Result>ds then Result:=DataSize+1;
end;

function ApplyMustache(const Template:UTF8String;Data:IJSONDocument):UTF8String;
type
  TDelimiterType=(dtStart,stStop);
var
  i,j,k,l,m,n,ri,rl:cardinal;
  t:UTF8String;
  Source:array of record
    Data:UTF8String;
    Index:cardinal;
  end;
  SourceSize,SourceIndex:cardinal;
  Context:array of record
    TagName:UTF8String;
    Data:IJSONDocument;
    Display:boolean;
    Sequence:OleVariant;
    SourceIndex,SeqIndex,SeqMax:cardinal;
  end;
  ContextSize,ContextIndex:cardinal;
  dStart,dStop,v:UTF8String;
  vv:OleVariant;
  b:boolean;
  dd:IJSONDocument;
const
  rGrowStep=$1000;
  procedure rCopy(const xx;x:cardinal);//inline;
  begin
    if ri+x>rl then
     begin
      while rl<x do inc(rl,rGrowStep);
      SetLength(Result,rl);
     end;
    Move(xx,Result[ri+1],x);
    inc(ri,x);
  end;
  procedure cPush(const pTagName:UTF8String;
    const pData:IJSONDocument;pDisplay:boolean);
  begin
    if ContextIndex=ContextSize then
     begin
      inc(ContextSize,$100);//cGrowStep;
      SetLength(Context,ContextSize);
     end;
    inc(ContextIndex);
    Context[ContextIndex].TagName:=pTagName;
    Context[ContextIndex].Data:=pData;
    Context[ContextIndex].Display:=Context[ContextIndex-1].Display and pDisplay;
    VarClear(Context[ContextIndex].Sequence);
    Context[ContextIndex].SeqIndex:=1;
    Context[ContextIndex].SeqMax:=0;
    Context[ContextIndex].SourceIndex:=k;
  end;
  procedure vLookup;
  var
    vi,vj,vl:integer;
    n:cardinal;
    vx:UTF8String;
  begin
    vl:=j-i;
    v:=Copy(t,i,vl);
    vi:=1;
    while (vi<=vl) and (v[vi]<>'.') do inc(vi);
    vx:=Trim(Copy(v,1,vi-1));
    n:=ContextIndex;
    vv:=Context[n].Data[vx];
    while VarIsNull(vv) and (n<>0) do
     begin
      dec(n);
      vv:=Context[n].Data[v];
     end;
    while not(VarIsNull(vv)) and (vi<=vl) do
     begin
      inc(vi);
      vj:=vi;
      while (vi<=vl) and (v[vi]<>'.') do inc(vi);
      vx:=Trim(Copy(v,vj,vi-vj));
      //TODO: support more?
      vv:=(IUnknown(vv) as IJSONDocument)[vx];
     end;
  end;
begin
  //defaults
  dStart:='{{';
  dStop:='}}';

  ri:=0;
  rl:=0;

  SourceIndex:=0;
  SourceSize:=0;
  SetLength(Source,SourceSize);

  ContextIndex:=0;
  ContextSize:=$100;
  SetLength(Context,ContextSize);
  Context[0].Data:=Data;
  Context[0].Display:=true;

  //first bit
  t:=Template;
  l:=Length(Template);
  i:=FindNext(dStart,t,1,l);
  if i<>1 then rCopy(t[1],i-1);

  //TODO: line/pos on exceptions?

  while (i<l) or (SourceIndex<>0) do
   begin
    while i<l do
     begin
      //find closing delimiter
      inc(i,Length(dStart));
      j:=FindNext(dStop,t,i,l);
      if j>l then raise EMustacheError.Create('Unterminated mustache tag');
      k:=j+cardinal(Length(dStart));

      //TODO: consume whitespace
      //TODO: ignore in-tag whitespace

      if i=j then
       begin
        //empty tag
       end
      else
       begin
        //handle tag
        case t[i] of

          '!':;//comment (ignore)

          '='://set delimiters
           begin
            //TODO: {{=@ @=}} keep surrounding whitespace
            if t[j-1]<>'=' then
              raise EMustacheError.Create('Closing "=" required when setting delimiters');
            v:=Trim(Copy(t,i+1,j-i-2));
            m:=Length(v);
            n:=1;
            while (n<=m) and (v[n]<>' ') do inc(n);
            if n>m then n:=m div 2;//split halfway? (raise?)
            dStart:=Trim(Copy(v,1,n-1));
            dStop:=Trim(Copy(v,n,m-n+1));
            if (dStart='') or (dStop='') then
              raise EMustacheError.Create('Empty delimiters not allowed');
            //TODO: require ContextIndex=0?
           end;

          '#','^'://section,inverted
           begin
            inc(i);
            vLookup;
            dd:=nil;
            m:=1;
            n:=0;
            case VarType(vv) of
              varNull,varEmpty:b:=false;
              varBoolean:b:=vv;
              varSmallint,
              varInteger,
              varShortInt,
              varByte,
              varWord,
              varLongWord,
              varInt64:b:=vv<>0;
              varSingle,
              varDouble,
              varCurrency:b:=vv<>0.0;
              //TODO: varArray
              //TODO: empty list: b:=false;
              varUnknown:
               begin
                //if QueryInterface?
                dd:=IUnknown(vv) as IJSONDocument;
                b:=true;
                //TODO: more?.
               end;
              varArray or varUnknown,varArray or varVariant:
               begin
                m:=VarArrayLowBound(vv,1);
                n:=VarArrayHighBound(vv,1);
                b:=n-m+1<>0;
               end;
              else
                raise EMustacheError.CreateFmt('Unexpected subject type "%s"',[v]);
            end;
            cPush(v,dd,b xor (t[i]='^'));
            //start iteration?
            if b and (m<n) then
             begin
              Context[ContextIndex].Sequence:=vv;//VarArrayRef?
              Context[ContextIndex].Data:=IUnknown(vv[m]) as IJSONDocument;
              Context[ContextIndex].SeqIndex:=m+1;
              Context[ContextIndex].SeqMax:=n;
             end;
           end;

          '/'://pop
           begin
            v:=Trim(Copy(t,i+1,j-i-2));
            if ContextIndex=0 then
              raise EMustacheError.CreateFmt('Unexpected section end "%s"',[v]);
            //TODO: if allow empty end section tag?
            if v<>Context[ContextIndex].TagName then
              raise EMustacheError.CreateFmt('Mismatching section end "%s"',[v]);

            if Context[ContextIndex].SeqIndex<=Context[ContextIndex].SeqMax then
             begin
              k:=Context[ContextIndex].SourceIndex;
              //TODO: support more?
              Context[ContextIndex].Data:=IUnknown(
                Context[ContextIndex].Sequence[
                 Context[ContextIndex].SeqIndex
                ]) as IJSONDocument;
              inc(Context[ContextIndex].SeqIndex);
             end
            else
             begin
              //cPop;
              VarClear(Context[ContextIndex].Sequence);//release
              Context[ContextIndex].Data:=nil;//release
              dec(ContextIndex);
             end;
           end;

          '>'://partials
            if Context[ContextIndex].Display then //?
             begin
              //cPush?
              if SourceIndex=SourceSize then
               begin
                inc(SourceSize,$10);
                SetLength(Source,SourceSize);
               end;
              //sPush:
              Source[SourceIndex].Data:=t;
              Source[SourceIndex].Index:=k;
              //Source[SourceIndex].Size:=l;
              inc(SourceIndex);
              //
              if @MustachePartials=nil then
                raise EMustacheError.Create('MustachePartials not defined');
              t:=MustachePartials(Trim(Copy(t,i+1,j-i-1)));

              l:=Length(t);
              k:=1;//first bit: see below
             end;

          '{','&'://without HTMLEncode
           begin
            if t[i]='{' then
             begin
              if (t[j-1]<>'}') and (Copy(t,j+1,Length(dStop))=dStop) then
               begin
                inc(j);
                inc(k);
               end;
              if t[j-1]<>'}' then
                raise EMustacheError.Create('Closing "}" required on unencoded');
             end;
            if Context[ContextIndex].Display then
             begin
              inc(i);
              vLookup;
              v:=VarToStr(vv);
              if v<>'' then rCopy(v[1],Length(v));
             end;
           end;

          else //
            if Context[ContextIndex].Display then
             begin
              vLookup;
              v:=VarToStr(vv);
               if v<>'' then
               begin
                if @MustacheDefaultEncode<>nil then v:=MustacheDefaultEncode(v);
                rCopy(v[1],Length(v));
               end;
             end;
        end;
       end;

      //trailing bit
      i:=FindNext(dStart,t,k,l);
      if Context[ContextIndex].Display then
        if i>l then rCopy(t[k],l-k+1) else
          if i<>k then rCopy(t[k],i-k);
     end;
    if SourceIndex<>0 then
     begin
      dec(SourceIndex);
      //cPop?
      t:=Source[SourceIndex].Data;
      k:=Source[SourceIndex].Index;
      l:=Length(t);//Source[SourceIndex].Size;

      //trailing bit
      i:=FindNext(dStart,t,k,l);
      if Context[ContextIndex].Display then
        if i>l then rCopy(t[k],l-k+1) else
          if i<>k then rCopy(t[k],i-k);
     end;
   end;
  if ContextIndex<>0 then
    raise EMustacheError.CreateFmt('Unclosed sections detected: %d',[ContextIndex]);
  SetLength(Result,ri);
end;

end.
