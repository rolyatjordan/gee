@{

# Script module or binary module file associated with this manifest.
RootModule = 'gee.psm1'

# Version number of this module.
ModuleVersion = '0.2.1'

# ID used to uniquely identify this module
GUID = 'f911c4c0-1684-4c3e-9458-112fab368c37'

# Author of this module
Author = 'Taylor Jordan (fork). Original: Keith Dahlby, Keith Hill, and contributors'

# Copyright statement for this module
Copyright = '(c) 2010-2018 Keith Dahlby, Keith Hill, and contributors; (c) 2026 Taylor Jordan'

# Description of the functionality provided by this module
Description = 'gee: Git tab completion and workflow shortcuts for PowerShell. Bring your own prompt.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

# PowerShell editions this module is compatible with
CompatiblePSEditions = @('Core', 'Desktop')

# Functions to export from this module
FunctionsToExport = @(
    'Add-GeeToProfile',
    'Expand-GitCommand',
    'Get-GitDirectory',
    'Get-GitHealth',
    'Get-GitStatus',
    'Get-GitToolsHelp',
    'New-GitBranch',
    'New-GitCommit',
    'Remove-GeeFromProfile',
    'Remove-GitAliasCruft',
    'Remove-GitBranch',
    'Remove-GitStaleBranch',
    'Set-GitLocationRoot',
    'Show-GitStatus',
    'Switch-GitBranch',
    'Switch-GitTrunk',
    'Sync-GitBranch',
    'Update-AllBranches'
)

# Cmdlets to export from this module
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module
AliasesToExport = @('g-help', 'g-status', 'g-trunk', 'g-root', 'g-new', 'g-switch', 'g-commit', 'g-prune', 'g-sync', 'g-health', 'g-clean-aliases')

# Private data to pass to the module specified in RootModule/ModuleToProcess.
# This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{
    PSData = @{
        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('git', 'tab', 'tab-completion', 'tab-expansion', 'tabexpansion', 'PSEdition_Core')

        # A URL to this module's license, which retains the upstream posh-git copyright.
        LicenseUri = 'https://github.com/rolyatjordan/gee/blob/trunk/LICENSE.txt'
    }
}
}
