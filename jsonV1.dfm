object frmJsonViewer: TfrmJsonViewer
  Left = 192
  Top = 124
  Width = 1088
  Height = 563
  Caption = 'jsonV'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDefault
  PixelsPerInch = 96
  TextHeight = 16
  object TreeView1: TTreeView
    Left = 0
    Top = 0
    Width = 1072
    Height = 525
    Align = alClient
    HideSelection = False
    Indent = 19
    ReadOnly = True
    TabOrder = 0
    ToolTips = False
    OnChange = TreeView1Change
    OnCreateNodeClass = TreeView1CreateNodeClass
    OnDblClick = TreeView1DblClick
    OnExpanding = TreeView1Expanding
  end
  object ActionList1: TActionList
    Left = 8
    Top = 8
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
