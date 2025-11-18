unit jsonV2;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, StdActns, ActnList, jsonDoc, Menus, ExtCtrls;

type
  TfrmJsonTable = class(TForm)
    ListView1: TListView;
    ActionList1: TActionList;
    EditSelectAll1: TEditSelectAll;
    EditCopy1: TEditCopy;
    PopupMenu1: TPopupMenu;
    Removecolumn1: TMenuItem;
    Sortascending1: TMenuItem;
    Sortdescending1: TMenuItem;
    procedure EditSelectAll1Execute(Sender: TObject);
    procedure EditCopy1Execute(Sender: TObject);
    procedure ListView1DblClick(Sender: TObject);
    procedure ListView1Data(Sender: TObject; Item: TListItem);
    procedure ListView1ColumnRightClick(Sender: TObject;
      Column: TListColumn; Point: TPoint);
    procedure ListView1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Removecolumn1Click(Sender: TObject);
    procedure Sortascending1Click(Sender: TObject);
    procedure Sortdescending1Click(Sender: TObject);
  private
    FListSource: TForm;
    FListNode: TTreeNode;
    FKeys: array of WideString;
    FItems: array of IJSONDocument;
    FIndexes: array of integer;
    FCSel: TListColumn;
    procedure SortItems(const FieldName:WideString;Ascending:boolean);
  protected
    procedure DoShow; override;
    procedure CreateParams(var Params: TCreateParams); override;
  public
    procedure BuildTable(ListSource: TForm; ListNode: TTreeNode;
      IndexRow: integer; const v: Variant; const NodeKey: string);
  end;

var
  frmJsonTable: TfrmJsonTable;

implementation

uses Clipbrd, Math;

{$R *.dfm}

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

function StripTab(const x:string):string;
var
  i:integer;
begin
  Result:=x;
  for i:=1 to Length(Result) do
    //if Result[i]=#9 then Result[i]:=' ';
    if Result[i]<' ' then Result[i]:=' ';//?
end;

{ TfrmJsonTable }

procedure TfrmJsonTable.BuildTable(ListSource: TForm; ListNode: TTreeNode;
  IndexRow: integer; const v: Variant; const NodeKey: string);
var
  d,cw:IJSONDocument;
  e:IJSONEnumerator;
  i,j,k,l,n1,n2:integer;
  sl:TStringList;
  lc:TListColumn;
  vt:TVarType;
begin
  //assert TVarData(v).VType=varArray or varUnknown
  FListSource:=ListSource;
  FListNode:=ListNode;
  ListView1.Columns.BeginUpdate;
  ListView1.Items.BeginUpdate;
  try
    //ListView1.Clear;
    //ListView1.Columns.Clear;

    n1:=VarArrayLowBound(v,1);//assert 0
    n2:=VarArrayHighBound(v,1);

    i:=n2-n1+1;
    ListView1.Items.Count:=i;
    SetLength(FItems,i);
    SetLength(FIndexes,0);

    sl:=TStringList.Create;
    try
      cw:=JSON;
      for i:=n1 to n2 do
       begin
        d:=JSON(v[i]);
        if NodeKey<>'' then d:=JSON(d[NodeKey]);
        if d=nil then d:=JSON;//?
        FItems[i-n1]:=d;
        if d<>nil then
         begin
          e:=JSONEnum(d);
          j:=0;
          while e.Next do
           begin

            //guess column width
            vt:=PVarData(e.v0).VType;
            l:=0;//default
            if (vt and varArray)=0 then
              case vt of
                varNull,varEmpty:;
                varOleStr,varString:
                  l:=Length(VarToStr(e.Value));
                varBoolean:;
                varUnknown,varDispatch:l:=Length(e.Key);//
                varShortInt,varSmallint,varInteger,
                varSingle,varDouble,varCurrency,//?
                $000E,//varDecimal
                varByte,varWord,varLongWord,varInt64,
                $0015://varWord64
                  l:=Length(VarToStr(e.Value))+2;
              end;

            //list key
            k:=sl.IndexOf(e.Key);
            if k=-1 then
             begin
              inc(j);
              if j<sl.Count then
                sl.Insert(j,e.Key)
              else
                sl.Add(e.Key);
              if l=0 then l:=Length(e.Key);              
              cw[e.Key]:=l;
             end
            else
             begin
              j:=k;
              if l>cw[e.Key] then cw[e.Key]:=l;
             end;

           end;
         end;
       end;

      if sl.Count=0 then sl.Add('?');

      SetLength(FKeys,sl.Count);
      for i:=0 to sl.Count-1 do
       begin
        FKeys[i]:=sl[i];
        lc:=ListView1.Columns.Add;
        lc.Caption:=sl[i];
        lc.Tag:=i+1;//column re-ordering garbles TListColumn.Index, use .Tag instead
        l:=cw[sl[i]];
        if l<4 then l:=4;
        if l>80 then l:=80;
        lc.Width:=(l+2)*8;//optimistic guess
        //lc.Alignment? see below
       end;

    finally
      sl.Free;
    end;
    if (IndexRow>0) and (IndexRow<ListView1.Items.Count) then
      ListView1.ItemIndex:=IndexRow;
  finally
    ListView1.Items.EndUpdate;
    ListView1.Columns.EndUpdate;
  end;
end;

procedure TfrmJsonTable.ListView1Data(Sender: TObject; Item: TListItem);
var
  d:IJSONDocument;
  e:IJSONEnumerator;
  c:TListColumn;
  i,k,l:integer;
  v1:Variant;
  vt:TVarType;
  s,t:string;
  ee:Extended;
  tc:char;
begin
  //assert Item.SubItems.Count=0
  for i:=0 to ListView1.Columns.Count-1 do
   begin
    v1:=FItems[Item.Index][FKeys[i]];

    vt:=TVarData(v1).VType;
    if (vt and varArray)<>0 then
     begin
      //assert VarArrayDimCount(xValue)=1
      l:=VarArrayHighBound(v1,1)-
        VarArrayLowBound(v1,1)+1;
      if l=0 then
        s:='[]'
      else
        s:=Format('[%s#%d]',[VarTypeStr(vt),l]);
     end
    else
      case vt of
        //
        varNull,varEmpty:
          s:='';//'(null)';
        varOleStr,varString:
         begin
          s:=VarToStr(v1);
          l:=Length(s);
          for k:=1 to l do
            if s[k]<' ' then
              s[k]:=' ';
         end;
        varBoolean:
          if v1 then
            s:='true'
          else
            s:='false';
        varUnknown,varDispatch:
          if (TVarData(v1).VUnknown<>nil) and
            (IUnknown(v1).QueryInterface(IJSONDocument,d)=S_OK) then
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
                    try
                      s:=VarToStr(e.Value);
                      if Length(s)>32 then s:=Copy(s,1,30)+'...';
                    except
                      t:='?';
                    end;
                end;
               end;
              s[1]:='{';
              if e.EOF then s:=s+'}' else s:=s+' ...';
             end;
           end
          else
            s:='('+VarTypeStr(vt)+')???';
        varShortInt,varSmallint,varInteger,
        $000E,//varDecimal
        varByte,varWord,varLongWord,varInt64,
        $0015://varWord64
         begin
          c:=ListView1.Column[i];
          c.Alignment:=taRightJustify;
          s:=VarToStr(v1);
          //TODO: align floats on decimal separator?
         end;
        varSingle,varDouble,varCurrency:
         begin
          //auto detect (max) number of digits after floating point
          //abusing ImageIndex here (don't use Tag as it's in use to correct variable column order)
          ee:=v1;
          t:=Format('%10.8f',[Frac(Abs(ee))]);
          k:=8;
          if t[10]='0' then tc:='0' else tc:='9';
          while (k>0) and (t[2+k]=tc) do dec(k);
          c:=ListView1.Column[i];
          c.Alignment:=taRightJustify;
          if c.ImageIndex<k then
            c.ImageIndex:=k //TODO: invalidate column?
          else
            k:=c.ImageIndex;
          s:=Format('%.*f',[k,ee]);
          //TODO: align floats on decimal separator?
         end
        else
          s:=VarToStr(v1);
      end;

    if i=0 then
      Item.Caption:=s
    else
      Item.SubItems.Add(s);
   end;
end;

procedure TfrmJsonTable.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.WndParent:=GetDesktopWindow;
end;

procedure TfrmJsonTable.DoShow;
begin
  inherited;
  ShowWindow(Application.Handle,SW_HIDE);
end;

procedure TfrmJsonTable.EditCopy1Execute(Sender: TObject);
var
  s:string;
  i,j:integer;
  li:TListItem;
begin
  Screen.Cursor:=crHourGlass;
  try
    //TODO: update to possibly altered column sequence (use TListColumn.Tag)

    //if IncludeColumns then
    s:=FKeys[0];
    for i:=1 to Length(FKeys)-1 do
      s:=s+#9+StripTab(FKeys[i]);

    s:=s+#13#10;

    for i:=0 to ListView1.Items.Count-1 do
     begin
      li:=ListView1.Items[i];
      if li.Selected then
       begin
        s:=s+li.Caption;
        for j:=0 to li.SubItems.Count-1 do
          s:=s+#9+StripTab(li.SubItems[j]);
        s:=s+#13#10;
       end;
     end;
    Clipboard.AsText:=s;
  finally
    Screen.Cursor:=crDefault;
  end;
end;

procedure TfrmJsonTable.EditSelectAll1Execute(Sender: TObject);
begin
  ListView1.SelectAll;
end;

procedure TfrmJsonTable.ListView1MouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  i,t:integer;
  s:TScrollInfo;
begin
  //capture column index for ListView1DblClick event handler
  s.cbSize:=SizeOf(TScrollInfo);
  s.fMask:=SIF_ALL;
  GetScrollInfo(ListView1.Handle,SB_HORZ,s);
  t:=-s.nPos;
  i:=0;
  while (i<ListView1.Columns.Count) and (t<x) do
   begin
    inc(t,Listview1.Column[i].Width);
    inc(i);
   end;
  if i=0 then FCSel:=nil else FCSel:=ListView1.Columns[i-1];
end;

procedure TfrmJsonTable.ListView1DblClick(Sender: TObject);
var
  n:TTreeNode;
  s:string;
  i,l:integer;
begin                 
  Screen.Cursor:=crHourGlass;
  try
    if Length(FIndexes)=0 then
      i:=ListView1.ItemFocused.Index
    else
      i:=FIndexes[ListView1.ItemFocused.Index];
    FListNode.Expand(false);
    n:=FListNode[i];
    if FCSel<>nil then
     begin
      n.Expand(false);
      s:=FKeys[FCSel.Tag-1]+' ';
      i:=0;
      l:=Length(s);
      while (i<n.Count) and (Copy(n[i].Text,1,l)<>s) do inc(i);
      if i<n.Count then n:=n[i];
      FCSel:=nil;
     end;
    n.TreeView.Selected:=n;
    //FListSource.BringToFront;//?
    FListSource.SetFocus;
    Close;//TODO: if not CtrlPressed?
  finally
    Screen.Cursor:=crDefault;
  end;
end;

procedure TfrmJsonTable.ListView1ColumnRightClick(Sender: TObject;
  Column: TListColumn; Point: TPoint);
var
  i,t:integer;
  s:TScrollInfo;
  p:TPoint;
begin
  //FCSel:=Column;
  //argument Column is not accurate when scrolled horizontally!
  s.cbSize:=SizeOf(TScrollInfo);
  s.fMask:=SIF_ALL;
  GetScrollInfo(ListView1.Handle,SB_HORZ,s);
  t:=0;//t:=-s.nPos;//?
  i:=0;
  while (i<ListView1.Columns.Count) and (t<Point.x) do
   begin
    inc(t,Listview1.Column[i].Width);
    inc(i);
   end;
  if i=0 then FCSel:=nil else FCSel:=ListView1.Columns[i-1];

  p:=ListView1.ClientToScreen(Point);
  PopupMenu1.Popup(p.X-s.nPos,p.Y);
end;

procedure TfrmJsonTable.Removecolumn1Click(Sender: TObject);
var
  t,i:integer;
  c:TListColumn;
begin
  if FCSel<>nil then
   begin
    ListView1.Columns.BeginUpdate;
    ListView1.Items.BeginUpdate;
    try
      t:=FCSel.Tag-1;
      ListView1.Columns.Delete(FCSel.Index);
      for i:=t to Length(FKeys)-2 do FKeys[i]:=FKeys[i+1];
      for i:=0 to ListView1.Columns.Count-1 do
       begin
        c:=ListView1.Column[i];
        if c.Tag>t then c.Tag:=c.Tag-1;
       end;
    finally
      ListView1.Items.EndUpdate;
      ListView1.Columns.EndUpdate;;
    end;
   end;
end;

procedure TfrmJsonTable.Sortascending1Click(Sender: TObject);
begin
  Screen.Cursor:=crHourGlass;
  try
    if FCSel<>nil then
      SortItems(FKeys[FCSel.Tag-1],true);
    ListView1.Invalidate;
  finally
    Screen.Cursor:=crDefault;
  end;
end;

procedure TfrmJsonTable.Sortdescending1Click(Sender: TObject);
begin
  Screen.Cursor:=crHourGlass;
  try
    if FCSel<>nil then
      SortItems(FKeys[FCSel.Tag-1],false);
    ListView1.Invalidate;
  finally
    Screen.Cursor:=crDefault;
  end;
end;

function VarSortStr(const v:Variant):string;
var
  s,t:string;
  d:IJSONDocument;
  e:IJSONEnumerator;
  vt:TVarType;
  ii:Int64;
  ee:Extended;
begin
  vt:=TVarData(v).VType;
  case vt of
    varBoolean:
      if v then
        s:='--b1'
      else
        s:='--b0';
    varUnknown,varDispatch:
      if (TVarData(v).VUnknown<>nil) and
        (IUnknown(v).QueryInterface(IJSONDocument,d)=S_OK) then
       begin
        e:=(d as IJSONEnumerable).NewEnumerator;
        if e.EOF then s:='{}' else
         begin
          s:='';
          while e.Next and (Length(s)<255) do
           begin
            s:=s+','+e.Key;
            vt:=TVarData(e.Value).VType;
            case vt of
              varNull,varEmpty:;//s:=s+': null';
              varShortInt,varSmallint,varInteger,
              //varSingle,varDouble,varCurrency,//?
              $000E,//varDecimal
              varByte,varWord,varLongWord,varInt64,
              $0015://varWord64
               begin
                ii:=v;
                s:=s+':'+Format('%20d',[ii]);
               end;
              varOleStr,varString:
               begin
                t:=VarToStr(e.Value);
                if Length(t)>30 then
                  s:=s+':"'+Copy(t,1,255)+'...'
                else
                  s:=s+':"'+t+'"';
               end;
              varBoolean:if e.Value then s:=s+':--b1' else s:=s+':--b0';
              varUnknown,varDispatch:s:=s+':?';
              varArray..(varArray or varTypeMask):
                s:=s+':#'+Format('%.10d',[VarArrayHighBound(e.Value,1)-
                  VarArrayLowBound(e.Value,1)+1]);
              else
                try
                  s:=VarToStr(e.Value);
                  if Length(s)>32 then s:=Copy(s,1,30)+'...';
                except
                  t:='?';
                end;
            end;
           end;
          s[1]:='{';
          if e.EOF then s:=s+'}' else s:=s+' ...';
         end;
       end
      else
        s:='('+VarTypeStr(vt)+')???';
    varShortInt,varSmallint,varInteger,
    $000E,//varDecimal
    varByte,varWord,varLongWord,varInt64,
    $0015://varWord64
     begin
      ii:=v;
      s:=Format('%20d',[ii]);
     end;
    varSingle,varDouble,varCurrency:
     begin
      ee:=v;
      s:=Format('%30.8f',[ee]);
     end;
    else
      try
        s:=VarToStr(v);//?
      except
        s:='???';
      end;
  end;
  Result:=s;
end;

type
  TSortData=class(TObject)
    Index:integer;
    Item:IJSONDocument;
  end;

procedure TfrmJsonTable.SortItems(const FieldName:WideString;Ascending:boolean);
var
  sl:TStringList;
  b:boolean;
  i,j,l:integer;
  d:TSortData;
begin
  //TODO: multi-level sort; ListView1ColumnClick

  sl:=TStringList.Create;
  try
    //sl.Sorted:=true? see sl.Sort below

    l:=Length(FItems);
    b:=Length(FIndexes)=0;
    for i:=0 to l-1 do
     begin
      d:=TSortData.Create;
      if b then d.Index:=i else d.Index:=FIndexes[i];
      d.Item:=FItems[i];
      sl.AddObject(VarSortStr(d.Item[FieldName]),d);
      FItems[i]:=nil;
     end;
    //assert sl.Count=l

    sl.Sort;

    SetLength(FIndexes,l);
    for i:=0 to l-1 do
     begin
      if Ascending then j:=i else j:=l-i-1;
      d:=sl.Objects[j] as TSortData;
      FItems[i]:=d.Item;
      FIndexes[i]:=d.Index;
      d.Item:=nil;
      d.Free;//since not done by TStringList...
     end;

  finally
    sl.Free;
    //caller does ListView1.Invalidate
  end;
end;

end.
