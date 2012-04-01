<#
.NOTES
    Copyright 2012 Robert Nees
    Licensed under the Apache License, Version 2.0 (the "License");
    http://sushihangover.blogspot.com
.SYNOPSIS
    RSA Private Key encrypt and decrypt functions
.DESCRIPTION
    This is a collection of functions that provide a wrapper to 'opensslkey.cs'
.EXAMPLE
    . Do-RSACrypto
    $PemFile = $HOME + '\.ssh\sushibob.pem'
    . Set-RSACryptoServiceProvider $PemFile
    $preClearText = "Hello, Lets keep this a secret"
    $clearBytes =  Do-StringToByte $clearText
    $clearBase64 = Do-ToBase64 $clearBytes
    $cypherBytes = Do-RSAEncrypt $clearBase64 $false
    $cypherBase64  = Do-ToBase64 $cypherBytes
    $cypherBase64
    $clearBytes = Do-RSADecrypt $cypherBase64 $false
    $postclearText =  Do-ByteToString $clearBytes
    Compare-Object $preclearText $postclearText -CaseSensitive -IncludeEqual
.LINK
    http://sushihangover.blogspot.com
    http://ruudvanderlinden.com/2010/10/19/running-inline-c-with-custom-assemblies-in-powershell-2-0/
    http://blogs.technet.com/b/stefan_gossner/archive/2010/05/07/using-csharp-c-code-in-powershell-scripts.aspx
    http://msdn.microsoft.com/en-us/library/system.security.cryptography.rsacryptoserviceprovider.aspx
#>
$CSFile = (Get-Item ($profile)).Directory.FullName + ‘\opensslkey.cs’
$SourceCode = [System.IO.File]::ReadAllText($CSFile)

# 'System.IO','System.Text','System.Runtime.InteropServices','System.Security.Cryptography','System.Security.Cryptography.X509Certificates','System.Diagnostics'
$Assemblies = ('System','System.Security')

try {
    Add-Type -TypeDefinition $SourceCode -ReferencedAssemblies $Assemblies -IgnoreWarnings -Language CSharp 
} catch {
    Write-Warning "An error occurred attempting to add the .NET Framework class to the PowerShell session."
    Write-Warning "The error was: $($Error[0].Exception.Message)"
}
Function Do-ToBase64 {
    Param (
        [Parameter(Mandatory=$true)][Alias('pem')][array]$ByteString
    )
    return [System.Convert]::ToBase64String($ByteString)
}
Function Do-FromBase64 {
    Param (
        [Parameter(Mandatory=$true)][Alias('pem')][string]$ByteString
    )
    return [System.Convert]::FromBase64String($ByteString)
}
Function Do-ByteToString {
    Param (
        [Parameter(Mandatory=$true)][Alias('byte')][byte[]]$AsciiByteArray
    )
    return [System.Text.Encoding]::ASCII.GetString($AsciiByteArray)
}
Function Do-StringToByte {
    Param (
        [Parameter(Mandatory=$true)][Alias('byte')][string]$AsciiByteString
    )
    return [System.Text.Encoding]::ASCII.GetBytes($AsciiByteString)
}
Function Set-RSACryptoServiceProvider {
    Param (
        [Parameter(Mandatory=$true)][Alias('pem')][Alias('p')][string]$PemPrivateKeyFile
    )
    if (Test-Path -Path $PemPrivateKeyFile) {
        Write-Debug "Pem file exists"
        $PemText = [System.IO.File]::ReadAllText($PemPrivateKeyFile)
        Write-Debug $PemText
        $PemPrivateKey = [javascience.opensslkey]::DecodeOpenSSLPrivateKey($PemText)
        [System.Security.Cryptography.RSACryptoServiceProvider]$RSA = [javascience.opensslkey]::DecodeRSAPrivateKey($PemPrivateKey);
        Write-Debug $RSA
    } else {
        Write-Debug "PEM File does not exist"
        $RSA = $null
    }
    new-variable -scope global -name RSACryptoServiceProvider -force 
    $RSACryptoServiceProvider = $RSA
}
Function Get-RSACryptoServiceProvider {
    if (!$RSACryptoServiceProvider) {
        . Set-RSACryptoServiceProvider
    }
    return $RSACryptoServiceProvider
}
Function Do-RSADecrypt {
    <#
    .SYNOPSIS
        RSA Decryption with optional OAEP padding
    .Parameter OAEPPadding
        True to perform direct RSA decryption using OAEP padding (only available on a computer
        running Microsoft Windows XP or later); otherwise, false to use PKCS#1 v1.5 padding.
    .Parameter out
        Returns Decrypted Base64 String
    #>

    Param (
        [Parameter(Mandatory=$true)][Alias('cypher')][string]$CypherBase64,
        [Parameter(Mandatory=$true)][Alias('oaep')][boolean]$OAEPPadding = $false,
        [Parameter(Mandatory=$false)][Alias('RSA')][System.Security.Cryptography.RSACryptoServiceProvider]$RSACryptoServiceProvider = (. Get-RSACryptoServiceProvider)
    )
    $CypherBytes  = [System.Convert]::FromBase64String($CypherBase64)
    $ClearBytes = $RSACryptoServiceProvider.Decrypt($CypherBytes, $OAEPPadding)
    Return $ClearBytes
}
Function Do-RSAEncrypt {
    Param (
        [Parameter(Mandatory=$true)][Alias('cypher')][array]$ClearBase64,
        [Parameter(Mandatory=$true)][Alias('oaep')][boolean]$OAEPPadding = $false,
        [Parameter(Mandatory=$false)][Alias('RSA')][System.Security.Cryptography.RSACryptoServiceProvider]$RSACryptoServiceProvider = (. Get-RSACryptoServiceProvider)
    )
    $ClearBytes  = [System.Convert]::FromBase64String($ClearBase64)
    $CypherBytes = $RSACryptoServiceProvider.Encrypt($ClearBytes, $OAEPPadding)
    #$CypherString = [System.Text.Encoding]::ASCII.GetString($CypherBytes)
    Return $CypherBytes
}
