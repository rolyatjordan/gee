param([bool]$UseLegacyTabExpansion, [bool]$EnableProxyFunctionExpansion)

if (Test-Path Env:\GEE_ENABLE_STRICTMODE) {
    # Set strict mode to latest to help catch scripting errors in the module. This is done by the Pester tests.
    Set-StrictMode -Version Latest
}

. $PSScriptRoot\CheckRequirements.ps1 > $null

. $PSScriptRoot\ConsoleMode.ps1
. $PSScriptRoot\Utils.ps1
. $PSScriptRoot\GeeTypes.ps1
. $PSScriptRoot\GitUtils.ps1
. $PSScriptRoot\GitParamTabExpansion.ps1
. $PSScriptRoot\GitTabExpansion.ps1
. $PSScriptRoot\GitTools.ps1

$global:GeeStatusSettings = [GeeStatusSettings]::new()

$IsAdmin = Test-Administrator

$exportModuleMemberParams = @{
    Alias = '*'
    Function = @(
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
        'Set-GeeAliases',
        'Set-GitLocationRoot',
        'Show-GitStatus',
        'Switch-GitBranch',
        'Switch-GitTrunk',
        'Sync-GitBranch',
        'Update-AllBranches'
    )
}

Export-ModuleMember @exportModuleMemberParams
