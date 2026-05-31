#Requires -Version 5.1
<#
.SYNOPSIS
    Agent Hub installer for Windows.

.DESCRIPTION
    Installs agent-hub modules (agents, skills, templates, hooks) into
    $env:USERPROFILE\.claude (or a path given via -Path).

.EXAMPLE
    .\install.ps1
    Install all modules to ~\.claude.

.EXAMPLE
    .\install.ps1 agents skills
    Install only the agents and skills modules.

.EXAMPLE
    .\install.ps1 -Force agents
    Force overwrite of existing agent files.

.EXAMPLE
    .\install.ps1 -DryRun
    Show what would happen without writing anything.

.EXAMPLE
    .\install.ps1 -Path C:\proj\.claude
    Install into a specific project's .claude directory.
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

$ErrorActionPreference = 'Stop'

$ClaudeHome =
    if ($Path) { $Path }
    elseif ($env:CLAUDE_HOME) { $env:CLAUDE_HOME }
    else { Join-Path $env:USERPROFILE '.claude' }

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$AllModules = @('agents', 'skills', 'templates', 'hooks')

function Show-Usage {
    Write-Host "Usage: .\install.ps1 [options] [modules...]"
    Write-Host ""
    Write-Host "Modules: agents skills templates hooks"
    Write-Host "  If no modules specified, all available modules are installed."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Force          Overwrite existing files (default: skip)"
    Write-Host "  -DryRun         Show what would be installed without copying"
    Write-Host "  -Path PATH      Install into PATH instead of `$env:USERPROFILE\.claude"
    Write-Host "  -Help           Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\install.ps1"
    Write-Host "  .\install.ps1 agents"
    Write-Host "  .\install.ps1 -Force agents skills"
    Write-Host "  .\install.ps1 -DryRun"
    Write-Host "  .\install.ps1 -Path C:\proj\.claude"
}

if ($Help) { Show-Usage; exit 0 }

if (-not $Modules -or $Modules.Count -eq 0) {
    $Modules = @()
    foreach ($mod in $AllModules) {
        if (Test-Path (Join-Path $ScriptDir $mod) -PathType Container) {
            $Modules += $mod
        }
    }
}

foreach ($mod in $Modules) {
    if (-not (Test-Path (Join-Path $ScriptDir $mod) -PathType Container)) {
        Write-Host "Module '$mod' not found in repo. Skipping." -ForegroundColor Red
    }
}

$script:Copied      = 0
$script:Skipped     = 0
$script:Overwritten = 0

function Install-File {
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$Destination
    )

    if ((Split-Path -Leaf $Source) -eq '.DS_Store') { return }

    $destDir = Split-Path -Parent $Destination

    if (Test-Path $Destination -PathType Leaf) {
        if ($Force) {
            if ($DryRun) {
                Write-Host "  [overwrite] $Destination" -ForegroundColor Yellow
            }
            else {
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item -Path $Source -Destination $Destination -Force
                Write-Host "  [overwrite] $Destination" -ForegroundColor Yellow
            }
            $script:Overwritten++
        }
        else {
            Write-Host "  [skip] $Destination (already exists)" -ForegroundColor Cyan
            $script:Skipped++
        }
    }
    else {
        if ($DryRun) {
            Write-Host "  [copy] $Destination" -ForegroundColor Green
        }
        else {
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -Path $Source -Destination $Destination
            Write-Host "  [copy] $Destination" -ForegroundColor Green
        }
        $script:Copied++
    }
}

Write-Host ""
Write-Host "Agent Hub Installer"
Write-Host "Target: $ClaudeHome" -ForegroundColor Cyan
if ($DryRun) { Write-Host "(dry run - no files will be modified)" -ForegroundColor Yellow }
Write-Host ""

foreach ($mod in $Modules) {
    $modDir = Join-Path $ScriptDir $mod
    if (-not (Test-Path $modDir -PathType Container)) { continue }

    Write-Host "[$mod]"

    Get-ChildItem -Path $modDir -File -Recurse | ForEach-Object {
        $relPath = $_.FullName.Substring($modDir.Length).TrimStart('\', '/')
        $dest    = Join-Path (Join-Path $ClaudeHome $mod) $relPath
        Install-File -Source $_.FullName -Destination $dest
    }

    Write-Host ""
}

Write-Host "Done. $script:Copied copied, $script:Skipped skipped, $script:Overwritten overwritten"
