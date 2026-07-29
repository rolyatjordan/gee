param([switch]$WhatIf = $false, [switch]$Force = $false, [switch]$Verbose = $false)

$installDir = Split-Path $MyInvocation.MyCommand.Path -Parent

Import-Module (Join-Path $installDir 'src' 'gee.psd1')
Add-GeeToProfile -WhatIf:$WhatIf -Force:$Force -Verbose:$Verbose
