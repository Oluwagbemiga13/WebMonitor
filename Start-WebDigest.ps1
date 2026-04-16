using module ./modules/Snapshot.psm1
using module ./modules/Fetcher.psm1
using module ./modules/Config.psm1

[CmdletBinding()]
param()


# Import-Module (Join-Path $PSScriptRoot 'modules/Config.psm1') -Verbose:$isVerbose -Force
# Import-Module (Join-Path $PSScriptRoot 'modules/Fetcher.psm1') -Verbose:$isVerbose -Force
# Import-Module (Join-Path $PSScriptRoot 'modules/Snapshot.psm1') -Verbose:$isVerbose -Force


try {
    Write-Verbose "Loading configuration and listing pages..."
    Import-Config
    $Config.pages | ForEach-Object {
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