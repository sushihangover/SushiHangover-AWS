<#
.NOTES
Copyright 2012 Robert Nees
Licensed under the Apache License, Version 2.0 (the "License");
http://sushihangover.blogspot.com
.SYNOPSIS
Upload video(s) to YouTube
.DESCRIPTION
This scripts provides a way to upload one or more videos to YouTube using 
the Powershell pipeline or standard named input parameters. Rejection and 
Upload Errors are logged to the Event Log for remote reporting.

I originally wrote this in python to be used with an automation project that used direct Amazon/AWS S3 bucket 
uploading and a REST event being published via Amazon Simple Notification Service (SNS) to know when to 
upload and archive new videos to YouTube, but also wanted a PowerShell based version for my Window deployments
but there was no PowerShell version available.
 
The pipeline output object is a Gdata/Youtube video object, if you used the -noWait switch parameter
than there is no guarantee that this object is for the final video as its 'State' could still be
'IsDraft', otherwise this script is synchronize and the video output object will be 'IsDraft = false' and
'might' have passed, failed or got rejected, check the 'Status' property to determine the final status 
of the video uploaded

.EXAMPLE
» Do-YouTubeUpload.ps1 -videoname 'C:\videos\SpaceNeedle1080p.wmv'  -title 'Space Needle' -description 'Space Needle Bending Over' -category 'Places' -keywords 'Seattle' -private $true
FYI: The Google SDK (GData API) is real fussy on the path, make it look like a DOS path, no funky Powershell stuff here...
.EXAMPLE
Do-YouTubeUpload.ps1 -key 'AI39s....hwzHhw' -id 'yourgoogleid@gmail.com' -pwd 'yourpassword'
Run the script once with your Developer's key, user name and password
and it will be saved in a CLIXML file named youtube_authorization.xml 
in the root of your $HOME directory
.LINK
http://sushihangover.blogspot.com
#>
[CmdletBinding()]
Param(
    [Parameter(parametersetname="Main",Mandatory=$true,ValueFromPipeline=$true)][Alias('n')][string]$videoName,
    [Parameter(parametersetname="Main",Mandatory=$true)][Alias('t')][string]$title,
    [Parameter(parametersetname="Main",Mandatory=$true)][Alias('d')][string]$description,
    [Parameter(parametersetname="Main",Mandatory=$true)][Alias('c')][string]$category,
    [Parameter(parametersetname="Main",Mandatory=$false)][Alias('k')][string]$keywords = '',
    [Parameter(parametersetname="Main",Mandatory=$false)][Alias('p')][boolean]$private = $false,
    [Parameter(parametersetname="Main",Mandatory=$false)][switch]$noWait,
    [Parameter(parametersetname="Main",Mandatory=$false)][switch]$whatif,
    [Parameter(parametersetname="Setup",Mandatory=$true)][Alias('key')][string]$devkey,
    [Parameter(parametersetname="Setup",Mandatory=$true)][Alias('id')][string]$user,
    [Parameter(parametersetname="Setup",Mandatory=$true)][Alias('pwd')][string]$password
    )
Begin {
    switch ($PsCmdlet.ParameterSetName)
    {
        "Setup"  {
            $google = New-Object PSOBject
            $google | add-member -membertype noteproperty -name key -value $devkey
            $google | add-member -membertype noteproperty -name id -value $user
            $google | add-member -membertype noteproperty -name pwd -value $password
            $google | export-clixml -Path $HOME\youtube_authorization.xml
            exit
        }
        "Main"  {
            if (!(Test-Path $HOME\youtube_authorization.xml)) {
                write-host 'Authorization file missing' -ForegroundColor Red
                help Do-YouTubeUpload.ps1 -examples
                exit
            }
            $google = Import-Clixml $HOME\youtube_authorization.xml

            add-type -path "C:\Program Files\Google\Google Data API SDK\Redist\Google.*.dll"
            add-type -path "C:\Program Files\Google\Google YouTube SDK for .NET\Redist\Google.*.dll"

            # test category to insure that it is valid 

            $settings = new-object Google.YouTube.YouTubeRequestSettings("SushiHangover.blogspot.com", $google.key, $google.id, $google.pwd);
            $settings.Timeout = 1000000

            $request = New-Object Google.YouTube.YouTubeRequest($settings);

            $youtubeService = New-Object Google.GData.YouTube.YouTubeService('UploadStatus', $google.key)
            $youtubeService.Credentials = New-object Google.GData.Client.GDataCredentials($google.id, $google.pwd)
        }
    }     
}
Process {
    $newVideo = New-Object Google.YouTube.Video
    $newVideo.Title = $title
    $newVideo.Description = $description
    $newVideo.KeyWords = $keywords
    $newVideo.Private = $private
    
    $yt_category = New-Object Google.GData.Extensions.MediaRss.MediaCategory($category)
    $yt_category.Attributes["scheme"] = [Google.GData.YouTube.YouTubeService]::DefaultCategory
    $tagArray = @()
    $tagArray = $newVideo.Tags.Add($yt_category);
    $newVideo.Keywords = $keywords
    $newVideo.MediaSource = new-object Google.GData.Client.MediaFileSource($videoName, "video/mp4")
    try {
        $uploadedVideo = $request.Upload($newVideo)
        if (!$noWait.IsPresent) {
            $status = $uploadedVideo
            while ($status.IsDraft) {
                if ($status.Status.Name -eq "processing") {
                    # Video is still processing at YouTube
                } elseif ($status.Status.Name -eq "rejected") {
                    # "Video has been rejected because:"
                    # $status.Status.Value
                    # $status.Status.Help
                    break
                } elseif ($status.Status.Name -eq 'failed') {
                    # "Video failed uploading because:"
                    # $status.Status.Value
                    # $status.Status.Help
                    break
                }
                Start-Sleep -s 5
                try {
                    $status = $request.Retrieve($uploadedVideo)
                } catch [Google.GData.Client.GDataNotModifiedException] {
                    $status = $uploadedVideo
                }
            }
        }

    } catch [System.IO.DirectoryNotFoundException] {
        write-host "Video file directory not found..." -ForegroundColor Red
        break
    } catch [System.IO.FileNotFoundException] {
        write-host "Video file not found..." -ForegroundColor Red
        break
    } catch [Google.GData.Client.GDataRequestException] { 
        $err = $_.Exception
        $err.ToString()
        break
    } finally {
        try {
            $status = $request.Retrieve($uploadedVideo)
        } catch [Google.GData.Client.GDataNotModifiedException] {
            $status = $uploadedVideo
        }
    }
    return $status
}
End {
    $youtubeService = $null
    $request = $null
    $settings = $null
}
