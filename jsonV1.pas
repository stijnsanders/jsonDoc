unit jsonV1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, ActnList, jsonDoc, StdActns;

type
  TfrmJsonViewer = class(TForm)
    ActionList1: TActionList;
    TreeView1: TTreeView;
    EditCopy1: TEditCopy;
    EditCopyValue1: TAction;
    procedure TreeView1CreateNodeClass(Sender: TCustomTreeView;
      var NodeClass: TTreeNodeClass);
    procedure TreeView1Expanding(Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean);
    procedure EditCopy1Execute(Sender: TObject);
    procedure TreeView1Change(Sender: TObject; Node: TTreeNode);
    procedure TreeView1DblClick(Sender: TObject);
    procedure EditCopyValue1Execute(Sender: TObject);
  private
    function LoadJSON(const FilePath: string): IJSONDocument;
    procedure ExpandJSON(Parent: TTreeNode; Data: IJSONDocument); 
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure DoShow; override;
    procedure Activate; override;
  end;

  TJSONNode=class(TTreeNode)
  public
    Data:IJSONDocument;
    Key:WideString;
    Index:integer;
    Loaded:boolean;
    procedure AfterConstruction; override;
    procedure ShowValue(xData: IJSONDocument; const xKey: WideString;
      xIndex: integer; const xValue: OleVariant);
  end;

var
  frmJsonViewer: TfrmJsonViewer;

implementation

uses
  Clipbrd;

{$R *.dfm}

{ TfrmJsonViewer }

procedure TfrmJsonViewer.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.WndParent:=GetDesktopWindow;
end;

procedure TfrmJsonViewer.DoShow;
var
  i:integer;
  fn:string;
  p:TJSONNode;
  n:TTreeNode;
begin
  inherited;
  TreeView1.Items.BeginUpdate;
  try
    case ParamCount of
      0:TreeView1.Items.Add(nil,'No file specified.');
      1:
       begin
        fn:=ParamStr(1);
        Caption:=fn+' - jsonV';
        //Application.Title:= //see CreateParams
        ExpandJSON(nil,LoadJSON(fn));
       end;
      else
        for i:=1 to ParamCount do
         begin
          fn:=ParamStr(i);
          p:=TreeView1.Items.Add(nil,fn) as TJSONNode;
          p.Data:=LoadJSON(fn);
          p.HasChildren:=true;
         end;
    end;
  finally
    TreeView1.Items.EndUpdate;
  end;
  n:=TreeView1.Items.GetFirstNode;
  if (n<>nil) and (n.getNextSibling=nil) then n.Expand(false);
end;

procedure TfrmJsonViewer.Activate;
begin
  inherited;
  ShowWindow(Application.Handle,SW_HIDE);
end;

procedure TfrmJsonViewer.TreeView1CreateNodeClass(Sender: TCustomTreeView;
  var NodeClass: TTreeNodeClass);
begin
  NodeClass:=TJSONNode;
end;

function TfrmJsonViewer.LoadJSON(const FilePath: string): IJSONDocument;
var
  m:TMemoryStream;
  i:integer;
  w:WideString;
begin
  m:=TMemoryStream.Create;
  try
    m.LoadFromFile(FilePath);
    //UTF-16
    if (PAnsiChar(m.Memory)[0]=#$FF) and
       (PAnsiChar(m.Memory)[1]=#$FE) then
     begin
      SetLength(w,i div 2);
      Move(w[1],PAnsiChar(m.Memory)[2],i);
     end
    else
    //UTF-8
    if (PAnsiChar(m.Memory)[0]=#$EF) and
       (PAnsiChar(m.Memory)[1]=#$BB) and
       (PAnsiChar(m.Memory)[2]=#$BF) then
     begin
      m.Position:=m.Size;
      i:=0;
      m.Write(i,1);
      w:=UTF8Decode(PAnsiChar(@PAnsiChar(m.Memory)[3]));
     end
    //ANSI
    else
     begin
      m.Position:=m.Size;
      i:=0;
      m.Write(i,1);
      w:=PAnsiChar(m.Memory);
     end;
  finally
    m.Free;
  end;
  if (w<>'') and (w[1]='[') then w:='{"":'+w+'}';
  Result:=JSON.Parse(w);
end;

procedure TfrmJsonViewer.TreeView1Expanding(Sender: TObject;
  Node: TTreeNode; var AllowExpansion: Boolean);
var
  p:TJSONNode;
  v:OleVariant;
  i,j,k:integer;
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
          if p.Index<>-1 then v:=v[VarArrayLowBound(v,1)+p.Index];
          //case VarType(v)
          if VarIsArray(v) then
           begin
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
          case VarType(v) of
            varUnknown:
              if IUnknown(v).QueryInterface(IJSONDocument,x)=S_OK then
                ExpandJSON(p,x);
              //else
          end;
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
    varOleStr:Result:='str';
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
  xIndex: integer; const xValue: OleVariant);
var
  vt:TVarType;
  d:IJSONDocument;
  e:IJSONEnumerator;
  s,t:string;
  l:integer;
begin
  Data:=xData;
  Key:=xKey;
  Index:=xIndex;
  vt:=VarType(xValue);
  if (vt and varArray)<>0 then
   begin
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
      varOleStr:
        Text:=Text+' (str) '+VarToStr(xValue);
      varBoolean:
        if xValue then
          Text:=Text+' (bool) true'
        else
          Text:=Text+' (bool) false';
      varUnknown,varDispatch:
        if IUnknown(xValue).QueryInterface(IJSONDocument,d)=S_OK then
         begin
          e:=(d as IJSONEnumerable).NewEnumerator;
          if e.EOF then s:='{}' else
           begin
            s:='';
            while e.Next and (Length(s)<255) do
             begin
              s:=s+', '+e.Key;
              vt:=VarType(e.Value);
              case vt of
                varNull,varEmpty:;//s:=s+': null';
                varOleStr:
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
                  s:=s+' ('+IntToHex(vt,4)+') '+t;
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

procedure TfrmJsonViewer.EditCopy1Execute(Sender: TObject);
begin
  if TreeView1.Selected<>nil then
    Clipboard.AsText:=TreeView1.Selected.Text;
end;

procedure TfrmJsonViewer.EditCopyValue1Execute(Sender: TObject);
var
  p:TJSONNode;
  v:OleVariant;
  d:IJSONDocument;
begin
  if (TreeView1.Selected<>nil) and (TreeView1.Selected is TJSONNode) then
   begin
    p:=TreeView1.Selected as TJSONNode;
    v:=p.Data[p.Key];
    if p.Index<>-1 then v:=v[VarArrayLowBound(v,1)+p.Index];
    case VarType(v) of
      varUnknown,varDispatch:
        if IUnknown(v).QueryInterface(IJSONDocument,d)=S_OK then
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
  v:OleVariant;
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
        //case VarType(v) of
        if (VarType(v)=varUnknown) and
          (IUnknown(v).QueryInterface(IJSONDocument,d)=S_OK) then
          Clipboard.AsText:=d.ToString
        else
          Clipboard.AsText:=VarToStr(v);
       end;
   end;
end;

end.
