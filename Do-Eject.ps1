<#
.NOTES
Copyright 2012 Robert Nees
Licensed under the Apache License, Version 2.0 (the "License");
http://sushihangover.blogspot.com
.SYNOPSIS
Eject Removable Media
.DESCRIPTION
This scripts provides a way to eject a removable media drive via the cmd line
.EXAMPLE
Do-Eject.ps1 E:
.LINK
http://sushihangover.blogspot.com
#>
Param (
        [parameter(
            parametersetname="Main")]
            [switch]$help,
        [parameter(
            parametersetname="Main",
            mandatory=$false,
            position=1)]
            [Alias("drive")]
            [string]$driveLetter = '',
        [parameter(
            parametersetname="Main",
            mandatory=$false,
            position=2)]
            [Alias("remote")]
            [string]$remoteServer = 'localhost'

)
if ($help.IsPresent) {
    help ($MyInvocation.MyCommand.Name) -examples
    exit
}
if ($driveLetter -eq '') {
    # List removable media and exit
#    Get-WMIObject Win32_LogicalDisk -filter "DriveType=2" -computer $
    write-host "`nRemovable Media currently present:" -foregroundcolor green
    Get-WMIObject Win32_LogicalDisk -filter "DriveType=2" -computer $remoteServer | format-tablE -Property DeviceID, VolumeName -AutoSize -HideTableHeaders
    exit
} else {
    $cd_drive = $driveLetter
    if ($remoteServer = 'localhost') {
        $sa = New-Object -comObject Shell.Application
        $sa.Namespace(17).ParseName("$cd_drive").InvokeVerb("Eject")
    } else {
        Invoke-Command -ComputerName $remoteServer -ScriptBlock {
            $sa = New-Object -comObject Shell.Application
            $sa.Namespace(17).ParseName("$cd_drive").InvokeVerb("Eject")
        }
    }
}