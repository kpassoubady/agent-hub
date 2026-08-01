#Requires -Version 5.1
<#
.SYNOPSIS
    Agent Hub installer for Gemini / Antigravity IDE.

.DESCRIPTION
    Installs agent-hub modules into
    $env:USERPROFILE\.gemini\config\plugins\agent-hub (or a path given via -Path).
    Writes a plugin.json manifest.

.EXAMPLE
    .\gemini_install.ps1
    Install all modules to the default Gemini plugin directory.

.EXAMPLE
    .\gemini_install.ps1 agents
    Install only the agents module.
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

$UserHome =
    if ($env:USERPROFILE) { $env:USERPROFILE }
    else { $env:HOME }

$GeminiHome =
    if ($Path) { $Path }
    elseif ($env:GEMINI_HOME) { $env:GEMINI_HOME }
    else { Join-Path $UserHome '.gemini' }

$PluginDir = Join-Path $GeminiHome 'config\plugins\agent-hub'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$AllModules = @('agents', 'skills', 'templates', 'hooks')

function Show-Usage {
    Write-Host "Usage: .\gemini_install.ps1 [options] [modules...]"
    Write-Host ""
    Write-Host "Modules: agents skills templates hooks"
    Write-Host "  If no modules specified, all available modules are installed."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Force          Overwrite existing files (default: skip)"
    Write-Host "  -DryRun         Show what would be installed without copying"
    Write-Host "  -Path PATH      Install into PATH instead of `$env:USERPROFILE\.gemini"
    Write-Host "  -Help           Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\gemini_install.ps1"
    Write-Host "  .\gemini_install.ps1 agents"
    Write-Host "  .\gemini_install.ps1 -Force agents skills"
    Write-Host "  .\gemini_install.ps1 -DryRun"
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

$script:Copied = 0
$script:Skipped = 0
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
Write-Host "Agent Hub -> Gemini/Antigravity Installer"
Write-Host "Target: $PluginDir" -ForegroundColor Cyan
if ($DryRun) { Write-Host "(dry run - no files will be modified)" -ForegroundColor Yellow }
Write-Host ""

$PluginJsonPath = Join-Path $PluginDir 'plugin.json'
$PluginJson = @'
{
  "name": "agent-hub",
  "description": "Reusable Claude Code agents, skills, and templates adapted for Gemini/Antigravity"
}
'@

if (-not $DryRun) {
    if (-not (Test-Path $PluginDir)) {
        New-Item -ItemType Directory -Path $PluginDir -Force | Out-Null
    }
    Set-Content -Path $PluginJsonPath -Value $PluginJson -NoNewline
    Write-Host "  [write] $PluginJsonPath" -ForegroundColor Green
}
else {
    Write-Host "  [write] $PluginJsonPath" -ForegroundColor Green
}
Write-Host ""

foreach ($mod in $Modules) {
    $modDir = Join-Path $ScriptDir $mod
    if (-not (Test-Path $modDir -PathType Container)) { continue }

    Write-Host "[$mod]"

    Get-ChildItem -Path $modDir -File -Recurse | ForEach-Object {
        $relPath = $_.FullName.Substring($modDir.Length).TrimStart('\', '/')
        $dest = Join-Path (Join-Path $PluginDir $mod) $relPath
        Install-File -Source $_.FullName -Destination $dest
    }

    Write-Host ""
}

Write-Host "Done. $script:Copied copied, $script:Skipped skipped, $script:Overwritten overwritten"
