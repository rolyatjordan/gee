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

function Test-GitBranchMerged {
<#
.SYNOPSIS
Tests whether a branch's changes are already present in a target ref, including
work that landed via a squash merge (which rewrites SHAs and defeats a plain
ancestry check).
#>
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$Branch,
        [Parameter(Mandatory)][string]$Target
    )

    # Fast path: an ordinary (non-squash) merge leaves the branch tip reachable
    # from the target, so a straight ancestry test settles it.
    git merge-base --is-ancestor $Branch $Target 2>$null
    if ($LASTEXITCODE -eq 0) { return $true }

    # Squash path: rebuild the branch's combined diff as a throwaway commit off
    # the merge-base, then ask 'git cherry' whether that patch already exists in
    # the target. A leading '-' means the equivalent change is present, i.e. the
    # branch was squash-merged. The synthetic commit is dangling (no ref) and
    # gets garbage-collected; it never touches the repo state.
    $base = git merge-base $Target $Branch 2>$null
    if (-not $base) { return $false }

    $tree = git rev-parse "$Branch^{tree}" 2>$null
    if (-not $tree) { return $false }

    $synthetic = git commit-tree $tree -p $base -m _ 2>$null
    if (-not $synthetic) { return $false }

    $cherry = git cherry $Target $synthetic 2>$null
    return [bool]($cherry | Where-Object { $_ -match '^-' })
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

.DESCRIPTION
Fetches with --prune, then finds local branches whose upstream has been deleted
on origin. A branch whose changes are already in origin/trunk - including work
that landed via a squash merge - is deleted automatically, because the commits
are safely preserved on trunk. A branch that is genuinely unmerged is left alone
unless -Force is given, so you never silently lose unpushed work.

.PARAMETER Force
Also delete stale branches that are NOT merged into origin/trunk. Without this,
unmerged branches are reported and skipped.
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param([switch]$Force)

    if (-not (Test-InGitRepo)) {
        Write-Error 'Not inside a Git repository.'
        return
    }

    git fetch --prune
    if ($LASTEXITCODE -ne 0) { return }

    $trunk = @('origin/trunk', 'origin/main') |
        Where-Object { git show-ref --verify --quiet "refs/remotes/$_"; $LASTEXITCODE -eq 0 } |
        Select-Object -First 1

    if (-not $trunk) {
        Write-Error 'No origin/trunk or origin/main remote branch found.'
        return
    }

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
        if (Test-GitBranchMerged -Branch $branch -Target $trunk) {
            # Verified in trunk (incl. squash) - -D is safe; -d would wrongly
            # refuse a squash-merged branch because its SHAs differ.
            if ($PSCmdlet.ShouldProcess($branch, "Delete merged stale branch (already in $trunk)")) {
                git branch -D $branch
            }
        }
        elseif ($Force) {
            if ($PSCmdlet.ShouldProcess($branch, "FORCE-DELETE unmerged stale branch (NOT in $trunk)")) {
                git branch -D $branch
            }
        }
        else {
            Write-Warning "Skipping '$branch': not merged into $trunk. Re-run with -Force to delete it (its commits are recoverable via 'git reflog' for ~90 days if you change your mind)."
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

function Get-GitHealth {
<#
.SYNOPSIS
Shows a holistic health view of the local repo relative to origin/trunk.

.DESCRIPTION
Lists every local branch with how many commits it is ahead of and behind
origin/trunk (or origin/main), its upstream tracking state, and when it was
last committed to. Branches with no commit within -StaleDays are flagged STALE,
and branches whose upstream has been deleted are flagged GONE. The header shows
the working-tree and stash state, and a closing summary calls out cleanup
opportunities (gone/stale branches and stashes) with the command to address
each. This is read-only; use g-prune to actually delete branches. Git resolves
paths from the repository root, so this reports on the whole repo no matter
where you are within it.

.PARAMETER StaleDays
Branches with no commit in this many days are flagged STALE. Default 30.

.PARAMETER SkipFetch
Report against already-fetched remote refs instead of running 'git fetch --prune' first.
#>
    [CmdletBinding()]
    param(
        [ValidateRange(1, [int]::MaxValue)][int]$StaleDays = 30,
        [switch]$SkipFetch
    )

    if (-not (Test-InGitRepo)) {
        Write-Error 'Not inside a Git repository.'
        return
    }

    if (-not $SkipFetch) {
        Write-Host 'Fetching latest changes...' -ForegroundColor Cyan
        git fetch --prune
        if ($LASTEXITCODE -ne 0) { return }
    }

    $trunk = @('origin/trunk', 'origin/main') |
        Where-Object { git show-ref --verify --quiet "refs/remotes/$_"; $LASTEXITCODE -eq 0 } |
        Select-Object -First 1

    if (-not $trunk) {
        Write-Error 'No origin/trunk or origin/main remote branch found.'
        return
    }

    $root = git rev-parse --show-toplevel
    $current = git branch --show-current
    $dirtyCount = @(git status --porcelain).Count
    $stashCount = @(git stash list).Count
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $staleSeconds = [long]$StaleDays * 86400

    Write-Host ''
    Write-Host "Repo:    $(Split-Path $root -Leaf)  ($root)" -ForegroundColor Yellow
    Write-Host "Trunk:   $trunk"
    Write-Host "Branch:  $(if ($current) { $current } else { '(detached HEAD)' })"
    if ($dirtyCount -gt 0) {
        Write-Host "Working: $dirtyCount uncommitted change(s)" -ForegroundColor Red
    }
    else {
        Write-Host 'Working: clean' -ForegroundColor Green
    }
    Write-Host "Stashes: $stashCount" -ForegroundColor $(if ($stashCount -gt 0) { 'DarkYellow' } else { 'Green' })
    Write-Host ''

    $format = '%(refname:short)|%(upstream:short)|%(upstream:track)|%(committerdate:unix)|%(committerdate:relative)'
    $trunkLocalNames = @('trunk', 'main')
    $staleCount = 0
    $goneMergedCount = 0
    $goneUnmergedCount = 0

    $rows = git for-each-ref --format=$format refs/heads |
        ForEach-Object {
            $f = $_ -split '\|', 5
            $branch = $f[0]
            $upstream = $f[1]
            $track = $f[2]
            $committed = [long]$f[3]
            $relative = $f[4]

            $counts = (git rev-list --left-right --count "$trunk...$branch").Trim() -split '\s+'
            $behind = [int]$counts[0]
            $ahead = [int]$counts[1]

            $isGone = $track -eq '[gone]'
            $upstreamStatus =
                if (-not $upstream) { '(none)' }
                elseif ($isGone) { 'gone' }
                elseif (-not $track) { 'up to date' }
                else { $track.Trim('[', ']') }

            # Skip the merged check for trunk/main itself (trivially "merged" into
            # its own remote) - it only muddies the output.
            $isMerged = ($branch -notin $trunkLocalNames) -and
                (Test-GitBranchMerged -Branch $branch -Target $trunk)

            $isStale = ($now - $committed) -gt $staleSeconds
            if ($isStale) { $staleCount++ }
            if ($isGone) {
                if ($isMerged) { $goneMergedCount++ } else { $goneUnmergedCount++ }
            }

            $flags = @()
            if ($isMerged) { $flags += 'MERGED' }
            if ($isStale) { $flags += 'STALE' }
            if ($isGone) { $flags += 'GONE' }

            [PSCustomObject]@{
                Branch     = if ($branch -eq $current) { "* $branch" } else { "  $branch" }
                Ahead      = $ahead
                Behind     = $behind
                Upstream   = $upstreamStatus
                LastCommit = $relative
                Flags      = $flags -join ' '
                SortKey    = $branch
            }
        }

    $rows |
        Sort-Object SortKey |
        Format-Table Branch, Ahead, Behind, Upstream, LastCommit, Flags -AutoSize

    Write-Host "Ahead/Behind are relative to $trunk. * marks the current branch." -ForegroundColor DarkGray

    Write-Host "MERGED includes squash-merges (change already in $trunk even though Ahead may be > 0)." -ForegroundColor DarkGray

    if ($goneMergedCount -gt 0 -or $goneUnmergedCount -gt 0 -or $staleCount -gt 0 -or $stashCount -gt 0) {
        Write-Host ''
        Write-Host 'Cleanup opportunities:' -ForegroundColor Cyan
        if ($goneMergedCount -gt 0) {
            Write-Host "  - $goneMergedCount merged branch(es) with a deleted upstream -> g-prune (safe: already in trunk)" -ForegroundColor Green
        }
        if ($goneUnmergedCount -gt 0) {
            Write-Host "  - $goneUnmergedCount UNMERGED branch(es) with a deleted upstream -> review, then g-prune -Force to delete" -ForegroundColor DarkYellow
        }
        if ($staleCount -gt 0) {
            Write-Host "  - $staleCount stale branch(es) with no commit in $StaleDays+ days -> review and g-switch/g-prune" -ForegroundColor DarkYellow
        }
        if ($stashCount -gt 0) {
            Write-Host "  - $stashCount stash(es) -> git stash list" -ForegroundColor DarkYellow
        }
    }
    else {
        Write-Host 'No cleanup needed - repo looks tidy.' -ForegroundColor Green
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
            'health' = 'Get-GitHealth'
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
    'Get-GitHealth', 'Remove-GitAliasCruft', 'Set-GeeAliases'
)

$initialPrefix = if (Test-Path Variable:global:GeeAliasPrefix) { $global:GeeAliasPrefix } else { 'g-' }
Set-GeeAliases -Prefix $initialPrefix
