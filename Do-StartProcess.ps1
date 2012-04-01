<#
.NOTES
Copyright 2012 Robert Nees
Licensed under the Apache License, Version 2.0 (the "License");
http://sushihangover.blogspot.com
.SYNOPSIS
Start a background process and return standard output
.DESCRIPTION
This script/function provides a wrapper to System.Diagnostics.Process and Added stdout as the return 'object', it will be returned as
an array of strings

Priority Parameter Options:
    Normal 	
    Idle (default)
    High
    RealTime
    BelowNormal
    AboveNormal

.EXAMPLE
$ffprobe = "ffprobe.exe"
$probeCMDLine = ' -prefix -show_streams -i "' + $file.FullName + '"'
$stdOut = Do-StartProcess.ps1 $ffprobe $probeCMDLine
.LINK
http://sushihangover.blogspot.com
#>
function Do-StartProcess {
    param(
        [parameter(mandatory=$true,position=1)][Alias("Cmd")][string]$cliCmd,
        [parameter(mandatory=$false,position=2)][Alias("Args")][string]$cmdArgs="",
        [parameter(mandatory=$false,position=3)][Alias("NoWait")][switch]$noWaitForExit,
        [parameter(mandatory=$false,position=4)][Alias("Priority")]
            [string]$cmdPriority=[System.Diagnostics.ProcessPriorityClass]::Idle
    )
    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = $cliCmd
	$ProcessInfo.Arguments = $cmdArgs
	$ProcessInfo.UseShellExecute = $False
    $ProcessInfo.RedirectStandardInput = $false
    $ProcessInfo.RedirectStandardOutput = $true
	$newProcess = [System.Diagnostics.Process]::Start($ProcessInfo)
    $newProcess.PriorityClass = $cmdPriority
    if (!$noWaitForExit.IsPresent) {
#        $newProcess.WaitForExit()
        $stdOut = @()
#        $stdOut = $newProcess.StandardOutput.Read()
        do {
            $readLine = $newProcess.StandardOutput.ReadLine()
            $stdOut += $readLine
        } while ($readLine -ne $null)
    }
    return $stdOut
}
