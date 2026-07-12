enum UntrackedFilesMode { Default; No; Normal; All }

# Data-shaping settings for Get-GitStatus.
class GeeStatusSettings {
    [string]$DescribeStyle = ''
    [bool]$Debug = $false

    [bool]$EnablePromptStatus = !$global:GitMissing
    [bool]$EnableFileStatus = $true
    [Nullable[bool]]$EnableFileStatusFromCache = $null
    [bool]$EnableStashStatus = $false

    [UntrackedFilesMode]$UntrackedFilesMode = [UntrackedFilesMode]::Default
    [string[]]$RepositoriesInWhichToDisableFileStatus = @()
}
