using module ./Logger.psm1
using module ./Config.psm1
using module ./Snapshot.psm1


$script:config = Import-Config

function Compare-Hash
{
    <# 
.SYNOPSIS
Compares the hash of the current snapshot with the existing snapshot to determine if there has been a content change.

.DESCRIPTION
If there is a change, it updates the snapshot file with the new content and hash.
Returns $true if there is no change, and $false if there is a change.
Returns $true if this is the first snapshot (no existing snapshot file), and creates the snapshot file.
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
    param (
        [WebSnapshot]$Snapshot
    )
    $pages = $script:config.pages
    $pageConfig = $pages | Where-Object { $_.name -eq $Snapshot.Name }
    if (-not $pageConfig)
    {
        Write-Log -Message "No page configuration found for snapshot: $( $Snapshot.Name )" -Level "ERROR"
        throw "No page configuration found for snapshot: $( $Snapshot.Name )"
    }

    $keyWords = $pageConfig.keywords

    $foundKeywords = @()
    foreach ($keyWord in $keyWords)
    {
        Write-Log -Message "Looking for keyword : $( $keyWord )" -Level "DEBUG"
        if ($Snapshot.Content -match ([regex]::Escape($keyWord)))
        {
            Write-Log -Message "Found : $( $keyWord )" -Level "DEBUG"
            $foundKeywords += $keyWord
            Write-Log -Message "foundKeywords content : $( $foundKeywords )" -Level "DEBUG"
        }
        else
        {
            Write-Log -Message "$( $keyWord ) not found." -Level "DEBUG"
        }
    }

    return $foundKeywords
}