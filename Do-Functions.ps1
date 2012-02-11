## Copyright 2012 Robert Nees
## Licensed under the Apache License, Version 2.0 (the "License");
## http://sushihangover.blogspot.com
##
function isNumeric ($x) {
    $x2 = 0
    $isNum = [System.Int32]::TryParse($x, [ref]$x2)
    return $isNum
}

function Set-IPAddress {
    param(  [string]$networkinterface = $(read-host "Enter the name of the NIC (ie Local Area Connection)"),
            [string]$ip = $(read-host "Enter an IP Address (ie 10.10.10.10)"),
            [string]$mask = $(read-host "Enter the subnet mask (ie 255.255.255.0)"),
            [string]$gateway = $(read-host "Enter the current name of the NIC you want to rename"),
            [string]$dns1 = $(read-host "Enter the first DNS Server (ie 10.2.0.28)"),
            [string]$dns2,
            [string]$registerDns = "TRUE"
        )
    $dns = $dns1
    if($dns2){$dns ="$dns1,$dns2"}
    $index = (gwmi Win32_NetworkAdapter | where {$_.netconnectionid -eq $networkinterface}).InterfaceIndex
    $NetInterface = Get-WmiObject Win32_NetworkAdapterConfiguration | where {$_.InterfaceIndex -eq $index}
    $NetInterface.EnableStatic($ip, $subnetmask)
    $NetInterface.SetGateways($gateway)
    $NetInterface.SetDNSServerSearchOrder($dns)
    $NetInterface.SetDynamicDNSRegistration($registerDns)
}
