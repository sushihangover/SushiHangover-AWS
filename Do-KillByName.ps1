<#
.NOTES
Copyright 2012 Robert Nees
Licensed under the Apache License, Version 2.0 (the "License");
http://sushihangover.blogspot.com
.SYNOPSIS
Kill process by name
.DESCRIPTION
This scripts provides a way to kill processes by name vs. Id
Do-KillByName.ps1 bonjour -whatif
.EXAMPLE
Do-KillByName.ps1 notepad
.EXAMPLE
Get-Process | Do-KillByName.ps1 -whatif | ft -AutoSize
.EXAMPLE
gwmi win32_process | where {$_.getowner().user -eq $env:username} | select handle | % { get-process -id $_.handle } | Do-killbyName -whatif
Kill all the processes that the current user is running (this includes the powershell console that is running this oneliner!!)
.LINK
http://sushihangover.blogspot.com
#>
[CmdletBinding()] 
Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$processName, 
    [Parameter(Mandatory=$false)][switch]$whatif
    )
Begin {
    $killList = @()
}
Process {
    if ($_ -is [System.Diagnostics.Process]) {
        $killMe = $_
    } else {
        $killMe = get-process | where {($_.Name -eq $processName)}
    }
    try {
        if ($killMe -is [System.Diagnostics.Process]) {
            $killList += $killMe
            if (!$whatif.IsPresent) {
                $killMe.Kill()
            }
        }
    } catch {
        write-host "No process named $processName found" -ForegroundColor Red -BackgroundColor White
    }
}
End {
    return $killList
}