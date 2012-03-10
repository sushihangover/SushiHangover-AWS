<#
.NOTES
Copyright 2012 Robert Nees
Licensed under the Apache License, Version 2.0 (the "License");
http://sushihangover.blogspot.com
.SYNOPSIS
Shutdown the computer with a Ctrl-C break
.DESCRIPTION
This scripts provides a visual countdown bar till computer is shutdown/rebooted/hibernate and 
you can use Ctrl-C to break this countdown
.EXAMPLE
Do-Shutdown.ps1 30
.LINK
http://sushihangover.blogspot.com
#>
Param (
        [parameter(
            parametersetname="All",
            mandatory=$true,
            position=1)]
            [Alias("min")]
            [int]$minutes,
        [parameter(
            parametersetname="All",
            mandatory=$false,
            position=2)]
            [string]$type = 'h',
        [parameter(
            parametersetname="All",
            mandatory=$false,
            position=3)]
            [switch]$whatif
)
$timeStep = 5
try {
    [console]::TreatControlCAsInput = $true
    for ($minutesLeft = $minutes - 1; $minutesLeft -ge 0 ; $minutesLeft--) {
        Write-Progress -Id 1 -Activity "Press Ctrl-C to Terminate Shutdown" -status "Shutdown in $minutesLeft minutes" -percentComplete (($minutesLeft / ($minutes)) * 100)
        for ($secondsLeft = 60; $secondsLeft -gt 0 ; $secondsLeft = $secondsLeft - $timeStep) {
            Write-Progress -Id 2 -ParentID 1 -Activity " " -status "+ $secondsLeft Seconds" -percentComplete (($secondsLeft / 60) * 100)
            Start-Sleep -s $timeStep
            if ([console]::KeyAvailable) {
                $key = [system.console]::readkey($true)
                if (($key.modifiers -band [consolemodifiers]"control") -and ($key.key -eq "C")) {
                    $breaking = $true
                    break
                }
            }
        }
    }
    if (!$breaking) {
        if ($whatif.IsPresent) {
            write-host 'Whatif: shutdown /' + $type
        } else {
            shutdown /$type
        }
    }
} finally {
    [console]::TreatControlCAsInput = $false
}
