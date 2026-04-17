
function Import-Config {
    param (
        [Parameter(Mandatory = $false)]
        [string]$configPath
    )
    Write-Verbose "Loading configuration..."

    if ($configPath) {
        Write-Verbose "Using provided configuration path: $configPath"
    }
    else {
        Write-Verbose "No configuration path provided. Using default path."
        $currentDir = Get-Location
        $configPath = Join-Path $currentDir "config\config.json"
    }

    if (-Not (Test-Path $configPath)) {
        throw "Configuration file not found at path: $configPath"
    }
    else {
        Write-Verbose "Configuration file found."
    }
    try {
        $configContent = Get-Content -Path $configPath -Raw
        $config = $configContent | ConvertFrom-Json
        Write-Verbose "Configuration loaded successfully."
        $config
    }
    catch {
        throw "Failed to load configuration: $_"
    }
}
