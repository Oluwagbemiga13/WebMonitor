using module ./Config.psm1
using module ./Logger.psm1
using module ./Secret-Manager.psm1

if (Get-Module -ListAvailable -Name "Send-MailKitMessage") {
    Write-Log -Message "Send-MailKitMessage module is installed." -Level "DEBUG"
} else {
	Write-Log -Message "Module is not installed." -Level "ERROR"
	Install-Module -Name "Send-MailKitMessage"
}

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
    $userEmail = $EmailConfig.email.sender
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
    Sends an email via MailKit based on config.email settings.
    If -Credential is not provided, one is created via New-EmailCredentials.
    If -Recipient or -Subject are omitted, defaults from configuration are used.
    When emailEnabled is false in config, the email is not sent but logged as a preview.

    .PARAMETER HtmlBody
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
    Send-Email -HtmlBody "<p> Keyword detected on monitored page.</p>"

    .EXAMPLE
    Send-Email -HtmlBody "<p>Change detected.</p>" -Recipient "ops@example.com" -Subject "WebMonitor Alert"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$HtmlBody,

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

    $emailConfig = $config.email

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
		-HtmlBody $HtmlBody `
		-Credential $Credential `
		
		Write-Log -Message "Email was sent with subject : $( $Subject ), content : $( $HtmlBody ) , sender : $( $emailConfig.sender )" -Level "DEBUG"
        Write-Log -Message "Email to $( $Recipient ) sent" -Level "INFO"
    }
    else
    {
        Write-Log -Message "Sending email is not enabled. Check your config file." -Level "WARN"
        Write-Log -Message "Email would look like this.`n Subject : $( $Subject )`n Sender : $( $emailConfig.sender ) `n Content : $( $HtmlBody )" -Level "WARN"
    }
}

function New-EmailHtmlBody {
	<#
	.SYNOPSIS
	Builds an HTML-formatted email body for a change-detection alert.

	.DESCRIPTION
	Generates a styled HTML email body containing the page name, URL,
	detection timestamp, and a list of matched keywords. Intended to be
	passed directly to Send-Email as the HtmlBody parameter.

	.PARAMETER Snapshot
	The WebSnapshot that triggered the alert. Provides the page name, URL,
	and detection timestamp.

	.PARAMETER KeyWords
	An array of keywords that were matched within the snapshot content.

	.OUTPUTS
	System.String

	.EXAMPLE
	$html = New-EmailHtmlBody -Snapshot $snapshot -KeyWords @("registration", "open")
	#>
	param(
		[Parameter(Mandatory=$true)]
		[WebSnapshot]$Snapshot,
		
		[Parameter(Mandatory=$true)]
		[string[]]$KeyWords
	)

	$pageName  = $Snapshot.Name
	$url       = $Snapshot.Url
	$timestamp = $Snapshot.Timestamp

	# Normalize / format keywords
	$keywordsHtml = if ($KeyWords -and $KeyWords.Count -gt 0) {
		($KeyWords | Sort-Object -Unique | ForEach-Object {
			"<li>$_</li>"
		}) -join "`n"
	}
	else {
		"<li>No specific keywords provided</li>"
	}

	$message = @"
<html>
<head>
    <style>
        body {
            font-family: Arial, sans-serif;
            color: #333;
            line-height: 1.5;
        }
        .container {
            padding: 16px;
        }
        .header {
            font-size: 18px;
            font-weight: bold;
            margin-bottom: 10px;
        }
        .section {
            margin-top: 12px;
        }
        .label {
            font-weight: bold;
        }
        .keywords {
            margin-top: 8px;
            padding-left: 20px;
        }
        .footer {
            margin-top: 20px;
            font-size: 12px;
            color: #777;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">Web Monitor Alert</div>

        <div class="section">
            A change has been detected on the monitored page.
        </div>

        <div class="section">
            <span class="label">Page:</span> $pageName<br/>
            <span class="label">URL:</span> <a href="$url">$url</a><br/>
            <span class="label">Detected at:</span> $timestamp
        </div>

        <div class="section">
            <span class="label">Matched Keywords:</span>
            <ul class="keywords">
                $keywordsHtml
            </ul>
        </div>

        <div class="footer">
            This notification was generated automatically by your Web Monitor service.
        </div>
    </div>
</body>
</html>
"@

	return $message
}