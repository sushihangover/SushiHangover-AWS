Function Set-EC2Config {
    Param(
        [Parameter(Mandatory=$false)][string]$proxyID,
        [Parameter(Mandatory=$false)][string]$proxyPwd,
        [Parameter(Mandatory=$false)][string]$proxyHost,
        [Parameter(Mandatory=$false)][string]$proxyPort,
        [Parameter(Mandatory=$false)][switch]$http
    )
    $ec2Config = New-object Amazon.EC2.AmazonEC2Config
    if ($http.isPresent) {
        $ec2Config.CommunicationProtocol = "HTTP"
    }
    if ($proxyHost) {$ec2Config.ProxyHost = $proxyHost}
    if ($proxyPort) {$ec2Config.ProxyPort = $proxyPort}
    if ($proxyUserID) {$ec2Config.ProxyUserName = $proxyUserID}
    if ($proxyPwd) {$ec2Config.ProxyPassword = $proxyPwd}
    new-variable -scope global -name AWSEC2Config -force -value $ec2Config
    $AWSEC2Config = $ec2Config
    # return [Amazon.EC2.AmazonEC2Config]$AWSEC2Config
}
Function Get-EC2Config {
    if (!$AWSEC2Config) {
        . Set-EC2Config
    }
    return [Amazon.EC2.AmazonEC2Config]$AWSEC2Config
}
Function Get-EC2Client {
    Param(
        [Parameter(Mandatory=$false)][Alias('creds')][Amazon.Runtime.BasicAWSCredentials]$AWSBasicCredentials = (. Get-AWSBasicCredentials),
        [Parameter(Mandatory=$false)][Alias('config')][Amazon.EC2.AmazonEC2Config]$AWSEC2Config = (. Get-EC2Config)
    )
    if ($AWSEC2InstancesRequest) {
        $AWSEC2InstancesRequest.Dispose()
        $AWSEC2InstancesRequest = $null
    }
    new-variable -scope global -name AWSEC2Client -force -value ([Amazon.AWSClientFactory]::CreateAmazonEC2Client($AWSBasicCredentials.GetCredentials().AccessKey, $AWSBasicCredentials.GetCredentials().ClearSecretKey, $AWSEC2Config))
    return [Amazon.EC2.AmazonEC2Client]$AWSEC2Client
}
Function Set-EC2Request {
    Param (
        [Parameter(Mandatory=$true)][Alias('ami')][string]$ImageId,
        [Parameter(Mandatory=$false)][Alias('type')][string]$InstanceType = 't1.micro',
        [Parameter(Mandatory=$false)][Alias('key')][string]$KeyName,
        [Parameter(Mandatory=$false)][Alias('sg')][string]$SecurityGroup,
        [Parameter(Mandatory=$false)][Alias('count')][int]$StartCount = 0,
        [Parameter(Mandatory=$false)][Alias('min')][int]$MinCount = 1,
        [Parameter(Mandatory=$false)][Alias('max')][int]$MaxCount = 1,
        [Parameter(Mandatory=$false)][Alias('behavior')][string]$InstanceInitiatedShutdownBehavior,
        [Parameter(Mandatory=$false)][Alias('monitor')][bool]$Monitoring = $false,
        [Parameter(Mandatory=$false)][Alias('terminable')][bool]$DisableApiTermination = $false,
        [Parameter(Mandatory=$false)][Alias('ec2client')][Amazon.EC2.AmazonEC2Client]$AWSEC2Client = (. Get-EC2Client)
    )
    $Request = New-Object Amazon.EC2.Model.RunInstancesRequest
    $Request.ImageId = $ImageId
    $Request.InstanceType = $InstanceType
    if ($KeyName) { $Request.KeyName = $KeyName }
    if ($SecurityGroup) { $Request.SecurityGroup = $SecurityGroup }
    if ($StartCount -gt 0) {
        $Request.MinCount = $StartCount
        $Request.MaxCount = $StartCount
    } else {
        $Request.MinCount = $MinCount
        $Request.MaxCount = $MaxCount
    }
    if ($InstanceInitiatedShutdownBehavior) { $Request.InstanceInitiatedShutdownBehavior = $InstanceInitiatedShutdownBehavior }
    $Monitor = New-Object Amazon.EC2.Model.MonitoringSpecification
    $Request.Monitoring = $Monitor
    $Request.Monitoring.Enabled = $Monitoring
    $Request.DisableApiTermination = $DisableApiTermination
    new-variable -scope global -name AWSEc2InstancesRequest -force
    $AWSEc2InstancesRequest = $Request
    return $Request
}
Function Get-EC2Request {
    if (!$AWSEc2InstancesRequest) {
        . Set-EC2RequestGetPasswordDataResult
    }
    return $AWSEc2InstancesRequest
}
Function Get-EC2Password {
    Param (
        [Parameter(Mandatory=$true)][Alias('i')][Alias('id')][string]$InstanceId,
        [Parameter(Mandatory=$false)][Alias('client')][Alias('c')][Amazon.EC2.AmazonEC2Client]$EC2Client = (. Get-EC2Client)
    )
    . Do-RSADecrypt
    $PemFile = $HOME + '\.ssh\sushibob.pem'
    $RSA = Set-RSACryptoServiceProvider $PemFile
    
    $Request = New-Object Amazon.EC2.Model.GetPasswordDataRequest
    $Request.InstanceId = $InstanceId
    $Response = $EC2Client.GetPasswordData($Request)
    $cypherBase64 = $Response.GetPasswordDataResult.PasswordData.Data
    $cypherBytes  = [System.Convert]::FromBase64String($cypherBase64)

    $clearBytes = $RSA.Decrypt($cypherBytes, $false)
    $clearText = [System.Text.Encoding]::ASCII.GetString($clearBytes)
    return $clearText
}
Function Start-EC2 {
    Param (
        [Parameter(Mandatory=$false)][Alias('request')][Alias('r')][Amazon.EC2.Model.RunInstancesRequest]$EC2Request = (. Get-EC2Request),
        [Parameter(Mandatory=$false)][Alias('client')][Alias('c')][Amazon.EC2.AmazonEC2Client]$EC2Client = (. Get-EC2Client)
    )
    return $EC2Client.RunInstances($EC2Request)
}
Function Connect-EC2RDP($server, $user, $pass) {
    cmdkey /generic:TERMSRV/$server /user:$user /pass:$pass
    mstsc /v:$server
}
Function Connect-EC2PSRemote {
    Param (
        [Parameter(Mandatory=$true)][Alias('s')][string]$Server,
        [Parameter(Mandatory=$false)][Alias('usr')][string]$UserName,
        [Parameter(Mandatory=$false)][Alias('pwd')][string]$Password
    )
    $secure = ConvertTo-SecureString $Password -asplaintext -force
    $cred = New-Object System.Management.Automation.PSCredential $UserName,$secure
    Set-Variable -Name UserCredential -Value $cred -Scope global
    #$server = 'http://' + $server
    $server
    New-PSSession -ComputerName $server -credential $UserCredential -UseSSL
}
Function Get-EC2Instance {
    Param (
        [Parameter(Mandatory=$false)][Alias('i')][Alias('id')][string]$InstanceId,
        [Parameter(Mandatory=$false)][Alias('f')][array]$Filter,
        [Parameter(Mandatory=$false)][Alias('client')][Alias('c')][Amazon.EC2.AmazonEC2Client]$EC2Client = (. Get-EC2Client)
    )
    $Request = New-Object Amazon.EC2.Model.DescribeInstancesRequest
    if ($InstanceId) {
        $Request.InstanceId = @()
        $Request.InstanceId += $InstanceId
    }
    $Request.Filter = $Filter
    [Amazon.EC2.Model.DescribeInstancesResponse]$Response = $EC2Client.DescribeInstances($Request)
    #return $Response.DescribeInstancesResult.Reservation
    [array]$Instances = @()
    #$Instances += $Response.DescribeInstancesResult.Reservation | % { $_.RunningInstance }
    $Instances += $Response.DescribeInstancesResult.Reservation | % { $_.RunningInstance }
    write-host $Instances.count
    Return [array]$Instances
}
Function Get-EC2InstanceStatus {
    Param (
        [Parameter(Mandatory=$false)][Alias('i')][Alias('id')][string]$InstanceId,
        [Parameter(Mandatory=$false)][Alias('f')][array]$Filter,
        [Parameter(Mandatory=$false)][Alias('client')][Alias('c')][Amazon.EC2.AmazonEC2Client]$EC2Client = (. Get-EC2Client)
    )
    $Request = New-Object Amazon.EC2.Model.DescribeInstanceStatusRequest
    if ($InstanceId) {
        $Request.InstanceId = @()
        $Request.InstanceId += $InstanceId
    }
    $Request.Filter = $Filter
    return [Amazon.EC2.Model.DescribeInstanceStatusResponse]$EC2Client.DescribeInstanceStatus($Request)
}
Function Start-EC2Instance {
    Param (
        [Parameter(Mandatory=$true)][Alias('i')][Alias('id')][string]$InstanceId,
        [Parameter(Mandatory=$false)][Alias('client')][Alias('c')][Amazon.EC2.AmazonEC2Client]$EC2Client = (. Get-EC2Client)
    )
    $Request = New-Object Amazon.EC2.Model.StartInstancesRequest
    if ($InstanceId) {
        $Request.InstanceId = @()
        $Request.InstanceId += $InstanceId
    }
    return [Amazon.EC2.Model.StartInstancesResponse]$EC2Client.StartInstances($Request)    
}
