# Cross-Platform Plan (macOS / Linux / Windows)

`gee` is a PowerShell module (a posh-git fork), and PowerShell 7+ (`pwsh`) already
runs natively on macOS, Linux, and Windows. Most OS-specific code paths are already
guarded, and the `pwsh.yml` CI workflow already runs the test matrix on all three
OSes. What remains is a small set of genuine Windows-only assumptions plus metadata,
CI, and docs cleanup.

## What already works cross-platform

| Area | File | Status |
|---|---|---|
| Console P/Invoke (`kernel32.dll`) | `src/ConsoleMode.ps1:4` | Early-returns a no-op stub on non-Windows |
| Admin check | `src/Utils.ps1:58` | Falls back to `id -u` on Linux/macOS |
| Path case-sensitivity | `src/Utils.ps1:386` | `Ordinal` on Linux, `OrdinalIgnoreCase` elsewhere |
| File encoding read | `src/Utils.ps1:354` | Handles PS 6+ vs 5.x |
| Git-for-Windows warning | `src/CheckRequirements.ps1:19` | Windows-gated |
| CI | `.github/workflows/pwsh.yml:18` | Matrix is `windows/macos/ubuntu` |

---

## Prep

Make sure your working tree is clean and branch off `trunk`:

```powershell
git switch trunk
git pull
git switch -c cross-platform-fixes
```

---

## Step 1 — Fix the `PSModulePath` separator (real bug)

**File:** `src/Utils.ps1` (line ~397)

**Find:**

```powershell
function Get-PSModulePath {
    $modulePaths = $Env:PSModulePath -split ';'
    $modulePaths
}
```

**Replace with:**

```powershell
function Get-PSModulePath {
    $modulePaths = $Env:PSModulePath -split [System.IO.Path]::PathSeparator
    $modulePaths
}
```

**Why:** `PathSeparator` is `;` on Windows and `:` on macOS/Linux. Hardcoding `;`
means the whole path string comes back as one element on Unix, so
`Test-InPSModulePath` never matches and profile-import logic misbehaves.

**Verify** (on any OS):

```powershell
Import-Module ./src/gee.psd1 -Force
# Should return multiple paths on every OS, not one giant string:
& (Get-Module gee) { Get-PSModulePath }
```

> Heads-up: `test/Utils.Tests.ps1` *mocks* `Get-PSModulePath`, so those tests won't
> catch this. Adding real coverage is optional and not required for the fix.

---

## Step 2 — Fix the install script path separator (real bug)

**File:** `install.ps1` (line 5)

**Find:**

```powershell
Import-Module $installDir\src\gee.psd1
```

**Replace with:**

```powershell
Import-Module (Join-Path $installDir 'src' 'gee.psd1')
```

**Why:** `\` is a literal filename character on Linux/macOS, not a directory
separator, so the backslash path fails to resolve. `Join-Path` emits the correct
separator per OS.

**Verify:**

- Windows: `./install.ps1 -WhatIf`
- macOS/Linux: `pwsh ./install.ps1 -WhatIf`

It should load the module and print the profile-edit it *would* make, with no
path-resolution error.

---

## Step 3 — Advertise cross-platform support in the manifest

**File:** `src/gee.psd1` (right after `PowerShellVersion`, ~line 22)

**Find:**

```powershell
# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.0'
```

**Replace with:**

```powershell
# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.0'

# PowerShell editions this module is compatible with
CompatiblePSEditions = @('Core', 'Desktop')
```

**Why:** `Desktop` = Windows PowerShell 5.1; `Core` = PowerShell 7+ (the
cross-platform runtime). Declaring both lets PSGallery and `Get-Module` filter
correctly and signals the module runs everywhere.

**Verify:**

```powershell
Test-ModuleManifest ./src/gee.psd1
```

Should pass with no errors and list both editions.

> Note: leave `PowerShellVersion = '5.0'` as-is — Windows users on 5.1 still work,
> and `CompatiblePSEditions` is what actually communicates cross-platform.

---

## Step 4 — Make CI actually run (config, not OS)

Both workflows only trigger on `main`/`master`, but this repo's default branch is
`trunk`, so CI never fires today.

**Files:** `.github/workflows/pwsh.yml` **and** `.github/workflows/powershell.yml`
(lines 4–7 in each)

**Find (in both):**

```yaml
on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
```

**Replace with (in both):**

```yaml
on:
  push:
    branches: [ trunk, main, master ]
  pull_request:
    branches: [ trunk, main, master ]
```

**Why:** `pwsh.yml` already runs the test matrix on `windows-latest`,
`macos-latest`, and `ubuntu-latest` — that's the cross-platform proof. It just needs
to trigger on the real branch. (`powershell.yml` is the Windows-PowerShell-5.1 job
and is correctly Windows-only — leave its matrix alone.)

**Verify:** After pushing the branch and opening a PR into `trunk`, both workflows
appear in the Checks tab. The "PowerShell Core" matrix should go green on all three
OSes.

---

## Step 5 — Docs pass (optional, recommended)

**File:** `README.md` — near the top / a Requirements section.

Add an explicit runtime line, e.g.:

> **Requirements:** Git 2.15+, and either **Windows PowerShell 5.1** (Windows) or
> **PowerShell 7+** (`pwsh`, required on macOS/Linux).

**Why:** the README currently reads Windows-first; new Mac/Linux users need to know
they must be in `pwsh`, not `powershell`.

---

## Finish

Run the test suite locally before pushing:

```powershell
Import-Module Pester
Invoke-Pester -Path test -Output Detailed
```

Then:

```powershell
git add -A
git commit
git push -u origin cross-platform-fixes
```

Open the PR into `trunk` and let the 3-OS matrix confirm it.

---

**One thing you can't fully verify from Windows alone:** that the Pester suite
genuinely passes *on* macOS and Linux. That's exactly what the Step 4 CI change buys
you — the `pwsh.yml` matrix runs it on real macOS and Ubuntu runners, so the PR
checks are your validation.
