## Copyright [yyyy] [name of copyright owner]
## Licensed under the Apache License, Version 2.0 (the "License");
## http://sushihangover.blogspot.com
##
$run = 'stop'
$hotspotcmd = 'C:\Program Files\Connectify\ConnectifyCLI.exe'
if ($args.length -eq 1) {
    $run = $args[0]
}
$serviceState = Get-Service "Connectify"
if (($run -eq 'stop') -and ($args.length -eq 1 )) {
    if ($serviceState.Status -eq "Running") {
        & $hotspotcmd  hotspot stop
        services.ps1 $run "Connectify"
    } else {
        write-host "Connectify is not running"
    }
} elseif (($run -ne 'stop') -and ($args.length -eq 1 ))  {
    services.ps1 $run "Connectify"
    & 'C:\Program Files\Connectify\ConnectifyCLI.exe' hotspot $args[0]
    & 'C:\Program Files\Connectify\ConnectifyCLI.exe' config get
} elseif ($args.length -gt 1 ) {
    if ($serviceState.Status -ne "Running") {
        services.ps1 start "Connectify"
    }
    & 'C:\Program Files\Connectify\ConnectifyCLI.exe' $args[0] $args[1]
    if ($serviceState.Status -ne "Running") {
        services.ps1 stop "Connectify"
    }
}
