using module ./Logger.psm1

function Export-EncryptedCredentials
{
    <#
    .SYNOPSIS
    Saves encrypted credentials to a JSON secret file.

    .DESCRIPTION
    Serializes a SecureCredentials object using ConvertFrom-SecureString and
    writes the result to the configured secret file path. Creates the file if
    it does not already exist.

    .PARAMETER SecureCredentials
    A SecureCredentials object containing the username and password to encrypt.

    .PARAMETER RelativeFilePath
    Relative path to the secret file. Defaults to config/secret.json.

    .OUTPUTS
    None

    .EXAMPLE
    Export-EncryptedCredentials -SecureCredentials $creds

    .EXAMPLE
    Export-EncryptedCredentials -SecureCredentials $creds -RelativeFilePath "config/my-secret.json"
    #>
    param (
        [Parameter(Mandatory = $true)]
        $SecureCredentials,

        [Parameter(Mandatory = $false)]
        $RelativeFilePath = "config/secret.json"
    )



    $currentDir = Get-Location
    $filePath = Join-Path $currentDir $RelativeFilePath

    $file = $null

    if (-not (Test-Path $filePath))
    {
        Write-Log -Message "Secfret file does not exist. Created new one at $( $filePath )" -Level "INFO"
        $parentDir = Split-Path -Path $RelativeFilePath -Parent
        $fileName = Split-Path -Path $RelativeFilePath -Leaf
        $file = New-Item -Path Join-Path $currentDir $parentDir -Name $fileName -ItemType "File"
    }
    else
    {
        $file = Get-Item -Path $filePath
    }

    $encryptedUsername = ConvertFrom-SecureString $SecureCredentials.Username
    $encryptedPassword = ConvertFrom-SecureString $SecureCredentials.Password
    $json = [PSCustomObject]@{
        username = $encryptedUsername
        password = $encryptedPassword
    }

    $jsonString = ConvertTo-Json $json
    Set-Content -Path $file.FullName -Value $jsonString
    Write-Log -Message "Credentials stored" -Level "INFO"
}

function Get-CredentialFromInput
{
    <#
    .SYNOPSIS
    Prompts interactively for email credentials.

    .DESCRIPTION
    Reads an email address and password from the console and returns a
    SecureCredentials object with both values stored as SecureStrings.

    .OUTPUTS
    SecureCredentials

    .EXAMPLE
    $creds = Get-CredentialFromInput
    #>

    $username = Read-Host "Enter your email address: "
    $SecuredUsername = ConvertTo-SecureString $username -AsPlainText -Force
    $password = Read-Host "Enter your email password:" -AsSecureString
    return [SecureCredentials]::new($SecuredUsername, $password)
}

function Import-Credentials
{
    <#
    .SYNOPSIS
    Loads encrypted credentials from disk, or creates new ones interactively.

    .DESCRIPTION
    Reads credentials from the secret file and converts values back to
    SecureStrings. Use -New to force prompting for fresh credentials
    and overwrite the existing secret file.

    .PARAMETER RelativeFilePath
    Relative path to the secret file. Defaults to config/secret.json.

    .PARAMETER New
    Forces creation of new credentials via interactive prompt.

    .OUTPUTS
    SecureCredentials

    .EXAMPLE
    $creds = Import-Credentials

    .EXAMPLE
    $creds = Import-Credentials -New
    #>
    param(
        [Parameter(Mandatory = $false)]
        $RelativeFilePath = "config/secret.json",

        [switch]$New
    )

    $currentDir = Get-Location
    $filePath = Join-Path $currentDir $RelativeFilePath

    if (($New) -or (-not (Test-Path $RelativeFilePath)))
    {
        $credentials = Get-CredentialFromInput
        Export-EncryptedCredentials -SecureCredentials $Credentials
        return $credentials
    }


    $currentDir = Get-Location
    $filePath = Join-Path $currentDir $RelativeFilePath

    Write-Log -Message "Importing credentials from $( $filePath )" -Level "DEBUG"

    $json = Get-Content $filePath -Raw | ConvertFrom-Json

    $secureUSername = ConvertTo-SecureString $json.Username
    $securePassword = ConvertTo-SecureString $json.Password

    Write-Log -Message "Credentials succesfully imported." -Level "INFO"

    return [SecureCredentials]::new($secureUSername, $securePassword)


}

class SecureCredentials
{
    [SecureString]$Username
    [SecureString]$Password

    SecureCredentials([SecureString]$username, [SecureString]$password)
    {
        $this.Username = $username
        $this.Password = $password
    }
}
