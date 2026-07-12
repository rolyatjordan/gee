# Import the gee module, first via installed gee module.
# If the module isn't installed, then attempt to load it from the cloned Git repo.
$geeModule = Get-Module gee -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
if ($geeModule) {
    $geeModule | Import-Module
}
elseif (Test-Path -LiteralPath ($modulePath = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) (Join-Path src 'gee.psd1'))) {
    Import-Module $modulePath
}
else {
    throw "Failed to import gee."
}

if ($args[0] -ne 'choco') {
    Write-Warning "gee's profile.example.ps1 will be removed in a future version."
    Write-Warning "Consider using `Add-GeeToProfile` instead."
}
