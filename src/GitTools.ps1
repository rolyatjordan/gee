# Interactive Git workflow commands.
#
# Get-GitStatus is intentionally not redefined here. gee exposes that command
# as its status object API, so Show-GitStatus provides the fetch-and-display
# workflow command instead.

function Test-InGitRepo {
    [OutputType([bool])]
    param()

    git rev-parse --is-inside-work-tree 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}

function Get-GitToolsHelp {
<#
.SYNOPSIS
Shows the gee workflow commands and their aliases.
#>
    $commands = $script:GitToolsCommandNames |
        ForEach-Object { Get-Command $_ -CommandType Function -ErrorAction SilentlyContinue } |
        Sort-Object Name

    $commands | ForEach-Object {
        $help = Get-Help -Name $_.Name -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Command = $_.Name
            Alias = ($script:GitToolsAliases.GetEnumerator() |
                Where-Object Value -eq $_.Name |
                ForEach-Object Key) -join ', '
            Description = if ($help -and $help.Synopsis) { $help.Synopsis.Trim() } else { 'No description available.' }
        }
    } | Format-Table -AutoSize
}

function Show-GitStatus {
<#
.SYNOPSIS
Fetches from remotes and displays the current Git status.
#>
    if (-not (Test-InGitRepo)) {
        Write-Error 'Not inside a Git repository.'
        return
    }

    Write-Host 'Fetching latest changes...' -ForegroundColor Cyan
    git fetch
    if ($LASTEXITCODE -ne 0) { return }

    Write-Host "`nCurrent status:" -ForegroundColor Yellow
    git status
}

function Switch-GitTrunk {
<#
.SYNOPSIS
Switches to trunk or main and pulls its latest changes.
#>
    if (-not (Test-InGitRepo)) {
        Write-Error 'Not inside a Git repository.'
        return
    }

    $branch = @('trunk', 'main') |
        Where-Object { git show-ref --verify --quiet "refs/heads/$_"; $LASTEXITCODE -eq 0 } |
        Select-Object -First 1

    if (-not $branch) {
        Write-Error 'No local trunk or main branch found.'
        return
    }

    git switch $branch
    if ($LASTEXITCODE -eq 0) { git pull }
}

function Set-GitLocationRoot {
<#
.SYNOPSIS
Changes the current location to the repository root.
#>
    if (-not (Test-InGitRepo)) {
        Write-Error 'Not inside a Git repository.'
        return
    }

    Set-Location (git rev-parse --show-toplevel)
}

function New-GitBranch {
<#
.SYNOPSIS
Creates and switches to a new branch.
#>
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name)
    git switch -c $Name
}

function Switch-GitBranch {
<#
.SYNOPSIS
Switches to an existing branch.
#>
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name)
    git switch $Name
}

function New-GitCommit {
<#
.SYNOPSIS
Creates a commit with the supplied message.
#>
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message)
    git commit -m $Message
}

function Remove-GitStaleBranch {
<#
.SYNOPSIS
Deletes local branches whose origin tracking branch no longer exists.
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param()

    if (-not (Test-InGitRepo)) {
        Write-Error 'Not inside a Git repository.'
        return
    }

    git fetch --prune
    if ($LASTEXITCODE -ne 0) { return }

    $currentBranch = git branch --show-current
    $staleBranches = git for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads |
        ForEach-Object {
            $parts = $_ -split ' ', 2
            if ($parts.Count -eq 2 -and $parts[1] -like 'origin/*' -and
                $parts[0] -ne $currentBranch -and $parts[0] -notin @('trunk', 'main')) {
                $remoteRef = "refs/remotes/$($parts[1])"
                git show-ref --verify --quiet $remoteRef
                if ($LASTEXITCODE -ne 0) { $parts[0] }
            }
        }

    foreach ($branch in $staleBranches) {
        if ($PSCmdlet.ShouldProcess($branch, 'Delete local stale branch')) {
            git branch -d $branch
        }
    }
}

function Sync-GitBranch {
<#
.SYNOPSIS
Pulls the current branch and then pushes local commits.

.PARAMETER DryRun
Shows the Git commands that would be run without changing the repository.
#>
    param([switch]$DryRun)

    if (-not (Test-InGitRepo)) {
        Write-Error 'Not inside a Git repository.'
        return
    }

    $branch = git branch --show-current
    if (-not $branch) {
        Write-Error 'Cannot sync a detached HEAD.'
        return
    }

    $upstream = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
    if ($DryRun) {
        Write-Host "Current branch: $branch" -ForegroundColor Yellow
        if ($upstream) {
            Write-Host "Upstream: $upstream" -ForegroundColor Yellow
            Write-Host "Ahead/Behind: $(git rev-list --left-right --count 'HEAD...@{u}')"
            Write-Host 'Would run: git pull'
            Write-Host 'Would run: git push'
        }
        else {
            Write-Host 'No upstream set.' -ForegroundColor Yellow
            Write-Host "Would run: git push --set-upstream origin $branch"
        }
        return
    }

    if ($upstream) {
        Write-Host 'Pulling changes...' -ForegroundColor Cyan
        git pull
        if ($LASTEXITCODE -ne 0) { return }

        Write-Host "`nPushing your changes..." -ForegroundColor Green
        git push
    }
    else {
        Write-Host "Pushing $branch and setting its upstream..." -ForegroundColor Green
        git push --set-upstream origin $branch
    }
}

function Remove-GitAliasCruft {
<#
.SYNOPSIS
Removes junk 'test-<GUID>' aliases that some tools leave in your global git config.

.DESCRIPTION
Certain tools probe git installations by writing 'alias.test-<GUID> config' entries to
~/.gitconfig and failing to clean up. This cmdlet removes matching aliases from the
global scope. The pattern defaults to $GitTabSettings.ExcludeAliasPattern.

.PARAMETER Pattern
Regex applied to alias names. Anything matching is removed.
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$Pattern = $global:GitTabSettings.ExcludeAliasPattern
    )

    if (-not $Pattern) {
        Write-Error 'No pattern provided and $GitTabSettings.ExcludeAliasPattern is empty.'
        return
    }

    $cruft = git config --global --get-regexp '^alias\.' |
        ForEach-Object {
            if ($_ -match '^alias\.(?<name>\S+) ') {
                if ($Matches['name'] -match $Pattern) { $Matches['name'] }
            }
        }

    if (-not $cruft) {
        Write-Host 'No matching alias entries found in global git config.' -ForegroundColor Green
        return
    }

    foreach ($name in $cruft) {
        if ($PSCmdlet.ShouldProcess("alias.$name (global)", 'Unset git alias')) {
            git config --global --unset-all "alias.$name"
        }
    }
}

$GitBranchCompleter = {
    param($commandName, $parameterName, $wordToComplete)

    if (-not (Test-InGitRepo)) { return }

    git branch -a 2>$null |
        ForEach-Object { $_.Trim() -replace '^\*?\s*', '' } |
        Where-Object { $_ -and $_ -notmatch '^remotes/origin/HEAD\s*->' } |
        ForEach-Object { $_ -replace '^remotes/origin/', '' } |
        Where-Object { $_ -and $_ -notin @('origin', 'HEAD') -and $_ -like "$wordToComplete*" } |
        Sort-Object -Unique |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

Register-ArgumentCompleter -CommandName Switch-GitBranch -ParameterName Name -ScriptBlock $GitBranchCompleter

function Set-GeeAliases {
<#
.SYNOPSIS
Allows customizing the command aliases for gee tools.

.PARAMETER Prefix
The prefix to apply to the alias names (default: 'g-'). Set to an empty string for no prefix.

.PARAMETER CustomAliases
An optional hashtable to completely override the default tool names to commands mapping.
#>
    [CmdletBinding()]
    param(
        [string]$Prefix = 'g-',
        [hashtable]$CustomAliases
    )

    if ((Test-Path Variable:script:GitToolsAliases) -and $script:GitToolsAliases) {
        foreach ($alias in $script:GitToolsAliases.Keys) {
            Remove-Item "Alias:\$alias" -ErrorAction SilentlyContinue
        }
    }

    $script:GitToolsAliases = [ordered]@{}

    if ($PSBoundParameters.ContainsKey('CustomAliases')) {
        foreach ($entry in $CustomAliases.GetEnumerator()) {
            $script:GitToolsAliases[$entry.Key] = $entry.Value
        }
    }
    else {
        $defaultAliases = [ordered]@{
            'help' = 'Get-GitToolsHelp'
            'status' = 'Show-GitStatus'
            'trunk' = 'Switch-GitTrunk'
            'root' = 'Set-GitLocationRoot'
            'new' = 'New-GitBranch'
            'switch' = 'Switch-GitBranch'
            'commit' = 'New-GitCommit'
            'prune' = 'Remove-GitStaleBranch'
            'sync' = 'Sync-GitBranch'
            'clean-aliases' = 'Remove-GitAliasCruft'
        }
        foreach ($entry in $defaultAliases.GetEnumerator()) {
            $aliasName = "$Prefix$($entry.Key)"
            $script:GitToolsAliases[$aliasName] = $entry.Value
        }
    }

    $scope = if ($MyInvocation.CommandOrigin -eq 'Internal') { 'Script' } else { 'Global' }
    
    foreach ($alias in $script:GitToolsAliases.GetEnumerator()) {
        Set-Alias -Name $alias.Key -Value $alias.Value -Scope $scope
    }
}

$script:GitToolsCommandNames = @(
    'Get-GitToolsHelp', 'Show-GitStatus', 'Switch-GitTrunk', 'Set-GitLocationRoot',
    'New-GitBranch', 'Switch-GitBranch', 'New-GitCommit', 'Remove-GitStaleBranch', 'Sync-GitBranch',
    'Remove-GitAliasCruft', 'Set-GeeAliases'
)

$initialPrefix = if (Test-Path Variable:global:GeeAliasPrefix) { $global:GeeAliasPrefix } else { 'g-' }
Set-GeeAliases -Prefix $initialPrefix
