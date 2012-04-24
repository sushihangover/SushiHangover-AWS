<#
    .NOTES
    Copyright 2012 Robert Nees
    Licensed under the Apache License, Version 2.0 (the "License");
    http://sushihangover.blogspot.com
    .SYNOPSIS
    Amazon (AWS) PowerShell Interface
    .DESCRIPTION
    .EXAMPLE
    .LINK
    http://sushihangover.blogspot.com
#>
$AWS_configDir=$HOME

Function Add-AWSSDK {
#    Add-Type -AssemblyName ('AWSSDK, Version=1.4.8.1, Culture=neutral, PublicKeyToken=cd2d24cd2bace800')
    $x86Path = "C:\Program Files (x86)\AWS SDK for .NET\bin\AWSSDK.dll"
    $x64Path = "C:\Program Files\AWS SDK for .NET\bin\AWSSDK.dll"
    if (Test-Path $x86Path){
        Add-Type -Path $x86Path
        }
    elseif (Test-Path $x64Path) {
        Add-Type -Path $x64Path
        }
    else {
        write-host "ERROR: This script requires the AWS SDK for .NET`n`n" -back black -fore red
        exit
        }
    return $true # need to pass add type failures to caller
}
Function Set-AWSCredentials {
    Param(
        [Parameter(Mandatory=$true)][Alias('akey')][string]$AccessKey,
        [Parameter(Mandatory=$true)][Alias('skey')][string]$SecretKey,
        [Parameter(Mandatory=$false)][Alias('id')][string]$AWSId = '',
        [Parameter(Mandatory=$false)][Alias('name')][string]$UserName = '',
        [Parameter(Mandatory=$false)][Alias('path')][string]$Location = ($AWS_configDir),
        [Parameter(Mandatory=$false)][Alias('file')][string]$Filename = 'amazon_account_info.xml'
        )
    $awsAccount = New-Object PSOBject
    $awsAccount | add-member -membertype noteproperty -name id -value $AWSId
    $awsAccount | add-member -membertype noteproperty -name name -value $UserName
    $awsAccount | add-member -membertype noteproperty -name access -value $AccessKey
    $awsAccount | add-member -membertype noteproperty -name secret -value $SecretKey
    $awsAccount | export-clixml -Path ($Location + '\' + $Filename)
}
Function Get-AWSCredentials {
    Param(
        [Parameter(Mandatory=$false)][Alias('path')][string]$Location = $AWS_configDir,
        [Parameter(Mandatory=$false)][Alias('file')][string]$Filename = 'amazon_account_info.xml'
        )
    if (!(Test-Path ($Location + '\' + $Filename))) {
        write-host 'AWS Account Information file missing, run Set-AWSCredentials' -ForegroundColor Red
        help Set-AWSCred -examples
        break
    }
    return Import-Clixml -Path ($Location + '\' + $Filename)
}
Function Get-AWSBasicCredentials {
    Param(
        [Parameter(Mandatory=$false)][Alias('creds')][Object]$AWSCredentials = (Get-AWSCredentials)
        )
    if ($AWSCredentials) {
        return New-Object Amazon.Runtime.BasicAWSCredentials($AWSCredentials.access, $AWSCredentials.secret, $false)
    }
}
Function Test-AWSCredentials {
    Param(
        [Parameter(Mandatory=$false)][Alias('creds')][Object]$BasicAWSCredentials = (Get-AWSBasicCredentials)
        )
    if ($AWSBasicCredentials) {
        # Try S3
        Connect-AWSS3
    }
}
Function Do-QuickList {
    $args
}
New-Alias -Name QL -Value Do-QuickList

. Add-AWSSDK | Out-Null
