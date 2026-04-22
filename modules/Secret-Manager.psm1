using module ./Logger.psm1

function Store-EncryptedCredentials
{
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

    $username = Read-Host "Enter your email address: "
    $SecuredUsername = ConvertTo-SecureString $username -AsPlainText -Force
    $password = Read-Host "Enter your email password:" -AsSecureString
    return [SecureCredentials]::new($SecuredUsername, $password)
}

function ImportCredentials
{
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
        Store-EncryptedCredentials -SecureCredentials $Credentials
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
