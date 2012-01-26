## Copyright 2012 Robert Nees
## Licensed under the Apache License, Version 2.0 (the "License");
## http://sushihangover.blogspot.com
##
if ($args.length -eq 0) {
    try {
        $run = 'stop'
        $iTunesProcessTmp = Get-Process itunes -ErrorAction "SilentlyContinue"
        $iTunesProcessTmp | % { $_.CloseMainWindow() }
    }
    catch {
        # just hide/ignore any errors from iTunes....
    }
} else {
    $run = $args[0]
}
$serviceState = Get-Service "Apple Mobile Device"
#if ($serviceState.Status -eq "Running") {
#    $run = 'stop'
#} else {
#    $run = 'start'
#}
if (($run -eq 'stop' ) -and ($iTunesProcess)) {
    # Only shutdown itunes App if it was started within this PowerShell Session
    $iTunesProcess | % { $_.CloseMainWindow() }
}
services.ps1 $run "Apple Mobile Device"
services.ps1 $run "iPod Service"
services.ps1 $run "Bonjour Service"
if ($run -eq 'start') {
    $iTunesProcess = [Diagnostics.Process]::Start("C:\Program Files\iTunes\iTunes.exe", "backup")
}
