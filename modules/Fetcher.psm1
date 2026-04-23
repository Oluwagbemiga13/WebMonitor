using module ./Config.psm1
using module ./Logger.psm1

$script:config = (Import-Config).fetcher


# Fetches data from the specified URL and returns the response object.
function Get-Data {
    <#
    .SYNOPSIS
    Retrieves the HTTP response from a URL.

    .DESCRIPTION
    Performs an HTTP GET request using Invoke-WebRequest with a configurable
    timeout (.timeoutSec). Throws if the status code is not 200.

    .PARAMETER Url
    The URL to request.

    .OUTPUTS
    Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject

    .EXAMPLE
    $response = Get-Data -Url "https://example.com"
    #>
param (
[string]$Url
)
$timeoutSec = if ($script:config.timeoutSec) {
[int]$script:config.timeoutSec
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
    <#
    .SYNOPSIS
    Extracts the raw HTML/text content from a web response.

    .PARAMETER Response
    The response object returned by Get-Data or Invoke-WebRequest.

    .OUTPUTS
    System.String

    .EXAMPLE
    $html = Get-HtmlContent -Response $response
    #>
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
    <#
    .SYNOPSIS
    Cleans fetched content using configured regex replacements.

    .DESCRIPTION
    Applies each entry in .regexesForRemoval to strip noise such as
    scripts, styles, and comments before keyword matching or hashing.

    .PARAMETER HtmlContent
    Raw page content to clean.

    .OUTPUTS
    System.String

    .EXAMPLE
    $clean = Remove-ExtraContent -HtmlContent $html
    #>
param (
[string]$HtmlContent
)
$regexes = $script:config.regexesForRemoval

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
    <#
    .SYNOPSIS
    Fetches and cleans a single page by URL.

    .DESCRIPTION
    Executes the full fetch pipeline (Get-Data, Get-HtmlContent,
    Remove-ExtraContent) and returns a FetchResult. The page name is
    derived from the URL by stripping the scheme and replacing slashes
    and dots with underscores. To use a name from configuration, use
    Invoke-FetchAllPages instead.

    .PARAMETER Url
    URL of the page to fetch.

    .OUTPUTS
    FetchResult

    .EXAMPLE
    $page = Invoke-FetchPage -Url "https://example.com/status"
    #>
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
    <#
    .SYNOPSIS
    Fetches and cleans all pages defined in configuration.

    .DESCRIPTION
    Iterates over config.pages, reports progress, and returns one
    FetchResult per configured page. Throws on fetch failure.

    .OUTPUTS
    FetchResult[]

    .EXAMPLE
    $results = Invoke-FetchAllPages
    #>
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

# Represents the result of a single page fetch, containing the page name, source URL, and cleaned content.
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