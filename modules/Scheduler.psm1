using module ./Snapshot.psm1
using module ./Fetcher.psm1
using module ./Config.psm1
using module ./Logger.psm1
using module ./Matcher.psm1
using module ./Email-Sender.psm1

<#
.SYNOPSIS
    Provides scheduling and orchestration logic for the WebMonitor application.

.DESCRIPTION
    This module defines the Scheduler class and the Invoke-Scheduler function.
    The Scheduler reads a time window and a check interval from the application
    configuration, then repeatedly fetches all monitored web pages, compares
    their content against stored snapshots, and sends email notifications when
    changes are detected.

    Outside the configured time window the Scheduler sleeps until the next
    start time, making it suitable for running as a long-lived background job.
#>

<#
    Orchestrates periodic web-page monitoring within a configured time window.

    On each cycle:
      1. Fetches all configured pages via Invoke-FetchAllPages.
      2. Creates a WebSnapshot for each fetched page.
      3. Compares the new snapshot hash against the previously stored hash.
      4. If the hash has changed, updates the snapshot file, searches for
         configured keywords, and sends a notification email.
      5. Sleeps until the next start time if the current time is outside
         the configured window.

    Relevant config keys (under the "scheduler" object):
      - startTime       	: HH:mm string 	– when monitoring begins each day.
      - endTime         	: HH:mm string 	– when monitoring stops each day.
      - checkIntervalSec	: int          	– seconds to wait between check cycles.
	  - NotifyOnHashChange	: bool 			- Send email even if keywords now found and only hash changed
#>
class Scheduler{
	# The time at which the scheduler begins processing each day.
	[System.DateTime]$Start

	# The time at which the scheduler stops processing each day.
	[System.DateTime]$End

	# Number of seconds to wait between consecutive check cycles.
	[int]$CheckIntervalSec
	
	# Send email even if keywords now found and only hash changed.
	[bool]$NotifyOnHashChange
	
	<#
	.SYNOPSIS
	    Initialises the Scheduler by reading values from the application config.

.DESCRIPTION
	    The constructor for the Scheduler class. It imports the application
	    configuration, reads the scheduled start and end times, and sets the
	    initial values for the Start and End properties. It also reads the
	    check interval and logs the created scheduler instance.

	    The time zone is not considered; the scheduler works off the local
	    system time.
	#>
	Scheduler(){
		
	$script:config = Import-Config
	$schedulerConfig = $script:config.scheduler
	
	$startArray = $schedulerConfig.startTime -split ":"
	$startHour = [int]$startArray[0]
	$startMinute = [int]$startArray[1]
	
	$endArray = $schedulerConfig.endTime -split ":"
	$endHour = [int]$endArray[0]
	$endMinute = [int]$endArray[1]
	
	$this.Start = Get-Date -Hour $startHour -Minute $startMinute -Second 0
	$this.End = Get-Date -Hour $endHour -Minute $endMinute -Second 0
	$this.NotifyOnHashChange = $schedulerConfig.notifyOnHashChange
	
	$this.CheckIntervalSec = $schedulerConfig.checkIntervalSec
	
	Write-Log -Message "Created new scheduler that will be running between $($this.Start.ToString('HH:mm')) and $($this.End.ToString('HH:mm'))" -Level "INFO"	
	}
	
	<#
	.SYNOPSIS
	    Resets the Start and End timestamps to the current date.

	.DESCRIPTION
	    Called automatically when the scheduler detects that the current time
	    has passed the end of today's window. Preserves the configured hour and
	    minute values while updating the date portion so that comparisons remain
	    accurate for the next calendar day.
	#>
	[void] ResetDate(){
		
		$this.Start = $this.Start.AddDays(1)
		$this.End = $this.End.AddDays(1)

		Write-Log -Message "Scheduler was reseted for the next day. It will start running on $($this.Start.ToString('yyyy-MM-dd HH:mm:ss'))" -Level "INFO"
	}
	
	<#
	.SYNOPSIS
	    Executes a single monitoring cycle.

	.DESCRIPTION
	    If the current time falls within the configured window, fetches all
	    pages, compares hashes, and sends notification emails for any pages
	    whose content has changed since the last snapshot.

	    If the current time is past the end of the window, resets the date
	    and sleeps until the next start time.
	#>
	[void]doProcess(){
		
		$now = Get-Date
		
		if($now.TimeOfDay -ge $this.Start.TimeOfDay -and $now.TimeOfDay -le $this.End.TimeOfDay) {
			Write-Log -Message "The time is within the window." -Level "DEBUG"
			
			Invoke-FetchAllPages | ForEach-Object {
			Write-Log -Message "Creating snapshot for page: $($_.Name)" -Level "DEBUG"
			
			$snapshot = [WebSnapshot]::new($_.Name, $_.Url, $_.Content)
	
			$hashEqual = Compare-Hash -Snapshot $snapshot
			Write-Log -Message "Hash equals : $($hashEqual) for $($snapshot.Name)" -Level "DEBUG"
	
			if(-not $hashEqual){
				New-SnapshotFile -Snapshot $snapshot
				
				$keywords = Find-Keywords -Snapshot $snapshot
				Write-Log -Message "Found these keywords: $($keywords) in $($snapshot.Name)" -Level "DEBUG"
				
				if($keywords.Count -eq 0 -and (-not $this.NotifyOnHashChange)){
					Write-Log -Message "No keywords were found. Not sending email."
					return
				}
				
				$htmlBody = New-EmailHtmlBody -Snapshot $snapshot -Keywords $keywords
				Send-Email -HtmlBody $htmlBody
			}
			else{
				Write-Log -Message "Hash is equal, nothing changed. Skipping email." -Level "INFO"
			}
	}
		}
		elseif($now.TimeOfDay -lt $this.Start.TimeOfDay){
			Write-Log -Message "It is too early. Sleeping until $($this.Start)" -Level "INFO"
			Start-Sleep -Seconds (New-TimeSpan -Start $now -End $this.Start).TotalSeconds
		}
		elseif($now.TimeOfDay -gt $this.End.TimeOfDay){
			$this.ResetDate()
			
			Write-Log -Message "It is past bedtime. Sleeping until $($this.Start)" -Level "INFO"
			Start-Sleep -Seconds (New-TimeSpan -Start $now -End $this.Start).TotalSeconds
		}
		
	}
}

<#
.SYNOPSIS
    Creates a Scheduler instance and starts the monitoring loop.

.DESCRIPTION
    Instantiates a Scheduler using the current application configuration,
    then calls doProcess() repeatedly, sleeping for CheckIntervalSec seconds
    between each iteration. Each cycle fetches all configured pages, compares
    their content against stored snapshots, and sends notification emails for
    any detected changes.

.EXAMPLE
    Invoke-Scheduler
#>
function Invoke-Scheduler{
	
	$scheduler = [Scheduler]::new()
	
	while($true){
		$scheduler.doProcess()
		Start-Sleep -Seconds $scheduler.CheckIntervalSec
	}
	
}