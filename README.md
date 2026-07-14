# gee

`gee` is a PowerShell module that adds Git tab completion and interactive workflow commands to your shell. It does **not** replace or hijack your prompt — bring your own (e.g. [Oh My Posh](https://ohmyposh.dev/)).

> Forked from [dahlbyk/posh-git](https://github.com/dahlbyk/posh-git) by Keith Dahlby, Keith Hill, and contributors. See [Credits and Upstream](#credits-and-upstream) at the bottom.

## Workflow Shortcuts

Import the module and run `Get-GitToolsHelp` (or `g-help`) to see the shortcut list at any time.

| Alias             | Command                | Purpose                                                                    |
| ----------------- | ---------------------- | -------------------------------------------------------------------------- |
| `g-help`          | `Get-GitToolsHelp`     | Show the shortcut list                                                     |
| `g-status`        | `Show-GitStatus`       | Fetch and display `git status`                                             |
| `g-trunk`         | `Switch-GitTrunk`      | Switch to `trunk` (or `main`) and pull                                     |
| `g-root`          | `Set-GitLocationRoot`  | Change to the repository root                                              |
| `g-new`           | `New-GitBranch`        | Create a branch                                                            |
| `g-switch`        | `Switch-GitBranch`     | Switch to a branch (with tab-complete)                                     |
| `g-commit`        | `New-GitCommit`        | Commit with a message                                                      |
| `g-prune`         | `Remove-GitStaleBranch`| Delete stale branches (upstream gone); auto-cleans merged ones incl. squash-merges, `-Force` for unmerged |
| `g-sync`          | `Sync-GitBranch`       | Pull then push, or set an upstream on first push                           |
| `g-health`        | `Get-GitHealth`        | Repo health: each branch's ahead/behind vs `origin/trunk`, stash count, stale/gone flags, cleanup tips |
| `g-clean-aliases` | `Remove-GitAliasCruft` | Remove `alias.test-<GUID>` probes some tools leave in your global gitconfig |

`Get-GitStatus` remains available as the structured status data API for anyone who wants to consume git repo state programmatically.

### Customizing Aliases

You can easily change the default `g-` prefix or entirely remap the aliases for the workflow cmdlets using one of two methods:

**1. Global Profile Setting (Recommended)**  
Add a `$global:GeeAliasPrefix` variable to your PowerShell profile *before* importing the `gee` module. The module will automatically use this prefix on load.
```powershell
$global:GeeAliasPrefix = 'git-'
# Now shortcuts will be git-switch, git-trunk, etc.
```

**2. `Set-GeeAliases` Cmdlet**  
You can dynamically change the aliases at any time using `Set-GeeAliases`. To change the prefix:
```powershell
Set-GeeAliases -Prefix 'my-'
```
To completely map your own custom alias names to the cmdlets, pass a hashtable:
```powershell
Set-GeeAliases -CustomAliases @{
    'my-help'   = 'Get-GitToolsHelp'
    'my-status' = 'Show-GitStatus'
    'my-trunk'  = 'Switch-GitTrunk'
    'my-root'   = 'Set-GitLocationRoot'
    'my-new'    = 'New-GitBranch'
    'my-switch' = 'Switch-GitBranch'
    'my-commit' = 'New-GitCommit'
    'my-prune'  = 'Remove-GitStaleBranch'
    'my-sync'   = 'Sync-GitBranch'
    'my-health' = 'Get-GitHealth'
    'my-clean'  = 'Remove-GitAliasCruft'
}
```
## Overview

`gee` is a PowerShell module that integrates Git and PowerShell. It provides:

* **Tab Completion** — for git commands, subcommands, parameters, branch names, remotes, and paths.
* **Workflow Shortcuts** — high-level interactive helper cmdlets to speed up daily Git operations.
* **Status data API** — `Get-GitStatus` returns a structured object that external prompt engines (Oh My Posh, Starship, custom `$function:prompt`) can consume without depending on this module doing any rendering.

### Tab Completion Example

Type `git ch` and press <kbd>tab</kbd> — PowerShell offers `checkout`, `cherry-pick`, etc. Tab completion also works for branch names and remotes: `git pull or<tab> tr<tab>` expands to `git pull origin trunk`.

## Design Choices

* **Slim by design** — the built-in prompt renderer from upstream posh-git has been removed. If you use Oh My Posh, Starship, or any other prompt engine, there's no conflict and no wasted code.
* **Modern tab-completion path on all supported PowerShell versions** — `Register-ArgumentCompleter -Native` is used on Windows PowerShell 5.x as well as PowerShell 7+.
* **Modern default branch names** — `trunk` and `main` instead of `master`.
* **Alias-cruft defenses** — automatically hides `test-<GUID>` probe aliases from tab completion and provides `g-clean-aliases` to remove them from your global gitconfig.

## Installation

### Prerequisites

1. Windows PowerShell 5.x or PowerShell 7+ (`pwsh`).
2. On Windows, execution policy set to `RemoteSigned` or `Unrestricted`. Check with `Get-ExecutionPolicy`; change with `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`.
3. `git` on your PATH. Check with `git --version`.

### Install from a GitHub Release (recommended)

Download the latest release zip and drop it into your PowerShell modules directory:

```powershell
$zip = Join-Path $env:TEMP 'gee.zip'
$dest = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules\gee'
Invoke-WebRequest 'https://github.com/rolyatjordan/gee/releases/latest/download/gee.zip' -OutFile $zip
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Expand-Archive $zip -DestinationPath $dest -Force
Remove-Item $zip
Import-Module gee
Add-GeeToProfile
```

On Windows PowerShell 5.x the modules directory is `Documents\WindowsPowerShell\Modules\gee` — swap `PowerShell` for `WindowsPowerShell` in the `$dest` path above.

To upgrade later, re-run the same block — it overwrites in place.

### Manual install (for local development)

```powershell
Import-Module .\src\gee.psd1
Add-GeeToProfile
```

The `Add-GeeToProfile` cmdlet writes `Import-Module gee` into your current-user profile so `gee` loads in every new shell.

Use `-AllHosts` to add it to `$profile.CurrentUserAllHosts` (available across console, ISE, VS Code, etc.), or `-AllUsers -AllHosts` to install for every user on the machine (requires elevation).

### Building a release (maintainers)

`build.ps1` at the repo root packages the module for a GitHub Release. It rewrites the version, validates the manifest, and produces `gee.zip` with `gee.psd1` at the archive root (the layout the install block above expects):

```powershell
.\build.ps1 -Version 1.1.1
```

Then attach the zip to a release — the asset **must** be named `gee.zip`, because the install URL points at `releases/latest/download/gee.zip`:

```powershell
gh release create v1.1.1 .\gee.zip --title "v1.1.1" --notes "..."
```

Run `.\build.ps1` with no arguments to package the current manifest as-is (a local smoke test), or add `-WhatIf` to preview without writing anything. The built `gee.zip` is git-ignored. Tests are run by CI (Pester) on every push and PR.

## Using gee

### Tab completion

Once imported, `git <Tab>` offers subcommands, `git checkout <Tab>` offers branch names, and so on. This completer is registered automatically when the module loads — no profile entry is required beyond importing `gee`.

For a nicer experience on Windows PowerShell 5.x, bind Tab to menu-style completion:

```powershell
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
```

This is a PSReadLine key binding, not part of `gee` — the module does **not** set it for you, and neither does `Add-GeeToProfile`. Run on its own it lasts only for the current session; to make it permanent, add the line to your PowerShell profile (`notepad $PROFILE`).

### Consuming git status from your prompt engine

Because `gee` ships no built-in prompt, integrate `Get-GitStatus` into your own prompt function or theme. Example:

```powershell
function prompt {
    $status = Get-GitStatus
    if ($status) {
        Write-Host "[$($status.Branch)]" -NoNewline -ForegroundColor Cyan
    }
    "PS $($ExecutionContext.SessionState.Path.CurrentLocation)> "
}
```

Oh My Posh users: the `git` segment already reads from `git` directly and does not need `Get-GitStatus`.

### Customization variables

* `$GitTabSettings` — tab completion behavior. Notable properties:
  * `AllCommands` — when `$true`, tab completes every subcommand from `git help --all` instead of the curated shortlist. Default `$false`.
  * `ExcludeAliasPattern` — regex applied to alias names in tab completion; matches are hidden. Defaults to `^test-[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$` (probe-and-forget test aliases). Set to `''` to disable filtering.
* `$GeeStatusSettings` — tunes `Get-GitStatus` data-gathering behavior. Notable properties: `EnableFileStatus`, `EnableStashStatus`, `RepositoriesInWhichToDisableFileStatus`, `UntrackedFilesMode`, `DescribeStyle`.

Note on performance: displaying file status in a very large repo can be slow. Rather than turning it off globally (`$GeeStatusSettings.EnableFileStatus = $false`), add the repo path to `$GeeStatusSettings.RepositoriesInWhichToDisableFileStatus`.

## Credits and Upstream

`gee` is a fork of the excellent [dahlbyk/posh-git](https://github.com/dahlbyk/posh-git). The tab-completion engine, `Get-GitStatus`, argument-expansion tables, and much of the module scaffolding are all upstream work. `gee` strips out the built-in prompt renderer, TortoiseGit integration, and VSTS/TFS support, then adds workflow shortcut cmdlets — but the core is theirs.

Enormous thanks to the original creators and contributors:

- **Keith Dahlby** — http://solutionizing.net/
- **Keith Hill**
- **Mark Embling** — http://www.markembling.info/
- **Jeremy Skinner** — http://www.jeremyskinner.co.uk/
- And all [upstream contributors](https://github.com/dahlbyk/posh-git/graphs/contributors).

Original project: https://github.com/dahlbyk/posh-git
Licensed under the MIT License (see [LICENSE.txt](LICENSE.txt) and [NOTICE](NOTICE) for a consolidated attribution statement).
