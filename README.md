# WebMonitor

WebMonitor is a PowerShell project for watching web pages.

It reads a list of pages from `config/config.json`, fetches each page, cleans volatile HTML content (scripts, styles,
comments), and compares results with saved snapshots.

Goal:

- Notify the user when page content changes.
- Notify the user when configured keywords are found.

## Configuration

Main config file: `config/config.json`

Key fields:

- `common.timeoutSec`: default request timeout.
- `common.snapshotFolder`: where snapshots are stored.
- `common.caseSensitive`: keyword matching mode.
- `common.regexesForRemoval`: regex cleanup rules applied before comparison.
- `pages[]`: list of pages to monitor.
    - `name`: page label.
    - `url`: page address.
    - `keywords`: words/phrases to detect.
    - `timeoutSec` (optional): page-specific timeout override.

## Run

From the project root:

```powershell
pwsh ./Start-WebDigest.ps1
```

## Project Structure

- `Start-WebDigest.ps1`: entry script.
- `modules/Config.psm1`: config loading.
- `modules/Fetcher.psm1`: fetch and HTML cleanup logic.
- `config/config.json`: monitored pages and rules.
- `data/`: snapshots and runtime data.
- `logs/`: log output.

## Status

Current repository contains the core fetch/cleanup building blocks. Change detection and notification flow can be
expanded from this base.
