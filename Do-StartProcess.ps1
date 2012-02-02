## Copyright 2012 Robert Nees
## Licensed under the Apache License, Version 2.0 (the "License");
## http://sushihangover.blogspot.com
##
function startProcess {
    [cmdletbinding(defaultparametersetname="All")]
    param(
        [parameter(
            parametersetname="All",
            mandatory=$true,
            position=1)]      
        [string]$cliCmd,
        [parameter(
            parametersetname="All",
            mandatory=$false,
            position=2)]
        [string]$cmdArgs="",
        [parameter(
            parametersetname="All",
            mandatory=$false,
            position=3)]
        [string]$cmdPriority=[System.Diagnostics.ProcessPriorityClass]::Idle
    )

    begin {
        "parameterset: {0}; cliCmd: $cliCmd; cmdArgs: $cmdArgs; cmdPriority: $cmdPriority" -f $pscmdlet.parametersetname, $cliCmd, $cmdArgs, $cmdPriority
    }
    end {
    	$ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    	$ProcessInfo.FileName = $cliCmd
	    $ProcessInfo.Arguments = $cmdArgs
	    $ProcessInfo.UseShellExecute = $False
	    $newProcess = [System.Diagnostics.Process]::Start($ProcessInfo)
        $newProcess.PriorityClass = $cmdPriority
        $newProcess.WaitForExit()
    }
}
