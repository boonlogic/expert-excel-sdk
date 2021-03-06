Attribute VB_Name = "results"

Private Function GetStatus() As Boolean
    GetStatus = True
    
    Dim label As String
    label = Range("currentNano").Value
    
    Range("status").Value = "getting results"
    Dim Client As New WebClient
    On Error GoTo Err
    Client.BaseUrl = Worksheets(label).Range("url").Value
    Client.TimeoutMs = 90000
    Client.SetProxy Worksheets(label).Range("proxy").Value
    
    Dim Request As New WebRequest
    Request.Resource = "nanoStatus/{label}"
    Request.Method = WebMethod.HttpGet
    Request.AddUrlSegment "label", label
    Request.AddQuerystringParam "api-tenant", Worksheets(label).Range("apitenant").Value
    Request.AddQuerystringParam "results", "numClusters,totalInferences,averageInferenceTime"
    Request.AddHeader "x-token", Worksheets(label).Range("xtoken").Value

    Dim Response As WebResponse
    Set Response = Client.Execute(Request)
    
    On Error GoTo JSONErr
    Dim json As Object, tempResponse As String
    tempResponse = Right(Response.Content, Len(Response.Content) - InStr(Response.Content, "{") + 1)
    
    Set json = JsonConverter.ParseJson(tempResponse)
    If Response.StatusCode <> 200 Then
        MsgBox "NANO ERROR:" & vbNewLine & "   " & json("message")
        GetStatus = False
    Else
        Range("numClusters").Value = json("numClusters") - 1
        Range("totalInferences").Value = json("totalInferences")
        Range("avgClusterTime").Value = json("averageInferenceTime")
    End If
    
    Range("status").Value = "finished"
    
Exit Function

Err:
    MsgBox "Status call failed: " & Err.Description
    GetStatus = False
    Exit Function

JSONErr:
    MsgBox "Response error: status"
    GetStatus = False
    Exit Function

End Function

Private Function GetResults() As Variant
    GetResults = True
    
    Dim label As String
    label = Range("currentNano").Value
    
    Range("status").Value = "getting results"
    Dim Client As New WebClient
    
    On Error GoTo Err
    Client.BaseUrl = Worksheets(label).Range("url").Value
    Client.TimeoutMs = 90000
    Client.SetProxy Worksheets(label).Range("proxy").Value
    
    Dim Request As New WebRequest
    Request.Resource = "nanoResults/{label}"
    Request.Method = WebMethod.HttpGet
    Request.AddUrlSegment "label", label
    Request.AddQuerystringParam "api-tenant", Worksheets(label).Range("apitenant").Value
    Request.AddQuerystringParam "results", "ID,RI,DI,FI"
    Request.AddHeader "x-token", Worksheets(label).Range("xtoken").Value

    Dim Response As WebResponse
    Set Response = Client.Execute(Request)
    
    On Error GoTo JSONErr
    Dim json As Object, tempResponse As String
    tempResponse = Right(Response.Content, Len(Response.Content) - InStr(Response.Content, "{") + 1)
    
    Set json = JsonConverter.ParseJson(tempResponse)
    If Response.StatusCode <> 200 Then
        
        MsgBox "NANO ERROR:" & vbNewLine & "   " & json("message")
        GetResults = False
    End If
    
    Set GetResults = json
    Range("status").Value = "finished"
    
Exit Function
    
Err:
    MsgBox "Results call failed: " & Err.Description
    GetResults = False
    Exit Function

JSONErr:
    MsgBox "Response error: results"
    GetResults = False
    Exit Function

End Function

Function GetBufferStatus() As Variant
    GetBufferStatus = True
    
    Dim label As String
    label = Range("currentNano").Value
    
    Range("status").Value = "getting buffer status"
    Dim Client As New WebClient
    
    On Error GoTo Err
    Client.BaseUrl = Worksheets(label).Range("url").Value
    Client.TimeoutMs = 90000
    Client.SetProxy Worksheets(label).Range("proxy").Value
    
    Dim Request As New WebRequest
    Request.Resource = "bufferStatus/{label}"
    Request.Method = WebMethod.HttpGet
    Request.AddUrlSegment "label", label
    Request.AddQuerystringParam "api-tenant", Worksheets(label).Range("apitenant").Value
    Request.AddHeader "x-token", Worksheets(label).Range("xtoken").Value

    Dim Response As WebResponse
    Set Response = Client.Execute(Request)
    
    On Error GoTo JSONErr
    Dim json As Object, tempResponse As String
    tempResponse = Right(Response.Content, Len(Response.Content) - InStr(Response.Content, "{") + 1)
    
    Set json = JsonConverter.ParseJson(tempResponse)
    If Response.StatusCode <> 200 Then
        MsgBox "NANO ERROR:" & vbNewLine & "   " & json("message")
        GetBufferStatus = False
    Else
        GetBufferStatus = Response.Content
    End If
    
    Range("status").Value = "finished"
    
Exit Function

Err:
    MsgBox "Buffer status failed: " & Err.Description
    GetBufferStatus = False
    Exit Function

JSONErr:
    MsgBox "Response error: buffer status"
    GetBufferStatus = False
    Exit Function

End Function

Private Function LoadData(PostBody As String, Optional Append As Boolean = False) As Boolean
    LoadData = True

    On Error GoTo Err
    ' If Range("numFeatures") <> Selection.Columns.Count Then
    '     MsgBox "Feature count doesn't match. Reconfigure or choose different vector length"
    '     LoadData = False
    '     Exit Function
    ' End If
    
    Dim label As String
    label = Range("currentNano").Value
    
    Dim Client As New WebClient

    Client.BaseUrl = Worksheets(label).Range("url").Value
    Client.TimeoutMs = 120000
    Client.SetProxy Worksheets(label).Range("proxy").Value
    
    Dim Request As New WebRequest
    Request.RequestFormat = WebFormat.json

    Request.Resource = "data/{label}"
    
    Request.Method = WebMethod.HttpPost
    Dim bndry As String
    bndry = "----WebKitFormBoundaryW34T6HD7JCW8"
    Request.ContentType = "multipart/form-data; boundary=" & bndry
        
    Request.AddHeader "x-token", Worksheets(label).Range("xtoken").Value
    
    Dim dataType As String
    dataType = Application.International(xlListSeparator)
    If dataType = "," Then
        dataType = "csv"
    Else
        dataType = "csv-c"
    End If
    
    Request.AddUrlSegment "label", label
    Request.AddQuerystringParam "runNano", "false"
    Request.AddQuerystringParam "fileType", dataType
    Request.AddQuerystringParam "gzip", "false"
    Request.AddQuerystringParam "results", ""
    Request.AddQuerystringParam "api-tenant", Worksheets(label).Range("apitenant").Value
    If Append Then
        Request.AddQuerystringParam "appendData", "true"
    Else
        Request.AddQuerystringParam "appendData", "false"
    End If
    Request.Body = PostBody
    
    Request.ResponseFormat = WebFormat.json
    Set Response = Client.Execute(Request)
    
    Dim json As Object, tempResponse As String
    tempResponse = Right(Response.Content, Len(Response.Content) - InStr(Response.Content, "{") + 1)
    
    If Response.StatusCode <> 200 Then
        On Error GoTo JSONErr
        Set json = JsonConverter.ParseJson(tempResponse)
    
        MsgBox "NANO ERROR:" & vbNewLine & "   " & json("message")
        LoadData = False
        Exit Function
    End If
    
Exit Function
    
Err:
    Select Case Err.Number
        Case 6
            MsgBox "Load data failed: data size too big"
            LoadData = False
            Exit Function
            
        Case Else
            MsgBox "Load data failed: " & Err.Description
            LoadData = False
            Exit Function
    End Select

JSONErr:
    MsgBox "Response error: load data"
    LoadData = False
    Exit Function

End Function

Function PostLearning() As Boolean
    PostLearning = True
    
    Dim label As String
    label = Range("currentNano").Value
    
    Range("status").Value = "switching learning status"
    Dim Client As New WebClient
    
    On Error GoTo Err
    Client.BaseUrl = Worksheets(label).Range("url").Value
    Client.TimeoutMs = 90000
    Client.SetProxy Worksheets(label).Range("proxy").Value
    
    Dim status As String
    If Worksheets("BoonNano").Shapes("Learning").OLEFormat.Object.Value = 1 Then
        status = "true"
    Else
        status = "false"
    End If
    
    Dim Request As New WebRequest
    Request.Resource = "learning/{label}"
    Request.Method = WebMethod.HttpPost
    Request.AddUrlSegment "label", label
    Request.AddQuerystringParam "enable", status
    Request.AddQuerystringParam "api-tenant", Worksheets(label).Range("apitenant").Value
    Request.AddHeader "x-token", Worksheets(label).Range("xtoken").Value

    Dim Response As WebResponse
    Set Response = Client.Execute(Request)
    
    On Error GoTo JSONErr
    Dim json As Object, tempResponse As String
    tempResponse = Right(Response.Content, Len(Response.Content) - InStr(Response.Content, "{") + 1)
    
    If Response.StatusCode <> 200 Then
        Set json = JsonConverter.ParseJson(tempResponse)
        MsgBox "NANO ERROR:" & vbNewLine & "   " & json("message")
        PostLearning = False
    Else
        PostLearning = True
    End If
    
    Range("status").Value = "finished"
    
Exit Function

Err:
    MsgBox "Learning status failed: " & Err.Description
    PostLearning = False
    Exit Function

JSONErr:
    MsgBox "Response error: switch learning status"
    PostLearning = False
    Exit Function

End Function


Function GetLearning() As String
    GetLearning = "True"
    
    Dim label As String
    label = Range("currentNano").Value
    
    Dim Client As New WebClient
    
    On Error GoTo Err
    Client.BaseUrl = Worksheets(label).Range("url").Value
    Client.TimeoutMs = 90000
    Client.SetProxy Worksheets(label).Range("proxy").Value

    
    Dim Request As New WebRequest
    Request.Resource = "learning/{label}"
    Request.Method = WebMethod.HttpGet
    Request.AddUrlSegment "label", label
    Request.AddQuerystringParam "api-tenant", Worksheets(label).Range("apitenant").Value
    Request.AddHeader "x-token", Worksheets(label).Range("xtoken").Value

    Dim Response As WebResponse
    Set Response = Client.Execute(Request)
    
    On Error GoTo JSONErr
    Dim json As Object, tempResponse As String
    tempResponse = Right(Response.Content, Len(Response.Content) - InStr(Response.Content, "{") + 1)
    
    If Response.StatusCode <> 200 Then
        Set json = JsonConverter.ParseJson(tempResponse)
        MsgBox "NANO ERROR:" & vbNewLine & "   " & json("message")
        GetLearning = "False"
    Else
        GetLearning = tempResponse
    End If
    
    Range("status").Value = "finished"
    
Exit Function

Err:
    MsgBox "Get Learning failed: " & Err.Description
    GetLearning = "False"
    Exit Function

JSONErr:
    MsgBox "Response error: get learning"
    GetLearning = "False"
    Exit Function

End Function

Private Function PostDataLoop() As Boolean
    PostDataLoop = True

    Range("status").Value = "loading data"
    ' create selection as dictionary
    Dim row As Long, col As Long, arrString As String, tmpStr As String
    row = Selection.Rows.Count
    col = Selection.Columns.Count
    
    If InStr(Application.OperatingSystem, "Windows") > 0 Then
        returnStr = vbNewLine
    Else
        ' Macos or (linux??)
        returnStr = vbCr & vbNewLine
    End If
    
    Dim bndry As String
    bndry = "----WebKitFormBoundaryW34T6HD7JCW8"
    
    Dim PostBody As String, appendQ As Boolean, dataSubsection As Long, i As Long, j As Long, maxRow As Long, factor As Long, bytes() As Byte, separator As String
    
    
    '----------
    dataSubsection = 1
    factor = 15000 ' if too large, then the webrequest will fail with a 100 CONTINUE error
    separator = Application.International(xlListSeparator)
    Do While dataSubsection <= row
    
    arrString = ""
    maxRow = WorksheetFunction.Min(row, dataSubsection + WorksheetFunction.Floor(factor / col, 1) - 1)
    
    ' ------CSV-------
    For i = dataSubsection To maxRow
        tmpStr = ""
        For j = 1 To col
            tmpStr = tmpStr & separator & CStr(Selection.Cells(i, j))
        Next j
        tmpStr = Right(tmpStr, Len(tmpStr) - 1)
        arrString = arrString & tmpStr
        If i = maxRow Then
            arrString = arrString & returnStr
        Else
            arrString = arrString & separator
        End If
    Next i
    PostBody = "--" & bndry & returnStr _
    & "Content-Disposition: form-data; name=""data""; filename=""example.csv""" & returnStr _
    & "Content-Type: text/csv" & returnStr & returnStr _
    & arrString & returnStr _
    & "--" & bndry & "--" & returnStr

    ' -------RAW-------
'    Dim byteIndex As Long
'    For i = dataSubsection To maxRow
'        tmpStr = ""
'        For j = 1 To col
'            bytes = CStr(Selection.Cells(i, j))
'            For byteIndex = 0 To UBound(bytes) - LBound(bytes)
'                tmpStr = tmpStr & CStr(bytes(byteIndex))
'            Next byteIndex
'        Next j
'        arrString = arrString & tmpStr
'    Next i
'    bytes = arrString
'
'    PostBody = "--" & bndry & returnStr _
'    & "Content-Disposition: form-data; name=""data""; filename=""example.csv""" & returnStr _
'    & "Content-Type: application/macbinary" & returnStr & returnStr _
'    & arrString & returnStr _
'    & "--" & bndry & "--" & returnStr

    appendQ = dataSubsection <> 1
    
    If Not (LoadData(PostBody, appendQ)) Then
        PostDataLoop = False
        Exit Function
    End If
    
    dataSubsection = dataSubsection + WorksheetFunction.Floor(factor / col, 1)
    
    Loop
    
    '----------
    
    Range("status").Value = "finished"

End Function

Private Function RunNano() As Boolean
    RunNano = True
    On Error GoTo Err
    
    If Not (PostLearning) Then
        RunNano = False
        Exit Function
    End If
    
    If Not (PostDataLoop) Then
        RunNano = False
        Exit Function
    End If
    
    Dim label As String
    label = Range("currentNano").Value
    
    Range("status").Value = "running nano"
    Dim Client As New WebClient
    
    Client.BaseUrl = Worksheets(label).Range("url").Value
    Client.TimeoutMs = 90000
    Client.SetProxy Worksheets(label).Range("proxy").Value
    
    Dim Request As New WebRequest
    Request.Resource = "nanoRun/{label}"
    Request.Method = WebMethod.HttpPost
    Request.AddUrlSegment "label", label
    Request.AddQuerystringParam "api-tenant", Worksheets(label).Range("apitenant").Value
    Request.AddHeader "x-token", Worksheets(label).Range("xtoken").Value

    Dim Response As WebResponse
    Set Response = Client.Execute(Request)
    
    Dim json As Object, tempResponse As String
    tempResponse = Right(Response.Content, Len(Response.Content) - InStr(Response.Content, "{") + 1)
    
    If Response.StatusCode <> 200 Then
        On Error GoTo JSONErr
        Set json = JsonConverter.ParseJson(tempResponse)
        
        MsgBox "NANO ERROR:" & vbNewLine & "   " & json("message")
        RunNano = False
    Else
        If GetStatus Then
                ' On Error GoTo Err
                ExportAnomalies
            MsgBox "Clustering successful"
        Else
            RunNano = False
            Exit Function
        End If
    End If
    
    Range("status").Value = "finished"
Exit Function
    
Err:
    MsgBox "Clustering failed: " & Err.Description
    RunNano = False
    Exit Function

JSONErr:
    MsgBox "Response error: clustering"
    RunNano = False
    Exit Function
    
End Function

Private Function ExportAnomalies() As Boolean
    Dim results As Variant, label As String, t As Integer, startRow As Integer
    
'    label = "Anomalies"
'    If WorksheetExists(label) Then
'        Worksheets(label).Cells.Clear
'    Else
'        Set NewSheet = Worksheets.Add(After:=Worksheets("BoonNano"))
'        NewSheet.Name = label
'    End If
'    Worksheets("BoonNano").Activate
'
     Set results = GetResults
'
'    numAnomalies = 0
'    For i = 1 To results("RI").Count
'        If results("RI")(i) >= Worksheets("BoonNano").Range("anomalyIndex").Value Then
'            numAnomalies = numAnomalies + 1
'            For j = 1 To Worksheets("BoonNano").Range("streamingWindowSize").Value
'
'
'            Next j
'            Selection.Rows(i).Copy
'            Worksheets(label).Range("$A$" & numAnomalies).PasteSpecial (xlPasteValues)
'        End If
'    Next i
'    Worksheets("BoonNano").Range("numAnomalies").Value = numAnomalies
    
    label = "Results"
    If WorksheetExists(label) Then
        Worksheets(label).Cells.Clear
        ' startRow = Worksheets(label).Cells(Rows.Count, 1).End(xlUp) + 1
    Else
        Set NewSheet = Worksheets.Add(After:=Worksheets("BoonNano"))
        NewSheet.Name = label
        Worksheets("Results").Columns("F").Select
        ActiveWindow.FreezePanes = True
        
    End If
    
    startRow = 1
        Worksheets(label).Rows(1).Font.Bold = True
        Worksheets(label).Cells(1, 1) = "Pattern Number"
        Worksheets(label).Cells(1, 2) = "Cluster ID"
        Worksheets(label).Cells(1, 3) = "Anomaly Index"
        Worksheets(label).Cells(1, 4) = "Frequency Index"
        Worksheets(label).Cells(1, 5) = "Distance Index"

    For i = 1 To results("RI").Count
        Worksheets(label).Cells(i + startRow, 1) = i + startRow - 1
        Worksheets(label).Cells(i + startRow, 2) = results("ID")(i)
        Worksheets(label).Cells(i + startRow, 3) = results("RI")(i)
        Worksheets(label).Cells(i + startRow, 4) = results("FI")(i)
        Worksheets(label).Cells(i + startRow, 5) = results("DI")(i)
    Next i
    With Worksheets(label).Columns("A:F")
        .AutoFit
        .HorizontalAlignment = xlCenter
    End With
    
    Worksheets("BoonNano").Activate

End Function

Private Function WorksheetExists(ByVal WorksheetName As String) As Boolean
    Dim Sht As Worksheet

      For Each Sht In ActiveWorkbook.Worksheets
           If Application.Proper(Sht.Name) = Application.Proper(WorksheetName) Then
               WorksheetExists = True
               Exit Function
           End If
        Next Sht
    WorksheetExists = False
End Function

