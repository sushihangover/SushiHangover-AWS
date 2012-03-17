<#
.NOTES
Copyright 2012 Robert Nees
Licensed under the Apache License, Version 2.0 (the "License");
http://sushihangover.blogspot.com
.SYNOPSIS
Sign a HTML post form to allow direct uploading to a S3 bucket
.DESCRIPTION
Posting directly to a S3 bucket can save a lot of I/O on your EC2 instance that
would need to move it to an S3 after the upload is complete. That process just
does not scale well, but direct S3 posting via HTML, HTML5, or Ajax is the to 
ensure that your upload application scales in a linear fashion across AWS.

* Check out the following posts:

Browser Uploads to S3 using HTML POST Forms : http://aws.amazon.com/articles/1434?_encoding=UTF8
HTML & AJAX solutions to upload files to S3 : http://zefer.posterous.com/pure-html-ajax-solutions-to-upload-files-to-s
.EXAMPLE
[107] » Do-AWSSignS3PostingForm.ps1 -form .\UploadPolicyDocument | format-list

policy    : eyJleHBXXXXXXXXXXXXXXXXXXXXXXXY29uZGl0aW9ucyI6IFsgI
            CAgIXXXXXXXXXXXXXXXXXXXXXXXXXXXXgWyJzdGFydHMtd2l0aC
            IsICIka2V5IiwgXXXXXXXXXXXXXXXXXXXXXXXXAgICB7InN1Y2N
            lc3NfYWN0aW9XXXXXXXXXXXXXXXXXXXXXE3LmNvbXB1dGUtMS5h
            bWF6XXXXXXXXXXXXXXXXXXXWRzdWNjZXNzZnVsLmh0bWwifSwgI
            CAgIFsiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXZW
            5ndGgtcmFXXXXXXXXXXXXXXXXXXXXXXXXgfQ==
signature : QBfXXXXXXXXXXXXXXXXXXXXXXXXA=
.LINK
http://sushihangover.blogspot.com
http://aws.amazon.com/articles/1434?_encoding=UTF8
http://zefer.posterous.com/pure-html-ajax-solutions-to-upload-files-to-s
#>
[CmdletBinding()]
Param(
    [Parameter(parametersetname="Main",Mandatory=$true)][Alias('form')][string]$formFields,
    [Parameter(parametersetname="Main",Mandatory=$false)][Alias('secert')][string]$secertKey = '',
    [Parameter(parametersetname="Main",Mandatory=$false)][switch]$whatif,
    [Parameter(parametersetname="Setup",Mandatory=$true)][Alias('savekey')][string]$saveSecertKey
        )
Begin {
    switch ($PsCmdlet.ParameterSetName)
    {
        "Setup"  {
            $file = $MyInvocation.MyCommand.Name
            $google = New-Object PSOBject
            $google | add-member -membertype noteproperty -name secretkey -value $saveSecertKey
            $google | export-clixml -Path $HOME\aws_secretkey.xml
            exit
        }
        "Main"  {
            if ($secertKey -eq '') {
                if (!(Test-Path $HOME\aws_secretkey.xml)) {
                    write-host 'SecertKey not provide via parameter and Secret Key file missing' -ForegroundColor Red
                    help ($MyInvocation.MyCommand.Name) -examples
                    exit
                }
                $s3 = Import-Clixml $HOME\aws_secretkey.xml
            } else {
                $s3 = New-Object PSOBject
                $s3 | add-member -membertype noteproperty -name secretkey -value $secretKey
            }
            $awsS3 = New-Object PSOBject
            $awsS3 | add-member -membertype noteproperty -name policy -value ''
            $awsS3 | add-member -membertype noteproperty -name signature -value ''
        }
    }
}
Process {
    $utf8 = New-Object System.Text.utf8encoding
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA1

    $formContents = Get-Content -Encoding Ascii $formFields
    $awsS3.policy = [System.Convert]::ToBase64String(
        $utf8.Getbytes($formContents)
    )

    $hmacsha.key = $utf8.Getbytes($s3.secretkey)
    $awsS3.signature = [System.Convert]::Tobase64String(
        $hmacsha.ComputeHash(
            $utf8.GetBytes($awsS3.policy)
        )
    )
    return $awsS3
}
End {
    $google = $null
    $awsS3 = $null
}