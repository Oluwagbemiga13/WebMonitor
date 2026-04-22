using module ./Config.psm1
using module ./Logger.psm1

$script:config = Import-Config

# Fetches data from the specified URL and returns the response object.
function Get-Data {
param (
[string]$Url
)
Write-Log -Message "Fetching data from $Url" -Level "INFO"
$timeoutSec = if ($script:config -and $script:config.common -and $script:config.common.timeoutSec) {
[int]$script:config.common.timeoutSec
} else {
15
}

$response = Invoke-WebRequest -Uri $Url -TimeoutSec $timeoutSec -ErrorAction Stop
if ($response.StatusCode -ne 200) {
Write-Log -Message "Failed to fetch data from $Url. Status code: $($response.StatusCode)" -Level "ERROR"
throw "Failed to fetch data from $Url. Status code: $($response.StatusCode)"
}
return $response
}

# Converts the response content to HTML format.
function Get-HtmlContent {
param (
[object]$Response
)
Write-Log -Message "Converting response to HTML format" -Level "INFO"
$htmlContent = $Response.Content
if (-not [string]::IsNullOrWhiteSpace($htmlContent)) {
return $htmlContent
}
Write-Log -Message "Failed to convert response to HTML. Content is empty." -Level "ERROR"
throw "Failed to convert response to HTML. Content is empty."

}

# Removes scripts, styles, and comments from the HTML content to clean it up.
function Remove-ExtraContent {
param (
[string]$HtmlContent
)
$regexes = $script:config.common.regexesForRemoval

foreach ($regex in $regexes) {
$regexOptions = [System.Text.RegularExpressions.RegexOptions]::None
if ($regex.multiline) {
$regexOptions = $regexOptions -bor [System.Text.RegularExpressions.RegexOptions]::Multiline
}
if ($regex.singleline) {
$regexOptions = $regexOptions -bor [System.Text.RegularExpressions.RegexOptions]::Singleline
}

# Protect against catastrophic regex backtracking on large pages.
$HtmlContent = [regex]::Replace(
$HtmlContent,
$regex.pattern,
$regex.replacement,
$regexOptions,
[TimeSpan]::FromSeconds(5)
)
Write-Log -Message "Applied regex for removal: $($regex.pattern)" -Level "DEBUG"
}

if (-not [string]::IsNullOrWhiteSpace($HtmlContent)) {
return $HtmlContent
}

Write-Log -Message "Failed to format HTML content. Content is empty after formatting." -Level "ERROR"
throw "Failed to format HTML content. Content is empty after formatting."


}

function Invoke-FetchPage {
param (
[string]$Url
)

$response = Get-Data -Url $Url
$htmlContent = Get-HtmlContent -Response $response
$cleanedContent = Remove-ExtraContent -HtmlContent $htmlContent
$name = $Url.Replace("https://", "").Replace("http://", "").Replace("/", "_").Replace(".", "_")
Write-Log -Message "Fetched and cleaned content from $Url" -Level "INFO"
[FetchResult]::new($name, $Url, $cleanedContent)
}

function Invoke-FetchAllPages {
$totalPages = @($script:config.pages).Count
$index = 0

$script:config.pages | ForEach-Object {
$index++
$url = $_.url
$name = $_.name

Write-Progress -Activity "Fetching pages" -Status "[$index/$totalPages] $name" -PercentComplete (($index / [math]::Max($totalPages, 1)) * 100)
Write-Log -Message "Fetching [$index/$totalPages]: $name ($url)" -Level "INFO"

try {
$response = Get-Data -Url $url
$htmlContent = Get-HtmlContent -Response $response
$cleanedContent = Remove-ExtraContent -HtmlContent $htmlContent
[FetchResult]::new($name, $url, $cleanedContent)
Write-Log -Message "Successfully fetched and cleaned content for $name ($url)" -Level "INFO"
}
catch {
Write-Log -Message "An error occurred in Invoke-FetchAllPages for '$name' ($url): $_" -Level "ERROR"
throw "An error occurred in Invoke-FetchAllPages for '$name' ($url): $_"
}
}
Write-Progress -Activity "Fetching pages" -Completed
}

class FetchResult {
[string]$Name
[string]$Url
[string]$Content

FetchResult([string]$Name, [string]$Url, [string]$Content) {
$this.Name = $Name
$this.Url = $Url
$this.Content = $Content
}
}