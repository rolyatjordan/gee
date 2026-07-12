# Define these variables since they are not defined in WinPS 5.x
if ($PSVersionTable.PSVersion.Major -lt 6) {
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $IsWindows = $true
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $IsLinux = $false
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $IsMacOS = $false
}

$modulePath = Convert-Path $PSScriptRoot\..\src
$moduleManifestPath = "$modulePath\gee.psd1"

[System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
$csi = [char]0x1b + "["

[System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
$expectedEncoding = if ($PSVersionTable.PSVersion.Major -le 5) { "utf8" } else { "ascii" }

if (!(Get-Variable -Name gitbin -Scope global -ErrorAction SilentlyContinue)) {
    if (($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows) {
        # On Windows, we can access the git binary via git.exe
        $global:gitbin = Get-Command -Name git -CommandType Application -TotalCount 1
    }
    else {
        # On Linux/macOS, we can access the git binary via its path /usr/bin/git
        $global:gitbin = (Get-Command -Name git -CommandType Application -TotalCount 1).Path
    }
}

# We need this or the Git mocks don't work
# This must global in order to be accessible in gee module scope
function global:git {
    $OFS = ' '
    $cmdline = "$args"
    # Write-Warning "in global git func with: $cmdline"
    switch ($cmdline) {
        '--version' { 'git version 2.16.2.windows.1' }
        'help' { Get-Content $PSScriptRoot\git-help.txt }
        default {
            $res = Invoke-Expression "&$gitbin $cmdline"
            $res
        }
    }
}

# This must global in order to be accessible in gee module scope
function global:Convert-NativeLineEnding([string]$content, [switch]$SplitLines) {
    $tmp = $content -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
    if ($SplitLines) {
        $tmp
    }
    else {
        $content = $tmp -join [System.Environment]::NewLine
        $content
    }
}

function GetHomePath() {
    if ($GitPromptSettings.DefaultPromptAbbreviateHomeDirectory) {
        "~"
    }
    else {
        $Home
    }
}

function GetHomeRelPath([string]$Path) {
    $separator = [System.IO.Path]::DirectorySeparatorChar
    if (!("$Path$separator".StartsWith("$Home$separator"))) {
        # Path not under $Home
        return $Path
    }

    if ($GitPromptSettings.DefaultPromptAbbreviateHomeDirectory) {
        "~$($Path.Substring($Home.Length))"
    }
    else {
        $Path
    }
}

function GetGitRelPath([string]$Path) {
    $gitPath = Get-GitDirectory
    if (!$gitPath) {
        throw "GetGitRelPath Should -be called inside a git repository"
    }
    # Up one level from `.git`
    $gitPath = Split-Path $gitPath -Parent

    $separator = [System.IO.Path]::DirectorySeparatorChar
    if (!"$Path$separator".StartsWith("$gitPath$separator")) {
        # Path not under $gitPath
        return $Path
    }

    if ($GitPromptSettings.DefaultPromptAbbreviateGitDirectory) {
        $gitName = Split-Path $gitPath -Leaf
        $relPath = if ($Path -eq $gitPath) { "" } else { $Path.Substring($gitPath.Length + 1) }
        "$gitName`:$relPath"
    }
    else {
        # Otherwise, honor Home path abbreviation
        GetHomeRelPath $Path
    }
}

function GetMacOSAdjustedTempPath($Path) {
    if (($PSVersionTable.PSVersion.Major -ge 6) -and $IsMacOS) {
        # Mac OS's temp folder has a symlink in its path - /var is linked to /private/var
        return "/private${Path}"
    }

    $Path
}

function MakeNativePath([string]$Path) {
    $Path -replace '\\|/', [System.IO.Path]::DirectorySeparatorChar
}

function MakeGitPath([string]$Path) {
    $Path -replace '\\', '/'
}

function NewGitTempRepo([switch]$MakeInitialCommit) {
    Push-Location
    $temp = [System.IO.Path]::GetTempPath()
    $repoPath = Join-Path $temp ([IO.Path]::GetRandomFileName())
    
    # Try to initialize with trunk, otherwise fallback and rename
    &$gitbin init --initial-branch trunk $repoPath *>$null
    if ($LASTEXITCODE -ne 0) {
        &$gitbin init $repoPath *>$null
        Set-Location $repoPath
        &$gitbin branch -M trunk *>$null
    }
    Set-Location $repoPath

    if ($MakeInitialCommit) {
        &$gitbin config user.email "spaceman.spiff@appveyor.com"
        &$gitbin config user.name "Spaceman Spiff"
        'readme' | Out-File ./README.md -Encoding ascii
        &$gitbin add ./README.md *>$null
        &$gitbin commit -m "initial commit." *>$null
    }

    $repoPath
}

function RemoveGitTempRepo($RepoPath) {
    Pop-Location
    if ($repoPath -and (Test-Path $repoPath)) {
        Remove-Item $repoPath -Recurse -Force
    }
}

function ResetGitTempRepoWorkingDir($RepoPath, $Branch = 'trunk') {
    Set-Location $repoPath
    &$gitbin checkout -fq $Branch *>$null
    &$gitbin clean -xdfq *>$null
}

Remove-Module gee -Force *>$null

# For Pester testing, enable strict mode inside the gee module. The env var only
# matters at module-load time (gee.psm1 reads it once and calls Set-StrictMode).
# Unset it immediately after import so the flag doesn't leak into the caller's shell
# and force strict mode on subsequent (non-test) imports of the module.
$env:GEE_ENABLE_STRICTMODE = 1

[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssigments', '')]
$module = Import-Module $moduleManifestPath -ArgumentList $false, $false -Force -PassThru

Remove-Item Env:GEE_ENABLE_STRICTMODE -ErrorAction SilentlyContinue
