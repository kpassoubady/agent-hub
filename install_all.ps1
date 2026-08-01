#Requires -Version 5.1
<#
.SYNOPSIS
    Install Agent Hub into all supported assistants at once.

.DESCRIPTION
    Runs the Claude, Gemini, Devin, and GitHub Copilot installers in sequence.
    Devin and Copilot are installed into the current workspace by default.
    Use -Global to install GitHub Copilot into ~/.copilot instead.

.EXAMPLE
    .\install_all.ps1
    Install all tools for the current workspace.

.EXAMPLE
    .\install_all.ps1 C:\projects\myapp
    Install Claude/Gemini globally and sync Devin/Copilot to the given workspace.

.EXAMPLE
    .\install_all.ps1 -DryRun
    Preview what would happen without writing any files.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Workspace = "",

    [Alias('f')]
    [switch]$Force,

    [Alias('d')]
    [switch]$DryRun,

    [Alias('g')]
    [switch]$Global,

    [Alias('h')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Show-Usage {
    Write-Host "Usage: .\install_all.ps1 [options] [workspace]"
    Write-Host ""
    Write-Host "Install Agent Hub into all supported assistants at once."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Force          Overwrite existing files"
    Write-Host "  -DryRun         Show what would happen without writing"
    Write-Host "  -Global         Install GitHub Copilot globally (~/.copilot) instead of the workspace"
    Write-Host "  -Help           Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\install_all.ps1"
    Write-Host "  .\install_all.ps1 C:\projects\myapp"
    Write-Host "  .\install_all.ps1 -Force"
    Write-Host "  .\install_all.ps1 -DryRun"
    Write-Host "  .\install_all.ps1 -Global"
}

if ($Help) { Show-Usage; exit 0 }

$CommonParams = @{}
if ($Force)  { $CommonParams['Force'] = $true }
if ($DryRun) { $CommonParams['DryRun'] = $true }

$DevinParams = @{} + $CommonParams
if (-not [string]::IsNullOrWhiteSpace($Workspace)) {
    $DevinParams['Workspace'] = $Workspace
}

$CopilotParams = @{} + $CommonParams
if ($Global) { $CopilotParams['Global'] = $true }
if (-not [string]::IsNullOrWhiteSpace($Workspace)) {
    $CopilotParams['Workspace'] = $Workspace
}

Write-Host ""
Write-Host "Agent Hub - Install All"
if ($DryRun) { Write-Host "(dry run - no files will be modified)" -ForegroundColor Yellow }
Write-Host ""

Write-Host "=== Claude Code ===" -ForegroundColor Yellow
& "$ScriptDir\claude_install.ps1" @CommonParams
Write-Host ""

Write-Host "=== Gemini / Antigravity ===" -ForegroundColor Yellow
& "$ScriptDir\gemini_install.ps1" @CommonParams
Write-Host ""

Write-Host "=== Devin ===" -ForegroundColor Yellow
& "$ScriptDir\devin_install.ps1" @DevinParams
Write-Host ""

Write-Host "=== GitHub Copilot ===" -ForegroundColor Yellow
& "$ScriptDir\sync-github-copilot.ps1" @CopilotParams
Write-Host ""

Write-Host "All installations complete." -ForegroundColor Green
