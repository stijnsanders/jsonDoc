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
    Height = 488
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
  object panSearch: TPanel
    Left = 0
    Top = 488
    Width = 1072
    Height = 36
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    Visible = False
    object Label1: TLabel
      Left = 8
      Top = 7
      Width = 29
      Height = 16
      Caption = '&Find:'
    end
    object txtFind: TEdit
      Left = 40
      Top = 4
      Width = 249
      Height = 24
      TabOrder = 0
      OnKeyPress = txtFindKeyPress
    end
    object btnFindPrev: TButton
      Left = 292
      Top = 4
      Width = 25
      Height = 25
      Caption = '<'
      TabOrder = 1
      OnClick = actSearchPrevExecute
    end
    object btnFindNext: TButton
      Left = 320
      Top = 4
      Width = 25
      Height = 25
      Caption = '>'
      TabOrder = 2
      OnClick = actSearchNextExecute
    end
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
    object EditCopyValue1: TAction
      Category = 'Edit'
      Caption = 'Copy &value'
      Hint = 'Copy value|Copies the value only to the clipboard'
      ShortCut = 24643
      OnExecute = EditCopyValue1Execute
    end
    object actFind: TAction
      Category = 'Search'
      Caption = 'Find...'
      ShortCut = 16454
      OnExecute = actFindExecute
    end
    object actSearchPrev: TAction
      Category = 'Search'
      Caption = 'Search Previous'
      ShortCut = 8306
      OnExecute = actSearchPrevExecute
    end
    object actSearchNext: TAction
      Category = 'Search'
      Caption = 'Search Next'
      ShortCut = 114
      OnExecute = actSearchNextExecute
    end
    object actSortChildren: TAction
      Category = 'Search'
      Caption = 'Sort Children'
      ShortCut = 16466
      OnExecute = actSortChildrenExecute
    end
  end
end
