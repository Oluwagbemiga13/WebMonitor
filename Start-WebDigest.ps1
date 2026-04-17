using module ./modules/Snapshot.psm1
using module ./modules/Fetcher.psm1
using module ./modules/Config.psm1
using module ./modules/Logger.psm1

[CmdletBinding()]
param()

$InformationPreference = 'Continue'


Write-Warning "Configuration and modules are cached at the script level. If you make changes to the configuration or modules, you will need to restart the PowerShell session for the changes to take effect." 

$script:config = Import-Config

try {
    Write-Verbose "Loading configuration and listing pages..."
    $script:config.pages | ForEach-Object {
        Write-Verbose "Page Name: $($_.name)"
        Write-Verbose "Page URL: $($_.url)"
    }
} catch {
    Write-Error "An error occurred: $_"
}


# $testContent = Get-Content "D:\Git\WebMonitor\testPage.txt" -Raw
# try {
#     Write-Verbose "Running content cleanup test on testPage.txt..."
#     Write-Verbose "Original Content:"
#     Write-Verbose $testContent
#     $cleanedContent = Remove-ExtraContent -HtmlContent $testContent
#     Write-Verbose "Cleaned Content:"
#     Write-Verbose $CleanedContent
# } catch {
#     Write-Error "An error occurred while cleaning content: $_"
# }

Invoke-FetchAllPages | ForEach-Object {
    Write-Verbose "Creating snapshot for page: $($_.Name)"
    $snapshot = [WebSnapshot]::new($_.Name, $_.Url, $_.Content)
    New-SnapshotFile -Snapshot $snapshot
}

Write-Log -Message "WebDigest script execution completed." -Level "INFO"
Write-Log -Message "This is a debug message." -Level "DEBUG"
Write-Log -Message "This is a warning message." -Level "WARN"
Write-Log -Message "This is an error message." -Level "ERROR"