<#
.NOTES
Copyright 2012 Robert Nees
Licensed under the Apache License, Version 2.0 (the "License");
http://sushihangover.blogspot.com
.SYNOPSIS
System shutdown in X minutes
.DESCRIPTION
This script preforms a system shutdown or hibernate in X number of minutes
.EXAMPLE
Hibernate in 20 minutes:
Do-Shutdown.ps1 20 -type h 
.EXAMPLE
Shutdown now:
Do-Shutdown.ps1 0 -type s
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
            [string]$type = 'h'
)
write-host "Sleeping for" ($minutes) "minutes before shutdown (Ctrl-C to break)"
start-sleep ($minutes * 60)
shutdown /$type
Read-Host "Press ENTER to abort"
shutdown /a
