<#
.SYNOPSIS
Builds the gee release zip from src/, optionally bumping the module version.

.DESCRIPTION
Packages the module files under src/ into a zip whose root contains gee.psd1 -
the layout the README install block expects (the archive is extracted straight
into ...\PowerShell\Modules\gee, so gee.psd1 must sit at the archive root, not
under a src/ folder). LICENSE.txt and NOTICE ride along at the archive root so
every distributed copy carries the attribution the MIT license requires.
Optionally rewrites ModuleVersion in the manifest. Always validates the manifest
with Test-ModuleManifest before packaging. Runs from the repo root regardless of
your current location.

.PARAMETER Version
New value for ModuleVersion in src/gee.psd1 (e.g. 1.1.1). Left unchanged if omitted.

.PARAMETER OutputPath
Where to write the zip. Defaults to gee.zip in the repo root.

.EXAMPLE
.\build.ps1 -Version 1.1.1
Bumps to 1.1.1, validates the manifest, and writes gee.zip.

.EXAMPLE
.\build.ps1
Packages the current manifest as-is (handy for a local smoke test).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Version,
    [string]$OutputPath = (Join-Path $PSScriptRoot 'gee.zip')
)

$ErrorActionPreference = 'Stop'

$manifestPath = Join-Path $PSScriptRoot 'src\gee.psd1'
$sourceGlob = Join-Path $PSScriptRoot 'src\*'

# MIT requires the copyright and permission notice travel with every copy, so a
# missing license file is a hard build failure rather than a silently thinner zip.
$licenseFiles = @('LICENSE.txt', 'NOTICE') | ForEach-Object {
    $path = Join-Path $PSScriptRoot $_
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required license file not found: $path"
    }
    $path
}

if ($Version) {
    $content = Get-Content -Path $manifestPath -Raw
    if ($content -notmatch "(?m)^(\s*ModuleVersion\s*=\s*)'[^']*'") {
        throw "Could not find a ModuleVersion entry in $manifestPath."
    }
    $content = $content -replace "(?m)^(\s*ModuleVersion\s*=\s*)'[^']*'", "`${1}'$Version'"
    Write-Host "ModuleVersion -> $Version" -ForegroundColor Cyan

    if ($PSCmdlet.ShouldProcess($manifestPath, 'Update manifest')) {
        # WriteAllText keeps UTF-8 (no BOM) and the existing line endings, so the
        # edit stays a minimal diff rather than reflowing the whole manifest the
        # way Update-ModuleManifest would (which also strips the file's comments).
        [System.IO.File]::WriteAllText($manifestPath, $content)
    }
}

$manifest = Test-ModuleManifest -Path $manifestPath
Write-Host "Manifest OK: gee $($manifest.Version)" -ForegroundColor Green

if ($PSCmdlet.ShouldProcess($OutputPath, 'Build release zip')) {
    Compress-Archive -Path (@($sourceGlob) + $licenseFiles) -DestinationPath $OutputPath -Force
    Write-Host "Built $OutputPath" -ForegroundColor Green
    Write-Host "Next: gh release create v$($manifest.Version) `"$OutputPath`" --title `"v$($manifest.Version)`"" -ForegroundColor DarkGray
}
