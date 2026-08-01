#Requires -Version 5.1
<#
.SYNOPSIS
    Devin workspace sync wrapper.

.DESCRIPTION
    Invokes sync-devin.ps1 for users who expect the devin_install.ps1 naming.
    Syncs agent-hub agents and the feature-factory skill into .devin/workflows.

.EXAMPLE
    .\devin_install.ps1
    Sync to .\devin\workflows in the current directory.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Workspace = "",

    [switch]$Copy,

    [switch]$Force,

    [switch]$DryRun
)

& "$PSScriptRoot\sync-devin.ps1" @PSBoundParameters
