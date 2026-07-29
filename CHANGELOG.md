# gee Release History

`gee` is a fork of [posh-git](https://github.com/dahlbyk/posh-git). Function,
module, and setting names have changed in the fork — see [README.md](README.md)
for the current source of truth.

## 0.2.1 - 2026-07-29

### Added

- `CompatiblePSEditions = @('Core', 'Desktop')` in the manifest, so the module advertises PowerShell 7 support explicitly.
- `build.ps1` now packages `LICENSE.txt` and `NOTICE` at the archive root, so every distributed copy carries the attribution the MIT license requires. A missing license file fails the build rather than producing a silently thinner zip.
- README now states the requirements up front: Git 2.15+, and either Windows PowerShell 5.1 or PowerShell 7+ (`pwsh`, required on macOS/Linux).

### Fixed

- `Get-PSModulePath` split `$Env:PSModulePath` on a hard-coded `;`, so module-path discovery found nothing on macOS/Linux. It now splits on `[System.IO.Path]::PathSeparator`.
- `install.ps1` built its manifest path with hard-coded backslashes; it now uses `Join-Path`.
- `LICENSE.txt` now asserts the fork's copyright alongside the upstream posh-git notice, which it retains.
- Corrected the copyright year in `NOTICE` (2024 -> 2026) and the upstream year range in the manifest (`2010-2021` -> `2010-2018`, matching `LICENSE.txt`).
- `LicenseUri` in the manifest pointed at upstream posh-git's license; it now points at this repository's `LICENSE.txt`.

### Changed

- Raised `PowerShellVersion` from `5.0` to `5.1` — the floor the module actually supports.
- Both CI workflows now trigger on `trunk` rather than `master`.
- Removed editor configuration and funding metadata inherited from upstream posh-git.

## 0.2.0 - 2026-07-14

### Added

- `g-health` (`Get-GitHealth`) — a holistic repo health view against `origin/trunk`: per-branch ahead/behind counts, upstream state, working-tree and stash summary, `STALE`/`GONE`/`MERGED` flags, and a cleanup-opportunities summary. Runs from anywhere in the working tree.
- `g-prune` (`Remove-GitStaleBranch`) now understands squash merges: branches whose changes are already in `origin/trunk` (including squash-merged work under a rewritten SHA) are detected and removed safely, while genuinely unmerged branches are skipped unless `-Force` is given.
- `build.ps1` — packages the module into a release `gee.zip` with `gee.psd1` at the archive root, optionally bumping the manifest version.

### Changed

- Re-based module versioning to `0.x`.
- Dropped the inherited posh-git `Prerelease = 'alpha'` manifest tag (upstream release-channel machinery this fork does not use).

## 0.1.0 - 2026-07-12

- Renamed module from `posh-git` to `gee`.
- Removed the built-in prompt renderer (`GitPrompt.ps1`, ANSI helpers, `WindowTitle.ps1`) — bring your own prompt engine.
- Renamed `Add-PoshGitToProfile` → `Add-GeeToProfile`, `Remove-PoshGitFromProfile` → `Remove-GeeFromProfile`.
- Renamed `PoshGitPromptSettings` class → `GeeStatusSettings` (and `$GitPromptSettings` global → `$GeeStatusSettings`).
- Renamed env var `POSHGIT_ENABLE_STRICTMODE` → `GEE_ENABLE_STRICTMODE`.
- Added workflow shortcuts: `g-status`, `g-trunk`, `g-root`, `g-new`, `g-switch`, `g-commit`, `g-prune`, `g-sync`, `g-clean-aliases`.
- Added `Remove-GitAliasCruft` cmdlet and a completion filter for `test-<GUID>` probe aliases.
- Fixed test-suite leaks: prompt hijack no longer persists after `Invoke-Pester`; the strict-mode env var no longer leaks; test-created global git aliases are cleaned up.

---

## Upstream

Forked from [posh-git](https://github.com/dahlbyk/posh-git) 1.1.0 (March 31, 2022).
For the full pre-fork release history, see the upstream changelog:
<https://github.com/dahlbyk/posh-git/blob/master/CHANGELOG.md>.
