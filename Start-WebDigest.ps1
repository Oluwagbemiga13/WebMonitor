Import-Module ./modules/Config.psm1 -Verbose -Force
Import-Module ./modules/Fetcher.psm1 -Verbose -Force

try {
    Import-Config
    $Config.pages | ForEach-Object {
        Write-Output "Page Name: $($_.name)"
        Write-Output "Page URL: $($_.url)"
    }
} catch {
    Write-Error "An error occurred: $_"
}


$testContent = Get-Content "D:\Git\ps-page-digester\testPage.txt" -Raw
try {
    Write-Output "Original Content:"
    Write-Output $testContent
    $CleanedContent = Remove-ExtraContent -HtmlContent $testContent
    Write-Output "Cleaned Content:"
    Write-Output $CleanedContent
} catch {
    Write-Error "An error occurred while cleaning content: $_"
}
