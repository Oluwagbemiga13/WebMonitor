Import-Module ./modules/Config.psm1 -Verbose -Force

# Fetches data from the specified URL and returns the response object.
function Get-Data {
    param (
        [string]$Url
    )
    Write-Output "Fetching data from $Url"
    $Response = Invoke-WebRequest -Uri $Url
    if ($Response.StatusCode -ne 200) {
        throw "Failed to fetch data from $Url. Status code: $($Response.StatusCode)"
    }
    return $response
}

# Converts the response content to HTML format.
function ConvertTo-Html {
    param (
        [Response]$Response
    )
    Write-Output "Converting response to HTML format"
    $HtmlContent = $Response.Content
    if (($null -ne $HtmlContent) -and ($HtmlContent -ne "")) {
        return $HtmlContent
    }
    else {
        throw "Failed to convert response to HTML. Content is empty."
    }
}

# Removes scripts, styles, and comments from the HTML content to clean it up.
function Remove-ExtraContent {
    param (
        [string]$HtmlContent
    )
    $Regexes = $Config.common.regexesForRemoval

    foreach ($Regex in $Regexes) {
        $multilineOption = [System.Text.RegularExpressions.RegexOptions]::None
        if($Regex.multiline) {
            $multilineOption =[System.Text.RegularExpressions.RegexOptions]::Multiline
        }
        $HtmlContent = [regex]::Replace($HtmlContent, $Regex.pattern, $Regex.replacement, $multilineOption)
    }

    if (($null -ne $HtmlContent) -and ($HtmlContent -ne "")) {
        return $HtmlContent
    }
    else {
        throw "Failed to format HTML content. Content is empty after formatting."
    }

}

function  Invoke-Fetcher {
    param (
        [string]$Url
    )

    $Response = Get-Data -Url $Url
    $HtmlContent = ConvertTo-Html -Response $Response
    $CleanedContent = Remove-ExtraContent -HtmlContent $HtmlContent
    return $CleanedContent
}

function  Invoke-Fetcher {
    $Config.pages | ForEach-Object {
        $Url = $_.url

    try {
        $Response = Get-Data -Url $Url
        $HtmlContent = ConvertTo-Html -Response $Response
        $CleanedContent = Remove-ExtraContent -HtmlContent $HtmlContent
        return $CleanedContent
    } catch {
        throw "An error occurred in Invoke-Fetcher: $_"
    }
}
}