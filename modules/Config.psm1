using module ./Logger.psm1

function Import-Config
{
    param (
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )
    Write-Log -Message "Loading configuration..." -Level "INFO"

    if ($ConfigPath)
    {
        Write-Log -Message "Using provided configuration path: $ConfigPath" -Level "INFO"
    }
    else
    {
        Write-Log -Message "No configuration path provided. Using default path." -Level "INFO"
        $currentDir = Get-Location
        $ConfigPath = Join-Path $currentDir "config\config.json"
    }

    if (-Not (Test-Path $ConfigPath))
    {
        Write-Log -Message "Configuration file not found at path: $ConfigPath" -Level "ERROR"
        throw "Configuration file not found at path: $ConfigPath"
    }
    else
    {
        Write-Log -Message "Configuration file found." -Level "INFO"
    }
    try
    {
        $configContent = Get-Content -Path $ConfigPath -Raw
        $config = $configContent | ConvertFrom-Json
        Write-Log -Message "Configuration loaded successfully." -Level "INFO"
        $config
    }
    catch
    {
        Write-Log -Message "Failed to load configuration: $_" -Level "ERROR"
        throw "Failed to load configuration: $_"
    }
}
