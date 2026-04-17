using module ./Logger.psm1

function Import-Config {
    param (
        [Parameter(Mandatory = $false)]
        [string]$configPath
    )
    Write-Log -Message "Loading configuration..." -Level "INFO"

    if ($configPath) {
        Write-Log -Message "Using provided configuration path: $configPath" -Level "INFO"
    }
    else {
        Write-Log -Message "No configuration path provided. Using default path." -Level "INFO"
        $currentDir = Get-Location
        $configPath = Join-Path $currentDir "config\config.json"
    }

    if (-Not (Test-Path $configPath)) {
        Write-Log -Message "Configuration file not found at path: $configPath" -Level "ERROR"
        throw "Configuration file not found at path: $configPath"
    }
    else {
        Write-Log -Message "Configuration file found." -Level "INFO"
    }
    try {
        $configContent = Get-Content -Path $configPath -Raw
        $config = $configContent | ConvertFrom-Json
        Write-Log -Message "Configuration loaded successfully." -Level "INFO"
        $config
    }
    catch {
        Write-Log -Message "Failed to load configuration: $_" -Level "ERROR"
        throw "Failed to load configuration: $_"
    }
}
