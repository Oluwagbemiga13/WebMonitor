using module ./Logger.psm1

class WebSnapshot {
   
        [string]$Name
        [string]$Url
        [string]$Content
        [DateTime]$Timestamp
        [string]$Hash

    WebSnapshot([string]$Name, [string]$Url, [string]$Content) {
        $this.Name = $Name
        $this.Url = $Url
        $this.Content = $Content
        $this.Timestamp = Get-Date
        $stream = [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($Content))
        try {
            $this.Hash = (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash
        }
        finally {
            $stream.Dispose()
        }
}
}

function New-SnapshotFile {
    param (
        [WebSnapshot]$Snapshot
    )
    $fileName = "$($Snapshot.Name).json"
    $filePath = Join-Path (Get-Location) "data\snapshots\$fileName"
    $snapshot | ConvertTo-Json -Depth 2 | Out-File -FilePath $filePath -Encoding UTF8
    Write-Log -Message "Created snapshot file for $($Snapshot.Name) at $filePath" -Level "INFO"
}