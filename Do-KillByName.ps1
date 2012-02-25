<#
.NOTES
Copyright 2012 Robert Nees
Licensed under the Apache License, Version 2.0 (the "License");
http://sushihangover.blogspot.com
.SYNOPSIS
Kill process by name
.DESCRIPTION
This scripts provides a way to kill processes by name verus by Id
.EXAMPLE
Do-KillByName.ps1 bonjour
.LINK
http://sushihangover.blogspot.com
#>
$pName = $args[0]
$killList = get-process | where {($_.Name -eq $pName)}
If ($killList -ne $null) {
    $killList
    $killList | foreach { $_.Kill() }
} Else {
    echo "No processes found"
}