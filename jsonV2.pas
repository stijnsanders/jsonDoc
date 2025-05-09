unit jsonV2;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdActns, ActnList;

type
  TfrmJsonTable = class(TForm)
    ListView1: TListView;
    ActionList1: TActionList;
    EditSelectAll1: TEditSelectAll;
    EditCopy1: TEditCopy;
    procedure EditSelectAll1Execute(Sender: TObject);
    procedure EditCopy1Execute(Sender: TObject);
    procedure ListView1DblClick(Sender: TObject);
  private
    FListSource:TForm;
    FListNode:TTreeNode;
  protected
    procedure DoShow; override;
    procedure CreateParams(var Params: TCreateParams); override;
  public
    procedure BuildTable(ListSource: TForm; ListNode: TTreeNode;
      const v: Variant);
  end;

var
  frmJsonTable: TfrmJsonTable;

implementation

uses jsonDoc, Clipbrd;

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
  const v: Variant);
var
  d,d1:IJSONDocument;
  e:IJSONEnumerator;
  i,j,k,l,n1,n2:integer;
  sl:TStringList;
  lc:TListColumn;
  li:TListItem;
  v1:Variant;
  vt:TVarType;
  s,t:string;
begin
  //assert TVarData(v).VType=varArray or varUnknown
  FListSource:=ListSource;
  FListNode:=ListNode;
  ListView1.Items.BeginUpdate;
  try
    //ListView1.Clear;
    //ListView1.Columns.Clear;

    n1:=VarArrayLowBound(v,1);//assert 0
    n2:=VarArrayHighBound(v,1);

    sl:=TStringList.Create;
    try
      for i:=n1 to n2 do
       begin
        d:=JSON(v[i]);
        if d<>nil then
         begin
          e:=JSONEnum(d);
          j:=0;
          while e.Next do
           begin
            k:=sl.IndexOf(e.Key);
            if k=-1 then
             begin
              inc(j);
              if j<sl.Count then
                sl.Insert(j,e.Key)
              else
                sl.Add(e.Key);
             end
            else
              j:=k;
           end;
         end;
       end;

      if sl.Count=0 then sl.Add('?');

      for i:=0 to sl.Count-1 do
       begin
        lc:=ListView1.Columns.Add;
        lc.Caption:=sl[i];
        lc.Width:=-1;//-2?
        //lc.Alignment? see below
       end;

      //TODO: switch to OwnerData

      for i:=n1 to n2 do
       begin
        d1:=JSON(v[i]);
        li:=ListView1.Items.Add;
        for j:=0 to sl.Count-1 do
         begin
          v1:=d1[sl[j]];

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
                 end
                else
                  s:='('+VarTypeStr(vt)+')???';
              varShortInt,varSmallint,varInteger,
              //varSingle,varDouble,varCurrency,//?
              $000E,//varDecimal
              varByte,varWord,varLongWord,varInt64,
              $0015://varWord64
               begin
                ListView1.Column[j].Alignment:=taRightJustify;
                s:=VarToStr(v1);
                //TODO: align floats on decimal separator? 
               end;
              else
                s:='('+VarTypeStr(vt)+') '+VarToStr(v1);
            end;

          if j=0 then
            li.Caption:=s
          else
            li.SubItems.Add(s);
         end;
       end;

    finally
      sl.Free;
    end;
  finally
    ListView1.Items.EndUpdate;
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
    //if IncludeColumns then
    s:=ListView1.Columns[0].Caption;
    for i:=1 to ListView1.Columns.Count-1 do
      s:=s+#9+StripTab(ListView1.Column[i].Caption);
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

procedure TfrmJsonTable.ListView1DblClick(Sender: TObject);
var
  n:TTreeNode;
begin
  Screen.Cursor:=crHourGlass;
  try
    FListNode.Expand(false);
    n:=FListNode[ListView1.ItemFocused.Index];
    n.Expand(false);
    {
    if FCIndex<>-1 then
     begin
      s:=ListView1.Column[FCIndex].Caption+' ';
      i:=0;
      l:=Length(s);
      //while (i<n.Count) and ((n[i] as TJSONNode).Key<>s) do inc(i);
      while (i<n.Count) and (Copy(n[i].Text,1,l)<>s) do inc(i);
      if i<n.Count then n:=n[i];
     end;
    }
    n.TreeView.Selected:=n;

    //FListSource.BringToFront;//?
    FListSource.SetFocus;
    Close;
  finally
    Screen.Cursor:=crDefault;
  end;
end;

end.
