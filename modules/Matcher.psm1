using module ./Logger.psm1
using module ./Config.psm1
using module ./Snapshot.psm1


$script:config = Import-Config

function Compare-Hash
{
    <#
    .SYNOPSIS
    Compares the current snapshot hash against the stored snapshot hash.

    .DESCRIPTION
    If no prior snapshot exists, creates one and returns $true (first run).
    If the hash has changed, updates the snapshot file and returns $false.
    If the hash is unchanged, returns $true.

    .PARAMETER Snapshot
    The current WebSnapshot to evaluate.

    .OUTPUTS
    System.Boolean

    .EXAMPLE
    $unchanged = Compare-Hash -Snapshot $snapshot
    #>
    param (
        [WebSnapshot]$Snapshot
    )
    Write-Log -Message "Comparing hash for snapshot: $( $Snapshot.Name )" -Level "INFO"
    $snapshotDir = Join-Path (Get-Location) "data\snapshots"
    $snapshotFile = Join-Path $snapshotDir "$( $Snapshot.Name ).json"
    if (-not (Test-Path $snapshotFile))
    {
        Write-Log -Message "No existing snapshot found for $( $Snapshot.Name ). This is the first snapshot." -Level "INFO"
        New-SnapshotFile -Snapshot $Snapshot
        return $true
    }
    $existingSnapshot = Get-Content -Path $snapshotFile -Raw | ConvertFrom-Json
    if ($existingSnapshot.Hash -ne $Snapshot.Hash)
    {
        Write-Log -Message "Content change detected for $( $Snapshot.Name ). Old Hash: $( $existingSnapshot.Hash ), New Hash: $( $Snapshot.Hash )" -Level "INFO"
        New-SnapshotFile -Snapshot $Snapshot
        return $false
    }
    else
    {
        Write-Log -Message "No content change detected for $( $Snapshot.Name ). Hash: $( $Snapshot.Hash )" -Level "INFO"
        return $true
    }
}

function Find-KeyWords
{
    <#
    .SYNOPSIS
    Searches a snapshot's content for configured keywords.

    .DESCRIPTION
    Resolves the page-specific keyword list from configuration by snapshot name
    and returns all keywords that match within the snapshot content.

    .PARAMETER Snapshot
    The WebSnapshot whose content should be scanned.

    .OUTPUTS
    System.String[]

    .EXAMPLE
    $found = Find-KeyWords -Snapshot $snapshot
    #>
    param (
        [WebSnapshot]$Snapshot
    )
    $pages = $script:config.fetcher.pages
    $pageConfig = $pages | Where-Object { $_.name -eq $Snapshot.Name }
    if (-not $pageConfig)
    {
        Write-Log -Message "No page configuration found for snapshot: $( $Snapshot.Name )" -Level "ERROR"
        throw "No page configuration found for snapshot: $( $Snapshot.Name )"
    }

    $keyWords = $pageConfig.keywords
    $caseSensitive = [System.Convert]::ToBoolean($script:config.matcher.caseSensitive)

    $foundKeywords = @()
    foreach ($keyWord in $keyWords)
    {
        Write-Log -Message "Looking for keyword : $( $keyWord )" -Level "DEBUG"

        $pattern = [regex]::Escape($keyWord)

        $found = if ($caseSensitive) {
            $Snapshot.Content -cmatch $pattern
        } else {
            $Snapshot.Content -imatch $pattern
        }

        if ($found) {
            Write-Log -Message "Found : $( $keyWord )" -Level "DEBUG"
            $foundKeywords += $keyWord
            Write-Log -Message "foundKeywords content : $( $foundKeywords )" -Level "DEBUG"
        }
        else {
            Write-Log -Message "$( $keyWord ) not found." -Level "DEBUG"
        }
    }

    return $foundKeywords
}