object frmJsonTable: TfrmJsonTable
  Left = 192
  Top = 124
  Width = 1088
  Height = 563
  Caption = 'jsonV Table View'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = True
  Position = poDefault
  PixelsPerInch = 96
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
    OnColumnRightClick = ListView1ColumnRightClick
    OnData = ListView1Data
    OnDblClick = ListView1DblClick
    OnMouseDown = ListView1MouseDown
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
  object PopupMenu1: TPopupMenu
    Left = 64
    Top = 48
    object Sortascending1: TMenuItem
      Caption = 'Sort &ascending'
      OnClick = Sortascending1Click
    end
    object Sortdescending1: TMenuItem
      Caption = 'Sort &descending'
      OnClick = Sortdescending1Click
    end
    object Removecolumn1: TMenuItem
      Caption = '&Hide column'
      OnClick = Removecolumn1Click
    end
  end
end
