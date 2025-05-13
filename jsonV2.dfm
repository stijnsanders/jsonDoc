object frmJsonTable: TfrmJsonTable
  Left = 192
  Top = 124
  Caption = 'jsonV Table View'
  ClientHeight = 524
  ClientWidth = 1072
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poDefault
  TextHeight = 16
  object ListView1: TListView
    Left = 0
    Top = 0
    Width = 1072
    Height = 524
    Align = alClient
    Columns = <>
    FullDrag = True
    GridLines = True
    HideSelection = False
    MultiSelect = True
    OwnerData = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnData = ListView1Data
    OnDblClick = ListView1DblClick
  end
  object ActionList1: TActionList
    Left = 32
    Top = 48
    object EditSelectAll1: TEditSelectAll
      Category = 'Edit'
      Caption = 'Select &All'
      Hint = 'Select All|Selects the entire document'
      ShortCut = 16449
      OnExecute = EditSelectAll1Execute
    end
    object EditCopy1: TEditCopy
      Category = 'Edit'
      Caption = '&Copy'
      Hint = 'Copy|Copies the selection and puts it on the Clipboard'
      ImageIndex = 1
      ShortCut = 16451
      OnExecute = EditCopy1Execute
    end
  end
end
