# WebMonitor

WebMonitor is a PowerShell-based web page monitoring tool. It periodically fetches configured pages, cleans volatile
HTML content (scripts, styles, comments), compares results against stored snapshots, and sends email notifications
when changes and configured keywords are detected.

> **Learning Project** – This project was built as a personal learning exercise to explore PowerShell module
> development, object-oriented scripting, and automation patterns. All source code (every `.psm1` and `.ps1` file)
> was written entirely in **Notepad++**. Only the README and inline documentation were written with AI
> assistance.

## Features

- **Change detection** – SHA-256 hashes are compared between fetch cycles; any content change triggers an alert.
- **Keyword matching** – Each page has its own keyword list; matched terms are included in the notification email.
- **Configurable notification behaviour** – `notifyOnHashChange` controls whether an email is sent on every hash change or only when keywords are matched.
- **Scheduled monitoring** – Runs within a configurable daily time window, sleeping outside of it.
- **HTML noise removal** – Configurable regex rules strip scripts, styles, and comments before comparison.
- **Email notifications** – Styled HTML emails are sent via SMTP using MailKit when changes or keywords are found.
- **Structured logging** – Timestamped, level-filtered log entries written to file and optionally to the console.
- **Encrypted credential storage** – SMTP credentials are encrypted using the Windows Data Protection API (DPAPI)
  and stored locally; they can only be decrypted on the same machine and user account that created them.

## Prerequisites

- PowerShell 7.2 or later
- Windows (required for DPAPI-based credential encryption)
- [Send-MailKitMessage](https://www.powershellgallery.com/packages/Send-MailKitMessage) module

```powershell
Install-Module -Name Send-MailKitMessage
```

## Configuration

### Step 1 – Create `config/config.json` from the example

Copy `config/config.json.example` to `config/config.json` and fill in your values:

```powershell
Copy-Item config/config.json.example config/config.json
```

The example file contains all available fields with placeholder values. **Do not use the example file directly** —
it contains a syntax error (`emailEnabled` is missing its colon) that is intentional to prevent accidental use.

### Config field reference

The configuration file is organized into five top-level sections: `fetcher`, `matcher`, `scheduler`, `email`, and `logging`.

#### `fetcher`

| Field                               | Description                                                                                                                              |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `fetcher.timeoutSec`                | Default HTTP request timeout in seconds.                                                                                                 |
| `fetcher.regexesForRemoval[]`       | Regex rules applied to strip noise before hashing. Each entry has `pattern`, `replacement`, `multiline`, `singleline`, and `description`. |
| `fetcher.pages[]`                   | List of pages to monitor.                                                                                                                |
| `fetcher.pages[].name`              | Label used for snapshot files and log messages. Must be unique.                                                                          |
| `fetcher.pages[].url`               | URL to fetch.                                                                                                                            |
| `fetcher.pages[].keywords`          | Words or phrases to search for in the cleaned page content.                                                                              |

#### `matcher`

| Field                    | Description                                  |
| ------------------------ | -------------------------------------------- |
| `matcher.caseSensitive`  | Whether keyword matching is case-sensitive.  |

#### `scheduler`

| Field                              | Description                                                                                                                                     |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `scheduler.startTime`              | `HH:mm` – when monitoring begins each day.                                                                                                     |
| `scheduler.endTime`                | `HH:mm` – when monitoring stops each day.                                                                                                      |
| `scheduler.checkIntervalSec`       | Seconds to wait between consecutive check cycles.                                                                                               |
| `scheduler.notifyOnHashChange`     | Set to `true` to send an email whenever the hash changes, even if no keywords were matched. Set to `false` to only send emails when keywords are found. |

#### `email`

| Field                  | Description                                                                    |
| ---------------------- | ------------------------------------------------------------------------------ |
| `email.emailEnabled`   | Set to `true` to send emails; `false` logs a preview instead.                  |
| `email.smtp_server`    | SMTP server hostname.                                                          |
| `email.port`           | SMTP port (e.g. `465` for SSL).                                                |
| `email.sender`         | Sender email address. Must match the username stored in `secret.json`.         |
| `email.recipient`      | Default recipient email address.                                               |
| `email.subject`        | Email subject line for alert notifications.                                    |

#### `logging`

| Field              | Description                                              |
| ------------------ | -------------------------------------------------------- |
| `logging.level`    | Minimum log level: `DEBUG`, `INFO`, `WARN`, or `ERROR`.  |
| `logging.file`     | Path to the log file.                                    |
| `logging.console`  | Set to `true` to echo log entries to the console.        |

### Step 2 – Store SMTP credentials (`config/secret.json`)

SMTP credentials are **not stored in plain text**. They are encrypted using the
[Windows Data Protection API (DPAPI)](https://learn.microsoft.com/en-us/dotnet/standard/security/how-to-use-data-protection)
via PowerShell's `ConvertFrom-SecureString` cmdlet. The encrypted data is tied to the Windows user account and
machine that performed the encryption — credentials cannot be decrypted on a different machine or by a different
user.

`secret.json` is generated automatically on the first run. You will be prompted for your email address and
password, which are then encrypted and written to disk. To regenerate credentials manually:

```powershell
Import-Module ./modules/Secret-Manager.psm1
Import-Credentials -New
```

> Never commit `config/secret.json` to source control.

## Run

From the project root:

```powershell
pwsh ./Start-WebDigest.ps1
```

> **Note:** Configuration and modules are cached at the script level. Restart the PowerShell session after making
> any changes to `config.json` or module files.

The scheduler runs indefinitely `scheduler.checkIntervalSec` seconds between
each one. Outside the configured time window it sleeps until the next start time before resuming.

## Project Structure

```
WebMonitor/
├── Start-WebDigest.ps1          # Entry point – starts the scheduler loop.
├── config/
│   ├── config.json              # Main configuration file (created from the example).
│   ├── config.json.example      # Annotated configuration reference – copy and edit this.
│   └── secret.json              # DPAPI-encrypted SMTP credentials (auto-generated, do not commit).
├── data/
│   └── snapshots/               # JSON snapshot files, one per monitored page.
├── logs/
│   └── webmonitor.log           # Structured log output.
└── modules/
    ├── Config.psm1              # Loads and validates config.json.
    ├── Email-Sender.psm1        # Builds and sends HTML notification emails.
    ├── Fetcher.psm1             # Fetches pages and removes noise via regex.
    ├── Logger.psm1              # Structured, level-filtered logging.
    ├── Matcher.psm1             # Hash comparison and keyword detection.
    ├── Scheduler.psm1           # Scheduling loop and orchestration.
    ├── Secret-Manager.psm1      # DPAPI-based credential storage and retrieval.
    └── Snapshot.psm1            # Snapshot data model and file persistence.
```

## How It Works

1. `Invoke-Scheduler` creates a `Scheduler` instance and runs **indefinitely**, sleeping
   `checkIntervalSec` seconds between each cycle.
2. Each cycle calls `Invoke-FetchAllPages`, which iterates over `fetcher.pages`, fetches every configured URL,
   applies the `fetcher.regexesForRemoval` cleanup rules, and returns cleaned content as `FetchResult` objects.
3. A `WebSnapshot` is created for each page — its content is hashed with SHA-256.
4. `Compare-Hash` checks the new hash against the stored snapshot file. On first run, a baseline snapshot is
   saved and no alert is sent.
5. If the hash has changed, the snapshot file is updated and `Find-KeyWords` scans the content for keywords
   configured in `fetcher.pages[].keywords`.
   - If keywords are found, a styled HTML notification is sent via `Send-Email`.
   - If no keywords are found but `scheduler.notifyOnHashChange` is `true`, an email is still sent.
   - If no keywords are found and `scheduler.notifyOnHashChange` is `false`, the change is logged but no email is sent.
6. Outside the configured time window the scheduler sleeps until the next start time before resuming.
