# gee Release History

`gee` is a fork of [posh-git](https://github.com/dahlbyk/posh-git). Function,
module, and setting names have changed in the fork — see [README.md](README.md)
for the current source of truth.

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
