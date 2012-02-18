<#
.NOTES
Copyright 2012 Robert Nees
Licensed under the Apache License, Version 2.0 (the "License");
http://sushihangover.blogspot.com
.SYNOPSIS
Ctrl-C wrapper for running jobs
.DESCRIPTION
This scripts provides a wrapper to terminate a running background job by Ctrl-C
.EXAMPLE

.LINK
http://sushihangover.blogspot.com
#>
Param (
        [parameter(
            parametersetname="Main",
            mandatory=$true,
            position=1)]
            [object]$jobWatch
 )
try {
    write-host "Press Ctrl-C to terminate" $jobWatch.Command
    [console]::TreatControlCAsInput = $true
    while ($jobWatch.State -eq 'Running') {
        Start-Sleep -s 5
        if ([console]::KeyAvailable) {
            $key = [system.console]::readkey($true)
            if (($key.modifiers -band [consolemodifiers]"control") -and
                ($key.key -eq "C"))
            {
                write-host "Terminating..."
                $jobWatch | stop-job
                break
            }
        }
    }

} finally {
    [console]::TreatControlCAsInput = $false
    $jobWatch
}
receive-job -Id $jobWatch.Id -Keep 
