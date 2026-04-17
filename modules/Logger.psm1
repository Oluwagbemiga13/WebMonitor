


$InformationPreference = 'Continue'


function Import-Config {
    $currentDir = Get-Location
    $configPath = Join-Path $currentDir "config\config.json"
    if (-Not (Test-Path $configPath)) {
        Write-Error "Configuration file not found at path: $configPath"
        throw "Configuration file not found at path: $configPath"
    }
    try {
        $configContent = Get-Content -Path $configPath -Raw
        $config = $configContent | ConvertFrom-Json
        Write-Verbose "Configuration loaded successfully."
        return $config
    }
    catch {
        Write-Error "Failed to load configuration: $_"
        throw "Failed to load configuration: $_"
    }
    
}

$script:config = Import-Config

class Logger {
    [string]$LogLevel
    [string]$LogFile

    Logger([string]$LogLevel, [string]$LogFile) {
        $this.LogLevel = $LogLevel
        $this.LogFile = $LogFile
    }

}

class Log {
    [string]$Invoker
    [string]$Level
    [DateTime]$Timestamp
    [string]$Message

    Log([string]$Invoker, [string]$Level, [string]$Message) {
        $this.Invoker = $Invoker
        $this.Level = $Level
        $this.Timestamp = Get-Date
        $this.Message = $Message    
    }

    [string] toMessage() {
        return "$($this.Timestamp.ToString('yyyy-MM-dd HH:mm:ss.fff')) [$($this.Level)] $($this.Invoker): $($this.Message)"

    }

    [Log] static fromMessage([string]$logLine) {
        $pattern = '^(?<Timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}) \[(?<Level>\w+)\] (?<Invoker>[^:]+): (?<Message>.+)$'
        $match = [regex]::Match($logLine, $pattern)
        if ($match.Success) {
            return [Log]::new($match.Groups['Invoker'].Value, $match.Groups['Level'].Value, $match.Groups['Message'].Value)
        }
        throw "Failed to parse log line: $logLine"
    }
}


function New-Logger {
    [CmdletBinding()]
    param (
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$LogLevel = $script:config.logging.level,
        [string]$LogFile = $script:config.logging.file
    )
    Write-Verbose "Initializing logger with level: $LogLevel and file: $LogFile"
    [Logger]$script:Logger = [Logger]::new($LogLevel, $LogFile)
    
    if ( -not (Test-Path -Path $LogFile)) {
        Write-Verbose "Log file does not exist. Creating new log file at: $LogFile"
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

function Write-ColoredInfo {
    param([string]$Message, [string]$Color = "Cyan")
    $ansiColor = $PSStyle.Foreground.$Color
    Write-Information "$ansiColor$Message$($PSStyle.Reset)" -InformationAction Continue
}

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    if ( -not (Test-Path variable:script:Logger)) {
        Write-Verbose "Logger not initialized. Initializing now."
        New-Logger
    }

    $logPriority = @{
        "DEBUG" = 1
        "INFO"  = 2
        "WARN"  = 3
        "ERROR" = 4
    }

    if ($logPriority[$Level] -lt $logPriority[$script:Logger.LogLevel]) {
        return
    }

    $invoker =
    if ($MyInvocation.PSCommandPath) { Split-Path -Leaf $MyInvocation.PSCommandPath }
    elseif ($MyInvocation.ScriptName) { Split-Path -Leaf $MyInvocation.ScriptName }
    else { $MyInvocation.InvocationName }

    $logEntry = [Log]::new($invoker, $Level, $Message)    
    $logLine = $logEntry.toMessage()
    Write-Verbose "Writing log entry: $logLine"
    Add-Content -Path $script:Logger.LogFile -Value $logLine
    if ($script:config.logging.console) {  
        switch ($Level) {
            "DEBUG" { Write-ColoredInfo -Message $logLine -Color "White" }
            "INFO" { Write-ColoredInfo -Message $logLine -Color "White" }
            "WARN" { Write-ColoredInfo -Message $logLine -Color "Yellow" }
            "ERROR" { Write-ColoredInfo -Message $logLine -Color "Red" }
        }
    }
}

