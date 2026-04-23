$InformationPreference = 'Continue'

if ($PSVersionTable.PSVersion.Major -ne 7) {
    throw "This script requires PowerShell 7.x. Current version: $($PSVersionTable.PSVersion)"
}

function Get-LoggerConfig
{
    <#
    .SYNOPSIS
    Loads logger settings from the application configuration file.

    .DESCRIPTION
    Reads config\config.json from the current working directory and returns
    the deserialized object consumed by the logging subsystem.

    .OUTPUTS
    PSCustomObject

    .EXAMPLE
    $cfg = Get-LoggerConfig
    #>
    $currentDir = Get-Location
    $configPath = Join-Path $currentDir "config\config.json"
    if (-Not (Test-Path $configPath))
    {
        Write-Error "Configuration file not found at path: $configPath"
        throw "Configuration file not found at path: $configPath"
    }
    try
    {
        $configContent = Get-Content -Path $configPath -Raw
        $config = $configContent | ConvertFrom-Json
        Write-Verbose "Configuration loaded successfully."
        return $config
    }
    catch
    {
        Write-Error "Failed to load configuration: $_"
        throw "Failed to load configuration: $_"
    }

}

$script:config = Get-LoggerConfig

# Holds the active logger configuration, including the minimum log level and the target log file path.
class Logger
{
    [string]$LogLevel
    [string]$LogFile

    Logger([string]$LogLevel, [string]$LogFile)
    {
        $this.LogLevel = $LogLevel
        $this.LogFile = $LogFile
    }

}

# Represents a single structured log entry, including the invoker, severity level, timestamp, and message.
# Provides serialization to a formatted log line and deserialization from one via the static fromMessage method.
class Log
{
    [string]$Invoker
    [string]$Level
    [DateTime]$Timestamp
    [string]$Message

    Log([string]$Invoker, [string]$Level, [string]$Message)
    {
        $this.Invoker = $Invoker
        $this.Level = $Level
        $this.Timestamp = Get-Date
        $this.Message = $Message
    }

    [string]
    toMessage()
    {
        return "$($this.Timestamp.ToString('yyyy-MM-dd HH:mm:ss.fff') ) [$( $this.Level )] $( $this.Invoker ): $( $this.Message )"

    }

    [Log]
    static fromMessage([string]$logLine)
    {
        $pattern = '^(?<Timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}) \[(?<Level>\w+)\] (?<Invoker>[^:]+): (?<Message>.+)$'
        $match = [regex]::Match($logLine, $pattern)
        if ($match.Success)
        {
            return [Log]::new($match.Groups['Invoker'].Value, $match.Groups['Level'].Value, $match.Groups['Message'].Value)
        }
        throw "Failed to parse log line: $logLine"
    }
}


function New-Logger
{
    <#
    .SYNOPSIS
    Initializes the module-level logger instance.

    .DESCRIPTION
    Creates a Logger object and ensures the configured log file exists on disk.
    Called automatically by Write-Log when no logger has been initialized yet.

    .PARAMETER LogLevel
    Minimum severity level to record. One of: DEBUG, INFO, WARN, ERROR.

    .PARAMETER LogFile
    Path to the log file. Defaults to the value in config.logging.file.

    .OUTPUTS
    None

    .EXAMPLE
    New-Logger -LogLevel INFO -LogFile ".\logs\webmonitor.log"
    #>
    [CmdletBinding()]
    param (
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$LogLevel = $script:config.logging.level,
        [string]$LogFile = $script:config.logging.file
    )
    Write-Verbose "Initializing logger with level: $LogLevel and file: $LogFile"
    [Logger]$script:Logger = [Logger]::new($LogLevel, $LogFile)

    if (-not (Test-Path -Path $LogFile))
    {
        Write-Verbose "Log file does not exist. Creating new log file at: $LogFile"
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

function Write-ColoredInfo
{
    <#
    .SYNOPSIS
    Writes a colored message to the information stream.

    .DESCRIPTION
    Outputs a message to the PowerShell information stream using ANSI color
    codes. Used internally by Write-Log to produce color-coded console output.

    .PARAMETER Message
    The text to display.

    .PARAMETER Color
    The ANSI foreground color to apply. Defaults to Cyan.
    Accepts any color name supported by $PSStyle.Foreground.

    .OUTPUTS
    None

    .EXAMPLE
    Write-ColoredInfo -Message "Operation complete." -Color "Green"
    #>
    param([string]$Message, [string]$Color = "Cyan")
    $ansiColor = $PSStyle.Foreground.$Color
    Write-Information "$ansiColor$Message$( $PSStyle.Reset )" -InformationAction Continue
}

function Write-Log
{
    <#
    .SYNOPSIS
    Writes a structured log entry to file and optionally to the console.

    .DESCRIPTION
    Creates a timestamped log record, filters by the configured minimum level,
    appends to the log file, and writes color-coded console output when
    config.logging.console is enabled. Initializes the logger automatically
    if it has not been set up yet.

    .PARAMETER Message
    The log message text.

    .PARAMETER Level
    Severity level of the entry. One of: DEBUG, INFO, WARN, ERROR. Defaults to INFO.

    .OUTPUTS
    None

    .EXAMPLE
    Write-Log -Message "Fetching complete." -Level INFO

    .EXAMPLE
    Write-Log -Message "Unexpected response code." -Level WARN
    #>
    param (
        [string]$Message,
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    if (-not (Test-Path variable:script:Logger))
    {
        Write-Verbose "Logger not initialized. Initializing now."
        New-Logger
    }

    $logPriority = @{
        "DEBUG" = 1
        "INFO" = 2
        "WARN" = 3
        "ERROR" = 4
    }

    if ($logPriority[$Level] -lt $logPriority[$script:Logger.LogLevel])
    {
        return
    }

    $invoker =
    if ($MyInvocation.PSCommandPath)
    {
        Split-Path -Leaf $MyInvocation.PSCommandPath
    }
    elseif ($MyInvocation.ScriptName)
    {
        Split-Path -Leaf $MyInvocation.ScriptName
    }
    else
    {
        $MyInvocation.InvocationName
    }

    $logEntry = [Log]::new($invoker, $Level, $Message)
    $logLine = $logEntry.toMessage()
    Write-Verbose "Writing log entry: $logLine"
    Add-Content -Path $script:Logger.LogFile -Value $logLine
    if ($script:config.logging.console)
    {
        switch ($Level)
        {
            "DEBUG" {
                Write-ColoredInfo -Message $logLine -Color "White"
            }
            "INFO" {
                Write-ColoredInfo -Message $logLine -Color "White"
            }
            "WARN" {
                Write-ColoredInfo -Message $logLine -Color "Yellow"
            }
            "ERROR" {
                Write-ColoredInfo -Message $logLine -Color "Red"
            }
        }
    }
}

