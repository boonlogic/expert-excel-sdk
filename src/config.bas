Attribute VB_Name = "config"
Private Sub ConfigureNano()

    SetConfig
    
    Dim autotune As Boolean
    If Worksheets("BoonNano").Shapes("Autotune").OLEFormat.Object.Value = 1 Then
        AutotuneConfig
    End If
    
    
End Sub

Private Function AutotuneConfig() As Boolean
    AutotuneConfig = True
    
    On Error GoTo Err
    If Not (SetConfig) Then
        AutotuneConfig = False
        Exit Function
    End If
    If Not (Application.Run("results.PostDataLoop")) Then
        AutotuneConfig = False
        Exit Function
    End If
    
    Range("status").Value = "autotuning"
    Dim label As String, byFeat As Boolean
    label = Range("currentNano").Value
    
    Dim Client As New WebClient
    
    Client.BaseUrl = Worksheets(label).Range("url").Value
    Client.TimeoutMs = 120000
    Client.SetProxy Worksheets(label).Range("proxy").Value
    
    Dim Request As New WebRequest
    Request.Resource = "autoTune/{label}"
    Request.Method = WebMethod.HttpPost
    Request.AddUrlSegment "label", label
    
    Request.AddQuerystringParam "api-tenant", Worksheets(label).Range("apitenant").Value
    Request.AddHeader "x-token", Worksheets(label).Range("xtoken").Value

    Dim Response As WebResponse
    Set Response = Client.Execute(Request)
    
    
    If Response.StatusCode <> 200 Then
    
        On Error GoTo JSONErr
        Dim json As Object, tempResponse As String
        tempResponse = Right(Response.Content, Len(Response.Content) - InStr(Response.Content, "{") + 1)
        
        MsgBox "NANO ERROR:" & vbNewLine & "   " & json("message")
        AutotuneConfig = False
    Else
    
        If Not (GetConfig) Then
            AutotuneConfig = False
            Exit Function
        End If
        
    End If
    
    Range("status").Value = "finished"
    
 Exit Function
    
Err:
    AutotuneConfig = False
    Exit Function

JSONErr:
    If Response.StatusCode = 408 Then ' timeout
        MsgBox "Server timeout"
    Else
        MsgBox "Response error: autotune"
    End If
    AutotuneConfig = False
    Exit Function

End Function

Private Function GetConfig() As Boolean
    GetConfig = True

    Dim label As String
    label = Range("currentNano").Value
    
    Dim Client As New WebClient
    
    Client.BaseUrl = Worksheets(label).Range("url").Value
    Client.TimeoutMs = 120000
    Client.SetProxy Worksheets(label).Range("proxy").Value
    
    Dim Request As New WebRequest
    Request.Resource = "clusterConfig/{label}"
    Request.Method = WebMethod.HttpGet
    Request.AddUrlSegment "label", label
    
    Request.AddQuerystringParam "api-tenant", Worksheets(label).Range("apitenant").Value
    Request.AddHeader "x-token", Worksheets(label).Range("xtoken").Value

    Dim Response As WebResponse
    Set Response = Client.Execute(Request)
    
    
    Dim json As Object, tempResponse As String
    If Response.StatusCode <> 200 Then
        On Error GoTo JSONErr
        Set json = WebHelpers.ParseJson(Response.Content)
        
        MsgBox "NANO ERROR:" & vbNewLine & "   " & json("message")
        GetConfig = False
    Else
        tempResponse = Right(Response.Content, Len(Response.Content) - InStr(Response.Content, "{") + 1)
        Set json = JsonConverter.ParseJson(tempResponse)
        
        Worksheets("BoonNano").Range("percentVariation") = CDbl(Format(json("percentVariation"), "#,##0.00"))
        Dim col As String
        col = Split(Selection.Address, "$")(1)
        For i = 1 To Worksheets("BoonNano").Range("numFeatures")
            tmpName = col & "5"
            Worksheets("BoonNano").Range(tmpName) = json("features")(i)("minVal")
        
            tmpName = col & "4"
            Worksheets("BoonNano").Range(tmpName) = json("features")(i)("maxVal")
            
            tmpName = col & "3"
            Worksheets("BoonNano").Range(tmpName) = json("features")(i)("weight")
        
            tmpName = col & "6"
            Worksheets("BoonNano").Range(tmpName) = json("features")(i)("label")
        
            col = Split(Cells(1, Selection.Columns(i + 1).Column).Address, "$")(1)
        Next i
        On Error Resume Next
        Worksheets("BoonNano").Shapes("Cluster").Delete
        Application.Run ("PageSetup.ClusterButton")
        
    End If
    
    Exit Function
    
JSONErr:
    If Response.StatusCode = 408 Then ' timeout
        MsgBox "Server timeout"
    Else
        MsgBox "Response error: get config"
    End If
    GetConfig = False
    Exit Function
        
End Function

Private Sub CheckBlank(Name As String)
    With Worksheets("BoonNano")
    If IsEmpty(.Range(Name)) Then
        If Name = "numFeatures" Then
            .Range(Name).Value = Selection.Columns.Count
        ElseIf Name = "accuracy" Then
            .Range(Name).Value = 0.99
        ElseIf Name = "streamingWindowSize" Then
            .Range(Name).Value = 1
        ElseIf Name = "numericFormat" Then
            .Range(Name).Value = GetType
            .Range(Name).HorizontalAlignment = xlRight
        ElseIf Name = "percentVariation" Then
            .Range(Name).Value = 0.05
        ElseIf InStr(Name, "3") <> 0 Then ' check if in weights row
            .Range(Name).Value = 1
        ElseIf InStr(Name, "4") <> 0 Then ' check if in maxes row
            .Range(Name).Value = 10
        ElseIf InStr(Name, "5") <> 0 Then ' check if in mins row
            .Range(Name).Value = 0
        ElseIf InStr(Name, "6") <> 0 Then ' check if in labels row
            .Range(Name).Value = ""
        ElseIf Name = "anomalyIndex" Then
            .Range(Name).Value = 1000
        End If
    End If
    End With
End Sub


Private Function GetType() As String
    With Worksheets("BoonNano")
        Dim cell As Range, rng As Range, isInt As Boolean, isNative As Boolean, isFloat As Boolean, rmndr As Double
        isInt = False
        isNative = True
        isFloat = False
        
        Set rng = Selection
        For Each cell In rng.Cells
            If cell.Value = Int(cell.Value) Then ' it is integer
                If Abs(cell.Value) <> cell.Value Then ' negative value
                    isNative = False
                    isInt = True
                End If
            Else ' it has a decimal
                isFloat = True
                isNative = False
                isInt = False
                GetType = "float32"
            End If
        Next cell
        If isInt And isFloat = False Then
            GetType = "int16"
        ElseIf isNative And isFloat = False Then
            GetType = "uint16"
        End If
    End With
End Function


Private Function SetConfig() As Boolean
    SetConfig = True
    Application.DecimalSeparator = "."
    Application.UseSystemSeparators = True
    
    Range("status").Value = "configuring"
    Dim label As String, byFeat As Boolean, autotune As Boolean
    label = Range("currentNano").Value
    
    If Worksheets("BoonNano").Shapes("ByFeature").OLEFormat.Object.Value = 1 Then
        byFeat = True
    Else
        byFeat = False
    End If
    
    If Worksheets("BoonNano").Shapes("Autotune").OLEFormat.Object.Value = 1 Then
        autotune = True
    Else
        autotune = False
    End If
    
    Dim Client As New WebClient
    
    On Error GoTo Err
    Client.BaseUrl = Worksheets(label).Range("url").Value
    Client.TimeoutMs = 90000
    Client.SetProxy Worksheets(label).Range("proxy").Value
    
    Dim Request As New WebRequest
    Request.RequestFormat = WebFormat.json
    Request.ResponseFormat = WebFormat.json
    
    Request.Resource = "clusterConfig/{label}"
    Request.Method = WebMethod.HttpPost
    Request.AddUrlSegment "label", label
    Request.AddQuerystringParam "api-tenant", Worksheets(label).Range("apitenant").Value
    Request.AddHeader "x-token", Worksheets(label).Range("xtoken").Value
    Request.ContentType = "application/json"
    
    ' create config dictionary
    Dim config As New Dictionary
    Dim tmpName As String
    
    tmpName = "clusterMode"
    config.Add tmpName, "batch"
    
    tmpName = "accuracy"
    CheckBlank (tmpName)
    config.Add tmpName, Range(tmpName).Value
    
    Dim features() As Variant
    Dim col As String
    col = Split(Selection.Address, "$")(1)
    tmpName = "numFeatures"
    CheckBlank (tmpName)
    ReDim features(Range(tmpName).Value - 1) As Variant
    For i = LBound(features) To UBound(features)
        Set features(i) = New Dictionary
        tmpName = col & "5"
        CheckBlank (tmpName)
        features(i).Add "minVal", Range(tmpName).Value
        
        tmpName = col & "4"
        CheckBlank (tmpName)
        features(i).Add "maxVal", Range(tmpName).Value
        
        tmpName = col & "3"
        CheckBlank (tmpName)
        features(i).Add "weight", Range(tmpName).Value
        
        tmpName = col & "6"
        CheckBlank (tmpName)
        features(i).Add "label", Range(tmpName).Value
        
        
        col = Split(Cells(1, Selection.Columns(i + 2).Column).Address, "$")(1)
    Next i
    config.Add "features", features
    
    Dim autotuneDict As New Dictionary
    autotuneDict.Add "autoTuneByFeature", byFeat
    autotuneDict.Add "autoTunePV", autotune
    autotuneDict.Add "autoTuneRange", autotune
    autotuneDict.Add "maxClusters", 1000
    
    config.Add "autoTuning", autotuneDict
    
    tmpName = "numericFormat"
    CheckBlank (tmpName)
    config.Add tmpName, Range(tmpName).Value
        
    tmpName = "percentVariation"
    CheckBlank (tmpName)
    config.Add tmpName, Range(tmpName).Value
    
    tmpName = "streamingWindowSize"
    CheckBlank (tmpName)
    config.Add tmpName, Range(tmpName).Value
    
    tmpName = "anomalyIndex"
    CheckBlank (tmpName)
    
    ' ---------

    Set Request.Body = config

    Dim Response As WebResponse
    Set Response = Client.Execute(Request)
    
    Dim json As Object
    If Response.StatusCode <> 200 Then
        On Error GoTo JSONErr
        Set json = WebHelpers.ParseJson(Response.Content)
        
        MsgBox "NANO ERROR:" & vbNewLine & "   " & json("message")
        SetConfig = False
    Else
        Range("numClusters").Value = 0
        Range("totalInferences").Value = 0
        Range("avgClusterTime").Value = 0
        
        On Error Resume Next
        Worksheets("BoonNano").Shapes("Cluster").Delete
        Worksheets("BoonNano").Shapes("Reset").Delete
        Worksheets("BoonNano").Shapes("Learning").Delete
        Application.Run ("PageSetup.ClusterButton")
        Application.Run ("PageSetup.ResetBufferButton")
        Application.Run ("PageSetup.LearningCheckbox")
        
        Dim learn As String
        learn = Application.Run("results.GetLearning")
        If Left(learn, 1) = "t" Then
            Worksheets("BoonNano").Shapes("Learning").OLEFormat.Object.Value = 1
        ElseIf Left(learn, 1) = "f" Then
            Worksheets("BoonNano").Shapes("Learning").OLEFormat.Object.Value = 0
        Else
            Worksheets("BoonNano").Shapes("Learning").OLEFormat.Object.Value = 1
        End If
        
    End If
    
    Range("status").Value = "finished"
    
Exit Function

NanoErr:
    SetConfig = False
    Exit Function

Err:
    MsgBox "Configure failed: " & Err.Description
    SetConfig = False
    Exit Function
    
JSONErr:
    MsgBox "Response error: set config"
    SetConfig = False
    Exit Function

End Function

