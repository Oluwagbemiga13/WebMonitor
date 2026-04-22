using module ./Logger.psm1

# Represents a single fetched page snapshot, including its content and SHA-256 hash.
class WebSnapshot
{

    [string]$Name
    [string]$Url
    [string]$Content
    [DateTime]$Timestamp
    [string]$Hash

    WebSnapshot([string]$Name, [string]$Url, [string]$Content)
    {
        $this.Name = $Name
        $this.Url = $Url
        $this.Content = $Content
        $this.Timestamp = Get-Date
        $stream = [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($Content))
        try
        {
            $this.Hash = (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash
        }
        finally
        {
            $stream.Dispose()
        }
    }
}

function New-SnapshotFile
{
    <#
    .SYNOPSIS
    Persists a WebSnapshot to disk as a JSON file.

    .DESCRIPTION
    Serializes the provided WebSnapshot and writes it to
    data\snapshots\<Name>.json under the current working directory.
    Creates or overwrites the file and logs the operation.

    .PARAMETER Snapshot
    The WebSnapshot instance to serialize and save.

    .OUTPUTS
    None

    .EXAMPLE
    $snap = [WebSnapshot]::new("ExamplePage", "https://example.com", "<html>...</html>")
    New-SnapshotFile -Snapshot $snap
    #>
    param (
        [WebSnapshot]$Snapshot
    )
    $fileName = "$( $Snapshot.Name ).json"
    $filePath = Join-Path (Get-Location) "data\snapshots\$fileName"
    $snapshot | ConvertTo-Json -Depth 2 | Out-File -FilePath $filePath -Encoding UTF8
    Write-Log -Message "Created snapshot file for $( $Snapshot.Name ) at $filePath" -Level "INFO"
}