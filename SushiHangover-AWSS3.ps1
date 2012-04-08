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
if you are connecting to AWS from a wired wide and reliable pipe
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
Function Set-S3TransferConfig {
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
        . Set-S3TransferConfig
    }
    return $AWSS3TransferConfig
}
Function Get-AWSS3Client {
    Param(
        [Parameter(Mandatory=$false)][Alias('creds')][Amazon.Runtime.BasicAWSCredentials]$AWSBasicCredentials = (. Get-AWSBasicCredentials),
        [Parameter(Mandatory=$false)][Alias('config')][Amazon.S3.AmazonS3Config]$AWSS3Config = (. Get-AWSS3Config)
    )
    # If a s3 client request comes in and an existing global transfer config exists, clean it up....
#    if ($AWSS3TransferConfig) {
#        $AWSS3TransferConfig.Dispose()
#        $AWSS3TransferConfig = $null
#    }
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
Function Show-S3Buckets {
    Param(
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    return Read-S3Buckets $AWSS3Client
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
}
Function Remove-S3Bucket {
    Param(
        [Parameter(Mandatory=$true)][Alias('b')][Alias('Bucket')][string]$BucketName,
        [Parameter(Mandatory=$false)][switch]$Force,
        [Parameter(Mandatory=$false)][switch]$WhatIf,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    $Result = $Null
    if (!(Exist-S3Bucket $BucketName -s3client $AWSS3Client)) {
        $message = 'Bucket (' + $BucketName + ') does not exist'
        Write-Debug $message
    } else {
        if (Get-S3Bucket $BucketName -s3client $AWSS3Client) {
            if ($Force.IsPresent) {
                if (!$WhatIf.IsPresent) {
                    Clear-S3Bucket -BucketName $BucketName -s3client $AWSS3Client
                } else {
                    Write-Host 'Using "-Force"; Bucket''s contents will be deleted' -ForegroundColor Red -BackgroundColor Black
                }
            } else {
                if ($WhatIf.IsPresent) {
                    Write-Host 'Delete will fail, bucket is not empty' -ForegroundColor Red -BackgroundColor Black
                    Break
                } else {
                    Write-Debug 'Delete would fail, bucket is not empty'
                }
            }
        }
        $s3BucketRequest = New-Object Amazon.S3.Model.DeleteBucketRequest 
        $s3BucketRequest.BucketName = $BucketName
        if (!$WhatIf.IsPresent) {
            Write-Debug "Issuing AWSS3Client.DeleteBucket"
            $Result = $AWSS3Client.DeleteBucket($s3BucketRequest)
        } else {
            Write-Host 'Bucket (' $BucketName ') would be deleted' -ForegroundColor Red -BackgroundColor Black
        }
    }
    Return $Result 
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
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][Alias('BucketName')][Alias('Name')][string]$PSPath,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client),
        [Parameter(Mandatory=$false)][Alias('max')][string]$MaximunKeys = 25,
        [Parameter(Mandatory=$false)][Alias('p')][string]$KeyPrefix,
        [Parameter(Mandatory=$false)][Alias('c')][int]$Count = [int]::MaxValue,
        [Parameter(Mandatory=$false)][Alias('r')][Amazon.S3.Model.ListObjectsRequest]$Request
    )
    Begin {
    }
    Process {
        if (!(Exist-S3Bucket $PSPath)) {
            write-host 'Bucket' $PSPath 'does NOT exist' -ForegroundColor Red
            break
        }
        $c = 0
        if (!$Request) {
            $Request = New-Object Amazon.S3.Model.ListObjectsRequest
            $Request.BucketName = $PSPath
            $Request.MaxKeys = $MaximunKeys
            $Request.Prefix = $Prefix
        }
        do {
            [Amazon.S3.Model.ListObjectsResponse]$response = $AWSS3Client.ListObjects($Request)
            if ($Response.IsTruncated) {
                Write-Debug "Truncated response..."
                $Request.Marker = $Response.NextMarker;
            } else {
                $Request = $null
            }
            if ($Response.S3Objects.Count -gt 0) {
                $Response.S3Objects | ForEach-Object {
                    [Amazon.S3.Model.S3Object]$_
                    $c++
                    if ($c -gt $Count) { break }
                }
            }
        } while ($Request)
    }
    End {
        $Request = $null
        $Response = $null
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
        [Parameter(Mandatory=$true)][Alias('b')][Alias('bucket')][string]$BucketName,
        [Parameter(Mandatory=$true)][Alias('k')][string]$Key,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    $request = New-Object Amazon.S3.Model.DeleteObjectRequest
    $request.BucketName = $BucketName
    $request.Key = $Key
    return Remove-S3Object -r $request -s3client $AWSS3Client
}
New-Alias Remove-S3File Remove-S3Key -Force

Function Clear-S3Bucket {
    Param(
        [Parameter(Mandatory=$true)][Alias('b')][string]$BucketName,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client),
        [Parameter(Mandatory=$false)][switch]$WhatIf
    )
    if (!(Exist-S3Bucket $BucketName)) {
        Write-host 'Bucket (' $BucketName ') does NOT exist' -ForegroundColor Red
        break
    }
    $request = New-Object Amazon.S3.Model.DeleteObjectsRequest
    Get-S3Bucket $BucketName | Foreach-Object {
        $request = Create-S3DeleteRequest -o $_ -r $request -s3client $AWSS3Client
    }
    $request.BucketName = $BucketName # ensure that nothing in delete request changed the bucket(?)
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
    Get-S3Bucket -BucketName $FromS3BucketName -s3client $AWSS3Client  | % {
        $request = New-object Amazon.S3.Model.CopyObjectRequest
        $request.SourceBucket = $_.BucketName
        $request.SourceKey = $_.Key
        $request.DestinationBucket = $ToS3BucketName
        $request.DestinationKey = $_.Key
        $S3CopyResponse += Copy-S3Object $request -s3client $AWSS3Client
    }
    return $S3CopyResponse
}
Function Rename-S3Bucket {
    Param(
        [Parameter(Mandatory=$true)][Alias('Path')][string]$OriginalS3BucketName,
        [Parameter(Mandatory=$true)][Alias('NewName')][string]$NewS3BucketName,
        [Parameter(Mandatory=$false)][Alias('s3client')][Amazon.S3.AmazonS3Client]$AWSS3Client = (. Get-AWSS3Client)
    )
    try {
        if (!(Exist-S3Bucket -BucketName $OriginalS3BucketName -s3client $AWSS3Client)) {
            Write-host 'Original bucket name' $OriginalS3BucketName 'does NOT exist' -ForegroundColor Red -BackgroundColor Black
            break
        }
        if (Exist-S3Bucket -BucketName $NewS3BucketName -s3client $AWSS3Client) {
            Write-host 'New bucket name' $NewS3BucketName 'already exists' -ForegroundColor Red -BackgroundColor Black
            break
        }
        $newBucketResponse = New-S3Bucket -BucketName $NewS3BucketName -s3client $AWSS3Client
        New-S3Bucket -BucketName $NewS3BucketName -s3client $AWSS3Client
        if (Exist-S3Bucket -BucketName $NewS3BucketName -s3client $AWSS3Client) {
            Get-S3Bucket $OriginalS3BucketName -s3client $AWSS3Client | % {
                $request = New-object Amazon.S3.Model.CopyObjectRequest
                $request.SourceBucket = $_.BucketName
                $request.SourceKey = $_.Key
                $request.DestinationBucket = $NewS3BucketName
                $request.DestinationKey = $_.Key
                Copy-S3Object $request
            }
            $deletebucket = Remove-S3Bucket -BucketName $OriginalS3BucketName -s3client $AWSS3Client
        } else {
            $newBucketResponse
        }
    } catch [Amazon.S3.AmazonS3Exception] {
        $error[0]
        Write-Verbose $error[0].Exception
    } catch {
        $error[0]
    }
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
Function Test-S3 {
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
Function Publish-S3 {
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [Object]$PSPath,
        [Parameter(Mandatory=$false)][Amazon.S3.AmazonS3Client]$S3Client = (. Get-AWSS3Client),
        [Parameter(Mandatory=$false)][Amazon.S3.Transfer.TransferUtilityConfig]$TransConfig = (. Get-AWSS3TransferConfig),
        [Parameter(Mandatory=$true)][Alias('b')][Alias('Bucket')][string]$BucketName,
        [Parameter(Mandatory=$false)][Alias('r')][switch]$Recurse,
        [Parameter(Mandatory=$false)][Alias('flat')][switch]$Flatnaming,
        [Parameter(Mandatory=$false)][switch]$Whatif,
        [Parameter(Mandatory=$false)][switch]$Force,
        [Parameter(Mandatory=$false)][switch]$Recursion
    )
    Begin {
        $flat = $flatnaming.IsPresent
        if (!$recursion.IsPresent) {
            if ($whatif.IsPresent) {
                $whatIfList = @()
            } else {
                if ($AWSS2TransferUtility -eq $null) {
                    $s3Transfer = New-Object Amazon.S3.Transfer.TransferUtility($s3Client, $transConfig)
                    new-variable -scope global -name AWSS2TransferUtility -force -value $s3Transfer
                }    
            }
            if (!(Exist-S3Bucket $BucketName)) {
                if ($whatif.IsPresent) {
                    Write-host 'Bucket name' $BucketName 'does not exist' -ForegroundColor Red -BackgroundColor Black
                }
                if (!$whatif.IsPresent) {
                    if ($force.IsPresent) {
                        Write-Debug "Creating S3 Bucket"
                        New-S3Bucket $BucketName
                    } else {
                        break
                    }
                } elseif ( $whatif.IsPresent -and $force.IsPresent ) {
                    Write-host 'Bucket name' $BucketName 'will be created' -ForegroundColor Green -BackgroundColor Black
                }
            }
        }
    }
    Process {
        if ($_.PSIsContainer) {
            if (!$recurse.IsPresent) {
                return
            }
            if ($whatif.IsPresent) {
                $tmp = "Recursing into : " + $_ 
                Write-Debug -Message $tmp
                ls $_.PSPath | Publish-S3 -bucket $BucketName -s3Client $s3Client -recursion -whatif
            } else {
                ls $_.PSPath | Publish-S3 -bucket $BucketName -s3Client $s3Client -recursion
            }
        } else {
            if ($flat) {
                $fooName = $_.Name
            } else {
                $fooName = ($_.fullname.replace($pwd.tostring() + "\","")).replace("\","/")
            }
            if ($whatif.IsPresent) {
                $whatIfItem = New-Object PSOBject
                $whatIfItem | add-member -membertype noteproperty -name bucket -value $BucketName
                $whatIfItem | add-member -membertype noteproperty -name key -value $fooName
                $whatIfItem | add-member -membertype noteproperty -name local -value $_.FullName
                $whatIfList += $whatIfItem
            } else {
                $stateItem = New-Object PSOBject
                $stateItem | add-member -membertype noteproperty -name key -value $fooName
                $AWSS3UploadQueue += $AWSS2TransferUtility.BeginUpload($_.FullName, $BucketName, $fooName, (genericScriptBlockCallback { . s3UploadCallBack $awsUploadQueue }), $stateItem)
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
            new-variable -scope global -name AWSS3UploadQueue -value $AWSS3UploadQueue -force
            return $AWSS3UploadQueue
        }
    }
}
. Add-AWSSDK | Out-Null
new-variable -scope global -name AWSS3UploadQueue -value @() -force
new-variable -scope global -name AWSS3MultiPartStartSize -value 1MB -force
