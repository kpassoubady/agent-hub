#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Code installer wrapper.

.DESCRIPTION
    Invokes install.ps1 for users who expect the claude_install.ps1 naming.
    Copies agent-hub modules into $env:USERPROFILE\.claude (or -Path).

.EXAMPLE
    .\claude_install.ps1
    Install all modules to ~\.claude.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Modules,

    [Alias('f')]
    [switch]$Force,

    [Alias('d')]
    [switch]$DryRun,

    [Alias('p')]
    [string]$Path,

    [Alias('h')]
    [switch]$Help
)

& "$PSScriptRoot\install.ps1" @PSBoundParameters
