unit jsonV1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, ActnList, jsonDoc, StdActns, StdCtrls, ExtCtrls, Menus;

type
  TfrmJsonViewer = class(TForm)
    ActionList1: TActionList;
    TreeView1: TTreeView;
    actEditCopy: TEditCopy;
    actEditCopyValue: TAction;
    panSearch: TPanel;
    Label1: TLabel;
    txtFind: TEdit;
    btnFindPrev: TButton;
    btnFindNext: TButton;
    actFind: TAction;
    actSearchPrev: TAction;
    actSearchNext: TAction;
    actSortChildren: TAction;
    lblSearchResult: TLabel;
    actViewTabular: TAction;
    procedure TreeView1CreateNodeClass(Sender: TCustomTreeView;
      var NodeClass: TTreeNodeClass);
    procedure TreeView1Expanding(Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean);
    procedure actEditCopyExecute(Sender: TObject);
    procedure TreeView1Change(Sender: TObject; Node: TTreeNode);
    procedure TreeView1DblClick(Sender: TObject);
    procedure actEditCopyValueExecute(Sender: TObject);
    procedure actFindExecute(Sender: TObject);
    procedure txtFindKeyPress(Sender: TObject; var Key: Char);
    procedure actSearchPrevExecute(Sender: TObject);
    procedure actSearchNextExecute(Sender: TObject);
    procedure AppActivate(Sender: TObject);
    procedure actSortChildrenExecute(Sender: TObject);
    procedure actViewTabularExecute(Sender: TObject);
  private
    FFilePath:string;
    FFileLastMod:int64;
    FFileMulti:boolean;
    FFileLastMods:array of int64;
    function LoadJSON(const FilePath:string;var FileLastMod:int64): IJSONDocument;
    procedure ExpandJSON(Parent: TTreeNode; Data: IJSONDocument);
    procedure ExpandString(Parent: TTreeNode; const Data: string);
    procedure SearchNode(Sender: TObject; Down: boolean);
  protected
    procedure DoShow; override;
    procedure CreateParams(var Params: TCreateParams); override;
  end;

  TJSONNode=class(TTreeNode)
  public
    Data:IJSONDocument;
    Key:WideString;
    Index:integer;
    Loaded:boolean;
    procedure AfterConstruction; override;
    procedure ShowValue(xData: IJSONDocument; const xKey: WideString;
      xIndex: integer; const xValue: Variant);
  end;
      
var
  frmJsonViewer: TfrmJsonViewer;

implementation

uses
  Clipbrd, ZLib, jsonV2;

{$R *.dfm}

{$IF not Declared(UTF8ToWideString)}
function UTF8ToWideString(const s: UTF8String): WideString;
begin
  Result:=UTF8Decode(s);
end;
{$IFEND}

{ TfrmJsonViewer }

procedure TfrmJsonViewer.DoShow;
var
  i,l:integer;
  fn:string;
  p:TJSONNode;
  n:TTreeNode;
begin
  inherited;

  {$if CompilerVersion >= 24}
  ///TODO: get locale "EN_US"?
  FormatSettings.DecimalSeparator:='.';
  FormatSettings.ThousandSeparator:=';';
  {$else}
  DecimalSeparator:='.';
  ThousandSeparator:=';';
  {$ifend}

  FFilePath:='';
  FFileLastMod:=0;
  FFileMulti:=false;

  Application.OnActivate:=AppActivate;

  TreeView1.Items.BeginUpdate;
  try
    case ParamCount of
      0:TreeView1.Items.Add(nil,'No file specified.');
      1:
       begin
        fn:=ParamStr(1);
        Caption:=fn+' - jsonV';
        Application.Title:=Caption;
        FFilePath:=fn;
        ExpandJSON(nil,LoadJSON(fn,FFileLastMod));
       end;
      else
       begin
        FFileMulti:=true;
        l:=ParamCount;
        SetLength(FFileLastMods,l);
        for i:=1 to l do
         begin
          fn:=ParamStr(i);
          p:=TreeView1.Items.Add(nil,fn) as TJSONNode;
          p.Data:=LoadJSON(fn,FFileLastMods[i-1]);
          p.HasChildren:=true;
         end;
       end;
    end;
  finally
    TreeView1.Items.EndUpdate;
  end;
  n:=TreeView1.Items.GetFirstNode;
  if (n<>nil) and (n.getNextSibling=nil) then n.Expand(false);
  ShowWindow(Application.Handle,SW_HIDE);
end;

procedure TfrmJsonViewer.TreeView1CreateNodeClass(Sender: TCustomTreeView;
  var NodeClass: TTreeNodeClass);
begin
  NodeClass:=TJSONNode;
end;

procedure LoadFromFile(m:TMemoryStream;const fn:string;var FileModTimeStamp:int64);
var
  f:TFileStream;
  fi:TByHandleFileInformation;
begin
  f:=TFileStream.Create(fn,fmOpenRead or fmShareDenyWrite);
  try
    if GetFileInformationByHandle(f.Handle,fi) then
      FileModTimeStamp:=(fi.ftLastWriteTime.dwHighDateTime shl 32) or
        fi.ftLastWriteTime.dwLowDateTime
    else
      FileModTimeStamp:=0;
    m.LoadFromStream(f);
  finally
    f.Free;
  end;
end;

procedure LoadFromCompressed(m:TMemoryStream;const fn:string;var FileModTimeStamp:int64);
var
  f:TFileStream;
  d:TDecompressionStream;
  fi:TByHandleFileInformation;
begin
  f:=TFileStream.Create(fn,fmOpenRead or fmShareDenyWrite);
  try
    if GetFileInformationByHandle(f.Handle,fi) then
      FileModTimeStamp:=(fi.ftLastWriteTime.dwHighDateTime shl 32) or
        fi.ftLastWriteTime.dwLowDateTime
    else
      FileModTimeStamp:=0;
    d:=TDecompressionStream.Create(f);
    try
      m.LoadFromStream(d);
    finally
      d.Free;
    end;
  finally
    f.Free;
  end;
end;

function TfrmJsonViewer.LoadJSON(const FilePath:string;
  var FileLastMod:int64):IJSONDocument;
var
  m:TMemoryStream;
  i,l:integer;
  w:WideString;
begin
  m:=TMemoryStream.Create;
  try
    if Copy(FilePath,Length(FilePath)-5,6)='.jsonz' then
      LoadFromCompressed(m,FilePath,FileLastMod)
    else
      LoadFromFile(m,FilePath,FileLastMod);
    l:=m.Size;
    if l=0 then
      w:=''
    else
     begin
      //UTF-16
      if (PAnsiChar(m.Memory)[0]=#$FF) and
         (PAnsiChar(m.Memory)[1]=#$FE) then
       begin
        i:=l-2;
        SetLength(w,i div 2);
        Move(PAnsiChar(m.Memory)[2],w[1],i);
       end
      else
      //UTF-8
      if (PAnsiChar(m.Memory)[0]=#$EF) and
         (PAnsiChar(m.Memory)[1]=#$BB) and
         (PAnsiChar(m.Memory)[2]=#$BF) then
       begin
        m.Position:=l;
        i:=0;
        m.Write(i,1);
        w:=UTF8ToWideString(PAnsiChar(@PAnsiChar(m.Memory)[3]));
       end
      //UTF-8 without BOM, or ANSI
      else
       begin
        m.Position:=l;
        i:=0;
        m.Write(i,1);
        w:=UTF8ToWideString(PAnsiChar(m.Memory));
        if w='' then w:=WideString(PAnsiChar(m.Memory));
       end;
     end;
  finally
    m.Free;
  end;
  if (w<>'') and (w[1]='[') then w:='{"":'+w+'}';
  Result:=JSON;
  try
    Result.Parse(w);
  except
    on e:EJSONDecodeException do
      MessageBox(Handle,PChar('Error loading "'+FilePath+'":'#13#10+
        e.Message),'jsonV',MB_OK or MB_ICONERROR);
  end;
end;

procedure TfrmJsonViewer.TreeView1Expanding(Sender: TObject;
  Node: TTreeNode; var AllowExpansion: Boolean);
var
  p,q:TJSONNode;
  v:Variant;
  i,j,k:integer;
  ii:array of integer;
  x:IJSONDocument;
begin
  p:=Node as TJSONNode;
  if not p.Loaded then
   begin
    TreeView1.Items.BeginUpdate;
    try
      p.Loaded:=true;
      p.HasChildren:=false;
      if p.Data<>nil then
//        if p.Key='' then
//          ExpandJSON(Node,p.Data)
//        else
         begin
          v:=p.Data[p.Key];
          i:=0;
          if p.Index<>-1 then
           begin
            q:=p;
            while (q<>nil) and (q.Index<>-1) do
             begin
              inc(i);
              q:=q.Parent as TJSONNode;
             end;
            SetLength(ii,i);
            q:=p;
            while i<>0 do //while (q<>nil) and (q.Index<>-1) do
             begin
              dec(i);
              ii[i]:=q.Index;
              q:=q.Parent as TJSONNode;
             end;
            for i:=0 to Length(ii)-1 do
              v:=v[VarArrayLowBound(v,1)+ii[i]];
           end;
          if VarIsArray(v) then
           begin
            //assert VarArrayDimCount(v)=1
            i:=VarArrayLowBound(v,1);
            j:=0;
            k:=VarArrayHighBound(v,1)+1;
            while i<k do
             begin
              (TreeView1.Items.AddChild(p,'#'+IntToStr(i)) as TJSONNode).
                ShowValue(p.Data,p.Key,j,v[i]);
              inc(i);
              inc(j);
             end;
           end
          else
          if (TVarData(v).VType=varOleStr) or (TVarData(v).VType=varString) then
            ExpandString(p,VarToStr(v))
          else
          if (TVarData(v).VType=varUnknown) and (TVarData(v).VUnknown<>nil) and
            (IUnknown(v).QueryInterface(IJSONDocument,x)=S_OK) then
            ExpandJSON(p,x);
         end
      else
        //no p.Data
    finally
      TreeView1.Items.EndUpdate;
    end;
   end;
end;

procedure TfrmJsonViewer.ExpandJSON(Parent: TTreeNode;
  Data: IJSONDocument);
var
  e:IJSONEnumerator;
begin
  //assert caller does TreeView1.Items.BeginUpdate/EndUpdate
  e:=(Data as IJSONEnumerable).NewEnumerator;
  while e.Next do
    (TreeView1.Items.AddChild(Parent,e.Key) as TJSONNode).
      ShowValue(Data,e.Key,-1,Data[e.Key]);
end;

procedure TfrmJsonViewer.ExpandString(Parent: TTreeNode;
  const Data: string);
var
  i,j,k,l:integer;
begin
  l:=Length(Data);
  i:=1;
  k:=0;
  while (i<=l) do
   begin
    while (i<=l) and (Data[i]<' ') do inc(i);
    if i<=l then
     begin
      j:=i;
      while (j<=l) and (Data[j]>=' ') do inc(j);
      inc(k);
      TreeView1.Items.AddChild(Parent,
        Format('@%d <%d..%d> %s',[k,i-1,j-1,Copy(Data,i,j-i)]));
      i:=j;
     end;
   end;
end;

function GetFileLastMod(const fn:string):int64;
var
  f:TFileStream;
  fi:TByHandleFileInformation;
begin
  Result:=0;
  f:=TFileStream.Create(fn,fmOpenRead or fmShareDenyNone);
  try
    if GetFileInformationByHandle(f.Handle,fi) then
      Result:=(fi.ftLastWriteTime.dwHighDateTime shl 32) or
        fi.ftLastWriteTime.dwLowDateTime;
  finally
    f.Free;
  end;
end;

procedure TfrmJsonViewer.AppActivate(Sender: TObject);
var
  n:TTreeNode;
  i:integer;
begin
  //TODO: store/re-apply expanded nodes...
  if FFileMulti then
   begin
    TreeView1.Items.BeginUpdate;
    try
      n:=TreeView1.Items.GetFirstNode;
      i:=0;
      while n<>nil do
       begin
        try
          //assert i<Length(FFileLastMods)
          if GetFileLastMod(n.Text)<>FFileLastMods[i] then
           begin
            n.DeleteChildren;
            (n as TJSONNode).Data:=LoadJSON(n.Text,FFileLastMods[i]);
            n.HasChildren:=true;
           end;
        except
          //silent;
        end;
        n:=n.getNextSibling;
        inc(i);
       end;
    finally
      TreeView1.Items.EndUpdate;
    end;
   end
  else
    try
      if (FFilePath<>'') and (GetFileLastMod(FFilePath)<>FFileLastMod) then
       begin
        TreeView1.Items.BeginUpdate;
        try
          TreeView1.Items.Clear;
          ExpandJSON(nil,LoadJSON(FFilePath,FFileLastMod));
        finally
          TreeView1.Items.EndUpdate;
        end;
       end;
    except
      //silent?
    end;
end;

procedure TfrmJsonViewer.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.WndParent:=GetDesktopWindow;
end;

{ TJSONNode }

procedure TJSONNode.AfterConstruction;
begin
  inherited;
  Data:=nil;
  Key:='';
  Index:=-1;
  Loaded:=false;
end;

function VarTypeStr(vt:TVarType):string;
begin
  case vt and varTypeMask of
    varNull,varEmpty:Result:='null';
    varBoolean:Result:='bool';
    varOleStr,varString:Result:='str';
    varUnknown,varDispatch:Result:='obj';
    varShortInt:Result:='i8';
    varSmallint:Result:='i16';
    varInteger:Result:='i32';
    varSingle:Result:='f32';
    varDouble:Result:='f64';
    varCurrency:Result:='c';
    varDate:Result:='ts';
    varVariant:Result:='var';
    $000E:Result:='dec';//varDecimal
    varByte:Result:='u8';
    varWord:Result:='u16';
    varLongWord:Result:='u32';
    varInt64:Result:='i64';
    $0015:Result:='u64';//varWord64
    varStrArg:Result:='uuid';
    else Result:=IntToHex(vt,4);
  end;
end;

procedure TJSONNode.ShowValue(xData: IJSONDocument; const xKey: WideString;
  xIndex: integer; const xValue: Variant);
var
  vt:TVarType;
  d:IJSONDocument;
  e:IJSONEnumerator;
  s,t:string;
  i,l:integer;
begin
  Data:=xData;
  Key:=xKey;
  Index:=xIndex;
  vt:=TVarData(xValue).VType;
  if (vt and varArray)<>0 then
   begin
    //assert VarArrayDimCount(xValue)=1
    l:=VarArrayHighBound(xValue,1)-
      VarArrayLowBound(xValue,1)+1;
    if l=0 then
      Text:=Text+' []'
    else
     begin
      Text:=Format('%s [%s#%d]',[Text,VarTypeStr(vt),l]);
      HasChildren:=true;
     end;
   end
  else
    case vt of
      //
      varNull,varEmpty:
        Text:=Text+' (null)';
      varOleStr,varString:
       begin
        s:=VarToStr(xValue);
        l:=Length(s);
        for i:=1 to l do
          if s[i]<' ' then
           begin
            s[i]:=' ';
            HasChildren:=true;
           end;
        Text:=Text+' (str) '+s;
       end;
      varBoolean:
        if xValue then
          Text:=Text+' (bool) true'
        else
          Text:=Text+' (bool) false';
      varUnknown,varDispatch:
        if (TVarData(xValue).VUnknown<>nil) and
          (IUnknown(xValue).QueryInterface(IJSONDocument,d)=S_OK) then
         begin
          e:=(d as IJSONEnumerable).NewEnumerator;
          if e.EOF then s:='{}' else
           begin
            s:='';
            while e.Next and (Length(s)<255) do
             begin
              s:=s+', '+e.Key;
              vt:=TVarData(e.Value).VType;
              case vt of
                varNull,varEmpty:;//s:=s+': null';
                varOleStr,varString:
                 begin
                  t:=VarToStr(e.Value);
                  if Length(t)>30 then
                    s:=s+': "'+Copy(t,1,30)+'...'
                  else
                    s:=s+': "'+t+'"';
                 end;
                varBoolean:if e.Value then s:=s+': true' else s:=s+': false';
                varUnknown,varDispatch:s:=s+':?';
                varArray..(varArray or varTypeMask):
                  s:=s+':[#'+IntToStr(VarArrayHighBound(e.Value,1)-
                    VarArrayLowBound(e.Value,1)+1)+']';
                else
                 begin
                  try
                    t:=VarToStr(e.Value);
                    if Length(t)>32 then t:=Copy(t,1,30)+'...';
                  except
                    t:='?';
                  end;
                  s:=s+' ('+VarTypeStr(vt)+') '+t;
                 end;
              end;
             end;
            s[1]:='{';
            if e.EOF then s:=s+'}' else s:=s+' ...';
           end;
          Text:=Text+' '+s;
          HasChildren:=true;
         end
        else
          Text:=Text+' ('+VarTypeStr(vt)+')???';
      else
        Text:=Text+' ('+VarTypeStr(vt)+') '+VarToStr(xValue);
    end;
end;

procedure TfrmJsonViewer.actEditCopyExecute(Sender: TObject);
begin
  if TreeView1.Selected<>nil then
    Clipboard.AsText:=TreeView1.Selected.Text;
end;

procedure TfrmJsonViewer.actEditCopyValueExecute(Sender: TObject);
var
  p:TJSONNode;
  v:Variant;
  d:IJSONDocument;
begin
  if (TreeView1.Selected<>nil) and (TreeView1.Selected is TJSONNode) then
   begin
    p:=TreeView1.Selected as TJSONNode;
    v:=p.Data[p.Key];
    if p.Index<>-1 then v:=v[VarArrayLowBound(v,1)+p.Index];
    case TVarData(v).VType of
      varUnknown,varDispatch:
        if (TVarData(v).VUnknown<>nil) and
          (IUnknown(v).QueryInterface(IJSONDocument,d)=S_OK) then
          Clipboard.AsText:=d.ToString;
      else Clipboard.AsText:=VarToStr(v);
    end;
   end;
end;

procedure TfrmJsonViewer.TreeView1Change(Sender: TObject; Node: TTreeNode);
var
  n:TTreeNode;
  s:string;
begin
  n:=Node;
  s:='';
  while n<>nil do
   begin
    s:=n.Text+' > '+s;
    n:=n.Parent;
   end;
end;

procedure TfrmJsonViewer.TreeView1DblClick(Sender: TObject);
var
  v:Variant;
  vt:TVarType;
  p:TJSONNode;
  d:IJSONDocument;
begin
  if TreeView1.Selected<>nil then
   begin
    p:=TreeView1.Selected as TJSONNode;
    if p.Data<>nil then
      if p.Key='' then
        Clipboard.AsText:=p.Data.ToString
      else
       begin
        v:=p.Data[p.Key];
        if p.Index<>-1 then v:=v[VarArrayLowBound(v,1)+p.Index];
        vt:=TVarData(v).VType;
        if (vt=varUnknown) and (TVarData(v).VUnknown<>nil) and
          (IUnknown(v).QueryInterface(IJSONDocument,d)=S_OK) then
          Clipboard.AsText:=d.ToString
        //else if vt=varArray or varUnknown then actViewTabular.Execute
        else
          Clipboard.AsText:=VarToStr(v);
       end;
   end;
end;

procedure TfrmJsonViewer.actFindExecute(Sender: TObject);
begin
  panSearch.Visible:=true;
  txtFind.SelectAll;
  txtFind.SetFocus;
end;

procedure TfrmJsonViewer.txtFindKeyPress(Sender: TObject; var Key: Char);
begin
  if Key=#13 then
   begin
    btnFindNext.Click;
    Key:=#0;
   end;
end;

procedure TfrmJsonViewer.actSearchPrevExecute(Sender: TObject);
begin
  SearchNode(Sender,false);
end;

procedure TfrmJsonViewer.actSearchNextExecute(Sender: TObject);
begin
  SearchNode(Sender,true);
end;

procedure TfrmJsonViewer.SearchNode(Sender:TObject;Down:boolean);
var
  n,n1:TTreeNode;
  f:string;
  b:boolean;
  c:integer;

  procedure MoveOne;
  begin
    if Down then
     begin
      if n<>nil then
       begin
        b:=true;
        TreeView1Expanding(Sender,n,b);
        n:=n.GetNext;
       end;
      if n=nil then
        n:=TreeView1.Items.GetFirstNode;
     end
    else
     begin
      while (n<>nil) and (n.getPrevSibling=nil) do n:=n.Parent;
      if n<>nil then n:=n.getPrevSibling;
      b:=true;
      while b and (n<>nil) do
       begin
        b:=true;
        TreeView1Expanding(Sender,n,b);
        if n.Count=0 then
          b:=false
        else
         begin
          b:=true;
          n:=n.GetLastChild;
         end;
       end;
     end;
    inc(c);
  end;

begin
  Screen.Cursor:=crHourGlass;
  TreeView1.Items.BeginUpdate;
  try
    c:=0;
    n1:=TreeView1.Selected;
    n:=n1;
    MoveOne;
    f:=LowerCase(txtFind.Text);//TODO: regexp? match full node data?
    while (n<>n1) and (n<>nil) and (Pos(f,LowerCase(n.Text))=0) do
     begin
      if n1=nil then n1:=n;
      MoveOne;
     end;
  finally
    Screen.Cursor:=crDefault;
    TreeView1.Items.EndUpdate;
  end;
  if n=nil then
    lblSearchResult.Caption:='none found'
  else
   begin
    if Down then
      lblSearchResult.Caption:=IntToStr(c)+' nodes forward'
    else
      lblSearchResult.Caption:=IntToStr(c)+' nodes backward';
    TreeView1.Selected:=n;
   end;
  TreeView1.SetFocus;
end;

procedure TfrmJsonViewer.actSortChildrenExecute(Sender: TObject);
begin
  if TreeView1.Selected<>nil then
    TreeView1.Selected.AlphaSort(false);
end;

procedure TfrmJsonViewer.actViewTabularExecute(Sender: TObject);
var
  p:TJSONNode;
  v:Variant;
  f:TfrmJsonTable;
  s:string;
begin
  p:=TreeView1.Selected as TJSONNode;
  v:=p.Data[p.Key];
  if TVarData(v).VType=varArray or varUnknown then
   begin
    Screen.Cursor:=crHourGlass;
    try
      f:=TfrmJsonTable.Create(Self);

      s:='.'+p.Key;
      p:=p.Parent as TJSONNode;
      while p<>nil do
       begin
        if p.Index=-1 then
          s:='.'+p.Key+s
        else
          s:='['+IntToStr(p.Index)+']'+s;
        p:=p.Parent as TJSONNode;
       end;
      f.Caption:=Copy(s,2,Length(s)-1)+' - '+FFilePath+' - jsonV';

      f.BuildTable(Self,TreeView1.Selected,v);

      f.Show;
    finally
      Screen.Cursor:=crDefault;
    end;
   end;
end;

end.
