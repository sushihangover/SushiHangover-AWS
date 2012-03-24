<#
.NOTES
Copyright 2012 Robert Nees
Licensed under the Apache License, Version 2.0 (the "License");
http://sushihangover.blogspot.com
.SYNOPSIS
Amazon (AWS) PowerShell Interface
.DESCRIPTION
s3Upload : Pipelined Async Uploading to S3 Buckets; FileInfo and DirectoryInfo pipeline in, 
uses async uploading via the AWS auto-segmentation transfer routines
The default for the segmentation is 1MB, set $AWSS3MultiPartStartSize larger before uploading 
if you are connecting to AWS from are a wired LARGE reliable pipe
# Download from S3 Buckets

.EXAMPLE
.LINK
http://sushihangover.blogspot.com
#>
function genericScriptBlockCallback {
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$Callback
    )
    if (-not ("CallbackEventBridge" -as [type])) {
        Add-Type @"
            using System;
            public sealed class CallbackEventBridge
            {
                public event AsyncCallback CallbackComplete = delegate { };
                private CallbackEventBridge() {}
                private void CallbackInternal(IAsyncResult result)
                {
                    CallbackComplete(result);
                }
                public AsyncCallback Callback
                {
                    get { return new AsyncCallback(CallbackInternal); }
                }
                public static CallbackEventBridge Create()
                {
                    return new CallbackEventBridge();
                }
            }
"@
    }
    $bridge = [callbackeventbridge]::create()
    Register-ObjectEvent -input $bridge -EventName callbackcomplete -action $callback -messagedata $args > $null
    $bridge.callback
}
Function duplicateMembers {
    param($array, [switch]$count)
    begin {
        $hash = @{}
    }
    process {
        $array | %{ $hash[$_] = $hash[$_] + 1 }
        if($count) {
            $hash.GetEnumerator() | ?{$_.value -gt 1} | %{
                New-Object PSObject -Property @{
                    Value = $_.key
                    Count = $_.value
                }
            }
        }
        else {
            $hash.GetEnumerator() | ?{$_.value -gt 1} | %{$_.key}
        }
    }
}
Function Get-Enum([type]$type){
    [enum]::getNames($type) | select @{n="Name";e={$_}},@{n="Value";e={$type::$_.value__}}
}
Function Add-AWS {
    Add-Type -path "C:\Program Files\AWS SDK for .NET\bin\AWSSDK.dll"
    return $true # need to pass add type failures to caller
}
Function Set-AWSCredentials {
    Param(
        [Parameter(Mandatory=$true)][Alias('access')][string]$Access,
        [Parameter(Mandatory=$true)][Alias('secert')][string]$Secert,
        [Parameter(Mandatory=$false)][Alias('id')][string]$Id = '',
        [Parameter(Mandatory=$false)][Alias('name')][string]$Name = '',
        [Parameter(Mandatory=$false)][Alias('path')][string]$Location = ($HOME),
        [Parameter(Mandatory=$false)][Alias('file')][string]$Filename = 'amazon_account_info.xml'
        )
    $awsAccount = New-Object PSOBject
    $awsAccount | add-member -membertype noteproperty -name id -value $ID
    $awsAccount | add-member -membertype noteproperty -name name -value $NAME
    $awsAccount | add-member -membertype noteproperty -name access -value $ACCESS
    $awsAccount | add-member -membertype noteproperty -name secert -value $SECERT
    $awsAccount | export-clixml -Path ($Location + '\' + $Filename)
}
Function Get-AWSCredentials {
    Param(
        [Parameter(Mandatory=$false)][Alias('path')][string]$Location = $HOME,
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
        return New-Object Amazon.Runtime.BasicAWSCredentials($AWSCredentials.access, $AWSCredentials.secert, $false)
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
Function Set-AWSS3Config {
    Param(
        [Parameter(Mandatory=$false)][string]$proxyID,
        [Parameter(Mandatory=$false)][string]$proxyPwd,
        [Parameter(Mandatory=$false)][string]$proxyHost,
        [Parameter(Mandatory=$false)][string]$proxyPort,
        [Parameter(Mandatory=$false)][int]$maxErrorRetry,
        [Parameter(Mandatory=$false)][switch]$http
    )
    $s3Config = New-object Amazon.S3.AmazonS3Config
    if ($http.isPresent) {
        $s3Config.CommunicationProtocol = "HTTP"
    }
    if ($proxyHost) {$s3Config.ProxyHost = $proxyHost}
    if ($proxyPort) {$s3Config.ProxyPort = $proxyPort}
    if ($proxyUserID) {$s3Config.ProxyUserName = $proxyUserID}
    if ($proxyPwd) {$s3Config.ProxyPassword = $proxyPwd}
    if ($maxErrorRetry) {$s3Config.MaxErrorRetry = $maxErrorRetry}
    new-variable -scope global -name AWSS3Config -force
    $AWSS3Config = $s3Config
}
Function Get-AWSS3Config {
    if (!$AWSS3Config) {
        . Set-AWSS3Config
    }
    return $AWSS3Config
}
Function Set-AWSS3TransferConfig {
    Param(
        [Parameter(Mandatory=$false)][Alias('size')][int]$multiPartAt = $AWSS3MultiPartStartSize,
        [Parameter(Mandatory=$false)][int]$threads,
        [Parameter(Mandatory=$false)][int]$timeout
    )    
    $s3TransferConfig = New-Object Amazon.S3.Transfer.TransferUtilityConfig
    if ($multiPartAt) {$s3TransferConfig.MinSizeBeforePartUpload = $multiPartAt}
    if ($threads) {$s3TransferConfig.NumberOfUploadThreads = $threads}
    if ($timeout) {$s3TransferConfig.DefaultTimeout = $timeout}
    new-variable -scope global -name AWSS3TransferConfig -force
    $AWSS3TransferConfig = $s3TransferConfig
}
Function Get-AWSS3TransferConfig {
    if (!$AWSS3TransferConfig) {
        . Set-AWSS3TransferConfig
    }
    return $AWSS3TransferConfig
}
Function Get-AWSS3Client {
    Param(
        [Parameter(Mandatory=$false)][Alias('creds')][Amazon.Runtime.BasicAWSCredentials]$AWSBasicCredentials = (. Get-AWSBasicCredentials),
        [Parameter(Mandatory=$false)][Alias('config')][Amazon.S3.AmazonS3Config]$AWSS3Config = (. Get-AWSS3Config)
    )
    if ($AWSS3TransferConfig) {
        $AWSS3TransferConfig.Dispose()
        $AWSS3TransferConfig = $null
    }
    new-variable -scope global -name AWSS3Client -force -value ([Amazon.AWSClientFactory]::CreateAmazonS3Client($AWSBasicCredentials.GetCredentials().AccessKey, $AWSBasicCredentials.GetCredentials().ClearSecretKey, $AWSS3Config))
    return $AWSS3Client
}
Function Read-S3Buckets {
    Param(
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    new-variable -scope global -name AWSS3Buckets -force -value ($AWSS3Client.ListBuckets())
    return $AWSS3Buckets.Buckets
}
Function New-S3Bucket {
    Param(
        [Parameter(Mandatory=$true)][Alias('name')][string]$S3BucketName,
        [Parameter(Mandatory=$false)][Alias('region')][string]$S3RegionName,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    $s3BucketRequest = New-Object Amazon.S3.Model.PutBucketRequest
    if ($S3RegionName) {
        $s3BucketRequest.BucketRegion = [Amazon.S3.Model.S3Region]::($S3RegionName)
    } else {
        $s3BucketRequest.BucketRegion = (. Get-S3Region)
    }
    $s3BucketRequest.BucketName = $S3BucketName
    return $AWSS3Client.PutBucket($s3BucketRequest)

#AmazonS3Exception
#Exception calling "PutBucket" with "1" argument(s): "The requested bucket name is not
#available. The bucket namespace is shared by all users of the system. Please select a
#different name and try again."

#RequestId      : 398CXXXXX9A4E49A
#AmazonId2      : mfl0NAAVSdqvL6cAMOlRG2HfJXXXXXXXXXDzHhvHqmyhhxKn/PRgwtKreJDDA+
#ResponseStream :
#Headers        : {x-amz-id-2, x-amz-request-id, Content-Length, Date...}
#Metadata       : {}
#ResponseXml    :
}
Function Remove-s3Bucket {
    Param(
        [Parameter(Mandatory=$true)][Alias('name')][string]$S3BucketName,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    $s3BucketRequest = New-Object Amazon.S3.Model.DeleteBucketRequest 
    $s3BucketRequest.BucketName = $S3BucketName
    return $AWSS3Client.DeleteBucket($s3BucketRequest)
}
Function Get-S3BucketRegion {
    Param(
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client),
        [Parameter(Mandatory=$true)][Alias('name')][string]$S3BucketName
    )
    $s3BucketRequest = New-Object Amazon.S3.Model.GetBucketLocationRequest
    $s3BucketRequest.BucketName = $S3BucketName
    $s3BucketRequest = $AWSS3Client.GetBucketLocation($s3BucketRequest)
    $foo = New-Object Amazon.S3.Model.S3Region
    $foo.value__ = [Amazon.S3.Model.S3Region]::($s3BucketRequest.Location)
    return $foo
}
Function Show-S3Region {
    Get-Enum([Amazon.S3.Model.S3Region]) | Format-Table -auto
}
Function Set-S3Region {
    Param(
        [Parameter(Mandatory=$false)][Alias('Region')][string]$s3Region
    )
    $foo = New-Object Amazon.S3.Model.S3Region
    $foo.value__ = [Amazon.S3.Model.S3Region]::$s3Region
    new-variable -scope global -name AWSS3Region -force -value $foo
    return $AWSS3Region
}
Function Get-S3Region {
    if (!$AWSS3Region) {
        (. Set-S3Region)
    }
    return $AWSS3Region
}
Function Exist-S3Bucket {
    Param(
        [Parameter(Mandatory=$true)][Alias('name')][string]$S3BucketName,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    return (Read-S3Buckets | % { $_.BucketName } ).Contains($S3BucketName)
}
Function Get-S3Bucket {
    Param(
        [Parameter(Mandatory=$true)][Alias('name')][string]$S3BucketName,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client),
        [Parameter(Mandatory=$false)][Alias('max')][string]$MaximunKeys = 25,
        [Parameter(Mandatory=$false)][Alias('p')][string]$KeyPrefix,
        [Parameter(Mandatory=$false)][Alias('c')][int]$Count = [int]::MaxValue,
        [Parameter(Mandatory=$false)][Alias('r')][Amazon.S3.Model.ListObjectsRequest]$Request
    )
    Begin {
        if (!(Exist-S3Bucket $S3BucketName)) {
            write-host 'Bucket' $S3BucketName 'does NOT exist' -ForegroundColor Red
            break
        }
        $c = 0
        if (!$Request) {
            $listRequest = New-Object Amazon.S3.Model.ListObjectsRequest
            $listRequest.BucketName = $S3BucketName
            $listRequest.MaxKeys = $MaximunKeys
            $listRequest.Prefix = $Prefix
        } else {
            $listRequest = $Request
        }
    }
    Process {
        do {
            [Amazon.S3.Model.ListObjectsResponse]$response = $AWSS3Client.ListObjects($listRequest)
            if ($response.IsTruncated) {
                write-host "Truncated response..." -ForegroundColor Red
                $listRequest.Marker = $response.NextMarker;
            } else {
                $listRequest = $null
            }
            if ($response.S3Objects.Count -gt 0) {
                $response.S3Objects | ForEach-Object {
                    [Amazon.S3.Model.S3Object]$_
                    $c++
                    if ($c -gt $Count) { break }
                }
            }
        } while ($listRequest)
    }
    End{
        # return $response
    }
}
Function Copy-S3Object {
    Param (
        [Parameter(Mandatory=$true)][Alias('r')][Amazon.S3.Model.CopyObjectRequest]$CopyRequest,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    return [Amazon.S3.Model.CopyObjectResponse]$AWSS3Client.CopyObject($CopyRequest)
}
Function Remove-S3Object {
    Param (
        [Parameter(Mandatory=$true)][Alias('r')][Amazon.S3.Model.DeleteObjectRequest]$DeleteRequest,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    return [Amazon.S3.Model.DeleteObjectResponse]$AWSS3Client.DeleteObject($DeleteRequest)
}
Function Remove-S3Objects {
    Param (
        [Parameter(Mandatory=$true)][Alias('r')][Amazon.S3.Model.DeleteObjectsRequest]$DeleteRequest,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    return [Amazon.S3.Model.DeleteObjectsResponse]$AWSS3Client.DeleteObjects($DeleteRequest)
}
Function Create-S3DeleteRequest {
    Param (
        [Parameter(Mandatory=$true)][Alias('o')][Amazon.S3.Model.S3Object]$DeleteObject,
        [Parameter(Mandatory=$false)][Alias('r')][Amazon.S3.Model.DeleteObjectsRequest]$DeleteRequest,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    if ($DeleteRequest) {
        $DeleteRequest.AddKey($DeleteObject.Key)
    } else {
        $DeleteRequest = New-Object Amazon.S3.Model.DeleteObjectRequest
        $request.BucketName = $S3BucketName
        $request.Key = $Key
    }
    return $DeleteRequest
}
Function Remove-S3Key {
    Param (
        [Parameter(Mandatory=$true)][Alias('b')][string]$S3BucketName,
        [Parameter(Mandatory=$true)][Alias('k')][string]$Key,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    $request = New-Object Amazon.S3.Model.DeleteObjectRequest
    $request.BucketName = $S3BucketName
    $request.Key = $Key
    return Remove-S3Object($request)
}
Function Clear-S3Bucket {
    Param(
        [Parameter(Mandatory=$true)][Alias('b')][string]$S3BucketName,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client),
        [Parameter(Mandatory=$false)][switch]$WhatIf
    )
    if (!(Exist-S3Bucket $S3BucketName)) {
        Write-host 'Bucket (' $S3BucketName ') does NOT exist' -ForegroundColor Red
        break
    }
    $request = New-Object Amazon.S3.Model.DeleteObjectsRequest
    Get-S3Bucket $S3BucketName | Foreach-Object {
        $request = Create-S3DeleteRequest -o $_ -r $request -s3client $AWSS3Client
    }
    $request.BucketName = $S3BucketName # ensure that nothing in delete request changed the bucket(?)
    if ($request.Keys.Count -gt 0) {
        if ($WhatIf.IsPresent) {
            $request.Keys | ForEach-Object { $_ } | ft -auto
        } else {
            Remove-S3Objects -r $request -s3client $AWSS3Client
        }
    }
}
Function Copy-S3Bucket {
    Param(
        [Parameter(Mandatory=$true)][Alias('from')][string]$FromS3BucketName,
        [Parameter(Mandatory=$true)][Alias('to')][string]$ToS3BucketName,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    if ((!(Exist-S3Bucket $FromS3BucketName)) -or (!(Exist-S3Bucket $ToS3BucketName)))  {
        Write-host 'Bucket does NOT exist' -ForegroundColor Red
        break
    }
    $S3CopyResponse = @()
    Get-S3Bucket $FromS3BucketName | % {
        $request = New-object Amazon.S3.Model.CopyObjectRequest
        $request.SourceBucket = $_.BucketName
        $request.SourceKey = $_.Key
        $request.DestinationBucket = $ToS3BucketName
        $request.DestinationKey = $_.Key
        $S3CopyResponse += Copy-S3Object $request
    }
    return $S3CopyResponse
}
Function Rename-Bucket {
    Param(
        [Parameter(Mandatory=$true)][Alias('Path')][string]$OriginalS3BucketName,
        [Parameter(Mandatory=$true)][Alias('NewName')][string]$NewS3BucketName,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    try {
        if (!(Exist-S3Bucket $OriginalS3BucketName)) {
            Write-host 'Origina bucket name' $OriginalS3BucketName 'does NOT exist' -ForegroundColor Red
            break
        }
        if (Exist-S3Bucket $NewS3BucketName) {
            Write-host 'New bucket name' $NewS3BucketName 'already exists' -ForegroundColor Red
            break
        }
        $newBucketResponse = New-Bucket -name $NewS3BucketName
        Get-S3Bucket $OriginalS3BucketName | % {
            $request = New-object Amazon.S3.Model.CopyObjectRequest
            $request.SourceBucket = $_.BucketName
            $request.SourceKey = $_.Key
            $request.DestinationBucket = $NewS3BucketName
            $request.DestinationKey = $_.Key
            Copy-S3Object $request
        }
        $deletebucket = Remove-Bucket -name $OriginalS3BucketName
    } catch [Amazon.S3.AmazonS3Exception] {
        [Amazon.S3.AmazonS3Exception]$error[0].Message
        break
    } catch {
        $error[0]
    }

#catch (AmazonS3Exception amazonS3Exception)
#            {
#                if (amazonS3Exception.ErrorCode != null &&
#                    (amazonS3Exception.ErrorCode.Equals("InvalidAccessKeyId")
#                    ||
#                    amazonS3Exception.ErrorCode.Equals("InvalidSecurity")))
#                {
#                    Console.WriteLine("Check the provided AWS Credentials.");
#                    Console.WriteLine(
#                    "To sign up for service, go to http://aws.amazon.com/s3");
#                }
#                else
#                {
#                    Console.WriteLine(
#                     "Error occurred. Message:'{0}' when listing objects",
#                     amazonS3Exception.Message);
#                }
#            }
}
Function s3UploadCallBack {
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [Object]$uploadQ
        )
    $awsUploadQueue
}
Function s3UploadProgress {
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [Object]$uploadQ
        )
    Begin {
    }
    Process {
        $uploadQ | fl -auto
    }
    End {
    }
}
Function Test-AWSS3 {
    $ok = $true
    try {
        $ipaddress = [System.Net.Dns]::GetHostAddresses("s3.amazon.com")
        # can not ping/icmp s3.amazon.com
        # $ping = test-connection -Authentication None -computer s3.amazon.com -count 1
    } catch {
        write-host "Host IP address lookup failed"
        $ipaddress = $null
        $ok = $false
    } finally {
        if ($ok) {
            try {
                 $buckets = Read-Buckets               
            } catch {
                $buckets = $null
                $ok = $false
            }
        }
    }
    return $ok
}
Function Copy-S3 {
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [Object]$PSPath,
        [Parameter(Mandatory=$false)][Amazon.S3.AmazonS3Client]$s3Client = (. Get-AWSS3Client),
        [Parameter(Mandatory=$false)][Amazon.S3.Transfer.TransferUtilityConfig]$transConfig = (. Get-AWSS3TransferConfig),
        [Parameter(Mandatory=$true)][Alias('b')][string]$bucket,
        [Parameter(Mandatory=$false)][Alias('r')][switch]$recurse,
        [Parameter(Mandatory=$false)][Alias('flat')][switch]$flatnaming,
        [Parameter(Mandatory=$false)][switch]$whatif
    )
    Begin {
        $flat = $flatnaming.IsPresent
        if ($whatif.IsPresent) {
            $whatIfList = @()
        } else {
            $s3Transfer = New-Object Amazon.S3.Transfer.TransferUtility($s3Client, $transConfig)
        }
    }
    Process {
        if ($_.PSIsContainer) {
            if (!$recurse.IsPresent) {
                return
            }
            if ($whatif.IsPresent) {
                write-host "Recursing into : " $_ -ForegroundColor Red
                ls $_.PSPath | awsS3Transfer -bucket $bucket -whatif
            } else {
                ls $_.PSPath | awsS3Transfer -bucket $bucket
            }
        } else {
            if ($flat) {
                $fooName = $_.Name
            } else {
                $fooName = ($_.fullname.replace($pwd.tostring() + "\","")).replace("\","/")
            }
            if ($whatif.IsPresent) {
                $whatIfItem = New-Object PSOBject
                $whatIfItem | add-member -membertype noteproperty -name bucket -value $bucket
                $whatIfItem | add-member -membertype noteproperty -name key -value $fooName
                $whatIfItem | add-member -membertype noteproperty -name local -value $_.FullName
                $whatIfList += $whatIfItem
            } else {
                $stateItem = New-Object PSOBject
                $stateItem | add-member -membertype noteproperty -name key -value $fooName
                $AWSS3UploadQueue += $s3Transfer.BeginUpload($_.FullName, $bucket, $fooName, (genericScriptBlockCallback { . s3UploadCallBack $awsUploadQueue }), $stateItem)
            }
        }
    }
    End {
        $s3Transfer.Dispose | Out-Null
        $s3Transfer = $null
        if ($whatif.IsPresent) {
            if (($flat) -and ($whatIfList.Count)) {
                $tmp = @(); $whatIfList | % { $tmp += $_.key };
                $tmp2 = duplicateMembers $tmp
                if ($tmp2) {
                    write-host "Caution: Duplicate 'flat' filenames!" $tmp2 -ForegroundColor Red
                }
            }
            return $whatIfList
        } else {
            return $AWSS3UploadQueue
        }
    }
}
ADD-aws | Out-Null
new-variable -scope global -name AWSS3UploadQueue -value @() -force
new-variable -scope global -name AWSS3MultiPartStartSize -value 1MB -force
