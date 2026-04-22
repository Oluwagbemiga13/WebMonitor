using module ./Config.psm1
using module ./Logger.psm1
using module ./Secret-Manager.psm1

Import-Module Send-MailKitMessage -Force
Import-Module Microsoft.PowerShell.Security -Force


function New-EmailCredentials
{
    <#
    .SYNOPSIS
    Builds SMTP credentials from stored secrets and configuration.

    .DESCRIPTION
    Imports encrypted credentials and application configuration, validates that
    the configured sender email matches the stored secret username, then returns
    a PSCredential used for SMTP authentication.

    .OUTPUTS
    System.Management.Automation.PSCredential

    .EXAMPLE
    $cred = New-EmailCredentials
    #>
    $Credentials = Import-Credentials
    $EmailConfig = Import-Config

    $secretEmail = ConvertFrom-SecureString $Credentials.Username -AsPlainText
    $userEmail = $EmailConfig.common.email.sender
    if ( [string]::IsNullOrEmpty($secretEmail))
    {
        Write-Log -Message "Username from secret is null or empty" -Level "ERROR"
        throw "Username from secret is null or empty"
    }
    if ( [string]::IsNullOrEmpty($userEmail))
    {
        Write-Log -Message "User email from config is null or empty" -Level "ERROR"
        throw "User email from config is null or empty"
    }

    if ($secretEmail -ne $userEmail)
    {
        Write-Log -Message "There is mismatch between address in config and secret. Check your configurations. Secret email : $( $secretEmail ) , Config email : $( $userEmail )" -Level "ERROR"
        throw "There is mismatch between email address in config and secret. Check your configurations"
    }
    Write-Log -Message "Email addresses in config files match." -Level "DEBUG"

    $securePassword = $Credentials.Password
    $credential = New-Object System.Management.Automation.PSCredential ($userEmail, $securePassword)
    Write-Log -Message "Credential successfully created" -Level "INFO"
    return $credential
}

function Send-Email
{
    <#
    .SYNOPSIS
    Sends a notification email using configured SMTP settings.

    .DESCRIPTION
    Sends an email via MailKit based on config.common.email settings.
    If -Credential is not provided, one is created via New-EmailCredentials.
    If -Recipient or -Subject are omitted, defaults from configuration are used.
    When emailEnabled is false in config, the email is not sent but logged as a preview.

    .PARAMETER Message
    The email body text.

    .PARAMETER Credential
    Optional SMTP credential. If omitted, credentials are loaded automatically.

    .PARAMETER Recipient
    Optional recipient email address. Defaults to the configured recipient.

    .PARAMETER Subject
    Optional email subject line. Defaults to "Web monitor found something".

    .OUTPUTS
    None

    .EXAMPLE
    Send-Email -Message "Keyword detected on monitored page."

    .EXAMPLE
    Send-Email -Message "Change detected." -Recipient "ops@example.com" -Subject "WebMonitor Alert"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential,

        [Parameter(Mandatory = $false)]
        [string]$Recipient,

        [Parameter(Mandatory = $false)]
        [string]$Subject
    )

    if (-not $Credential)
    {
        $Credential = New-EmailCredentials
        Write-Log -Message "Using default credential" -Level "DEBUG"
    }

    $config = Import-Config

    $emailConfig = $config.common.email

    if (-not $Recipient)
    {
        $Recipient = $emailConfig.recipient
        Write-Log -Message "Using default recipient" -Level "DEBUG"
    }

    if (-not $Subject)
    {
        $Subject = "Web monitor found something"
        Write-Log -Message "Using default subject" -Level "DEBUG"
    }

    if ( [System.Convert]::ToBoolean($emailConfig.emailEnabled))
    {
        $RecipientList = [MimeKit.InternetAddressList]::new();
        $RecipientList.Add([MimeKit.InternetAddress]$Recipient);

        Send-MailKitMessage `
		-SMTPServer $emailConfig.smtp_server `
		-Port  $emailConfig.port `
		-From $emailConfig.sender `
		-RecipientList $RecipientList `
		-Subject $Subject `
		-TextBody $Message `
		-Credential $Credential `
		
		Write-Log -Message "Email was sent with subject : $( $Subject ), content : $( $Message ) , sender : $( $emailConfig.sender )" -Level "DEBUG"
        Write-Log -Message "Email to $( $Recipient ) sent" -Level "INFO"
    }
    else
    {
        Write-Log -Message "Sending email is not enabled. Check your config file." -Level "WARN"
        Write-Log -Message "Email would look like this.`n Subject : $( $Subject )`n Sender : $( $emailConfig.sender ) `n Content : $( $Message )" -Level "WARN"
    }

}