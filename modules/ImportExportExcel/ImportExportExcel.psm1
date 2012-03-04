Function Remove-ComObject { 
    [CmdletBinding()] 
    param() 
    end { 
        Start-Sleep -Milliseconds 500 
        [Management.Automation.ScopedItemOptions]$scopedOpt = 'ReadOnly, Constant' 
        Get-Variable -Scope 1 | Where-Object { 
        $_.Value.pstypenames -contains 'System.__ComObject' -and -not ($scopedOpt -band $_.Options) 
        } | Remove-Variable -Scope 1 -Verbose:([Bool]$PSBoundParameters['Verbose'].IsPresent) 
        [GC]::Collect() 
    }
}
Function Import-Excel { 
    [CmdletBinding()] 
    Param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$Path, 
        [Parameter(Mandatory=$false)][switch]$NoHeaders, 
        [Parameter(Mandatory=$false)][int]$startRow = 0,
        [Parameter(Mandatory=$false)][int]$rowsToImport = 999999,
        [Parameter(Mandatory=$false)][int]$workSheetNumber = 1,
        [Parameter(Mandatory=$false)][switch]$showProgress
    )
    $Path = if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path -Path (Get-Location) -ChildPath $Path} 
    if(!(Test-Path $Path) -or $Path -notmatch ".xls$|.xlsx$") { Write-Host "ERROR: Invalid excel file [$Path]." -ForeGroundColor Red; read-host "Press enter to continue"; exit } 
    $excel = New-Object -ComObject Excel.Application
    if (!$excel) { Write-Host "ERROR: Please install Excel first." -ForeGroundColor Red; read-host "Press enter to continue"; exit } 
    $content = @() 
    [datetime]$aDateReference = New-Object DateTime
    $workbooks = $excel.Workbooks 
    $workbook = $workbooks.Open($Path) 
    $worksheets = $workbook.Worksheets 
    $sheet = $worksheets.Item($workSheetNumber) 
    $range = $sheet.UsedRange 
    $rows = $range.Rows
    $rowCount = $rows.Count # set count now for performance reasons
    $columns = $range.Columns 
    $columnCount = $columns.Count # set count now for performance reasons
    $headers = @()
    $top = if ($NoHeaders) {
        $startRow #1
    } else {
        $startRow # what line to start on when retrieving data 
    }  
    if ($NoHeaders) { # If the Excel file has no headers, use Column1, Column2, etc... 
        for($i=1; $i -le $columnCount; $i++) {
            if ($showProgress.IsPresent) {
                Write-Progress -Id 1 -Activity "Creating Generic Headers for Excel Columns" -status "Column = $i"
            }
            $headers += "Column$i"
        }
    } else {
        if ($showProgress.IsPresent) {
            Write-Progress -Id 1 -Activity "Parsing Headers from Excel Worksheet" 
        }
        $i = 1
        $headers = $rows.Item($startRow - 1) | % {
            if ($showProgress.IsPresent) {
                Write-Progress -Id 2 -ParentId 1 -Activity "Creating Custom Headers for Excel Columns" -status "Column = $i"
                $i++
            }
            $_.Value2 
        }
        $headerCount = $headers.Count
        for($i=0; $i -lt $headerCounts; $i++) {
            if ($showProgress.IsPresent) {
                Write-Progress -Id 2 -ParentId 1 -Activity "Creating Header" -status "Column = $i" -percentComplete ($i / $headerCount * 100)
            }
            if(!$headers[$i]) { # If a column is missing a header, then create one
                $headers[$i] = "Column$($i+1)" 
            } 
        }  
    }
    $currentRow = 0
    for($r = $startRow; $r -le $rowCount; $r++) {  
        if ($showProgress.IsPresent) {
            Write-Progress -Id 1 -Activity "Parsing Excel Rows" -status "Excel Row = $r" -percentComplete ($r / $rowCount * 100)
        }
        $data = $rows.Item($r) | ForEach-Object { $_.Value2 } 
        $line = New-Object PSOBject
        $colTime = Measure-command {
            for($c=0; $c -lt $columnCount; $c++) {
                if ($showProgress.IsPresent) {
                    Write-Progress -Id 2 -ParentId 1 -Activity "Parsing Excel Cells" -status "Excel Column = $c" -percentComplete ($c / $columnCount * 100)
                }
#                if ([datetime]::tryparse($sheet.Cells.Item($r,$c+1).Text, [ref]$aDateReference)) {
#                    [datetime]$foo = [datetime]$sheet.Cells.Item($r, $c+1).Text
#                } else {
#                    $foo = $sheet.Cells.Item($r, $c+1).Value2
#                }
                $line | Add-Member NoteProperty $headers[$c]( $data[$c] )
            }
        }
        $content += $line
        $currentRow++
        if ($currentRow -ge $rowsToImport) {
            break
        }
    }
    do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($columns) } while($o -gt -1) 
    do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($rows) } while($o -gt -1) 
    do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($range) } while($o -gt -1) 
    do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sheet) } while($o -gt -1) 
    do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($worksheets) } while($o -gt -1) 
    $workbook.Close($false) 
    do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) } while($o -gt -1) 
    do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbooks) } while($o -gt -1) 
    $excel.Quit() 
    do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) } while($o -gt -1)
    return $content 
} 

function Export-Excel { 
  [CmdletBinding()] 
  Param([Parameter(Mandatory=$true)][string]$Path, 
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][PSObject]$InputObject, 
        [Parameter(Mandatory=$false)][ValidateSet("Line","ThickLine","DoubleLine")][string]$HeaderBorder, 
        [Parameter(Mandatory=$false)][switch]$BoldHeader, 
        [Parameter(Mandatory=$false)][switch]$Force 
        ) 
  $Path = if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path -Path (Get-Location) -ChildPath $Path} 
  if($Path -notmatch ".xls$|.xlsx$") { Write-Host "ERROR: Invalid file extension in Path [$Path]." -ForeGroundColor Red; return } 
  $excel = New-Object -ComObject Excel.Application 
  if(!$excel) { Write-Host "ERROR: Please install Excel first." -ForeGroundColor Red; return } 
  $workbook = $excel.Workbooks.Add() 
  $sheet = $workbook.Worksheets.Item(1) 
  $xml = ConvertTo-XML $InputObject # I couldn't figure out how else to read the NoteProperty names 
  $lines = $xml.Objects.Object.Property 
  for($r=2;$r-le$lines.Count;$r++) { 
    $fields = $lines[$r-1].Property 
    for($c=1;$c-le$fields.Count;$c++) { 
      if($r -eq 2) { $sheet.Cells.Item(1,$c) = $fields[$c-1].Name } 
      $sheet.Cells.Item($r,$c) = $fields[$c-1].InnerText 
      } 
    } 
  [void]($sheet.UsedRange).EntireColumn.AutoFit() 
  $headerRow = $sheet.Range("1:1") 
  if($BoldHeader) { $headerRow.Font.Bold = $true } 
  switch($HeaderBorder) { 
    "Line"       { $style = 1 } 
    "ThickLine"  { $style = 4 } 
    "DoubleLine" { $style = -4119 } 
    default      { $style = -4142 } 
    } 
  $headerRow.Borders.Item(9).LineStyle = $style 
  if($Force) { $excel.DisplayAlerts = $false } 
  $workbook.SaveAs($Path) 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($headerRow) } while($o -gt -1) 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sheet) } while($o -gt -1) 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) } while($o -gt -1) 
  $excel.ActiveWorkbook.Close($false) 
  $excel.Quit() 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) } while($o -gt -1) 
  return $Path 
  } 
 
Export-ModuleMember Export-Excel,Import-Excel,Remove-ComObject