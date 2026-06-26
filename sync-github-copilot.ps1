<#
.SYNOPSIS
    Sync agent-hub agents and skills into a GitHub Copilot workspace.

.DESCRIPTION
    Creates symlinks (or copies) of agent-hub agents and the feature-factory skill
    into a target Copilot workspace under .github/copilot/.

.PARAMETER Workspace
    Path to the target Copilot workspace. Defaults to the current directory.

.PARAMETER Copy
    Copy files instead of creating symbolic links.

.PARAMETER Force
    Overwrite existing files or links.

.PARAMETER DryRun
    Show what would be installed without modifying any files.

.EXAMPLE
    .\sync-github-copilot.ps1
    Syncs agents to .github\copilot\ in the current directory.

.EXAMPLE
    .\sync-github-copilot.ps1 -Workspace "C:\projects\myapp" -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Workspace = "",

    [Parameter(Mandatory = $false)]
    [switch]$Copy,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Default workspace = current directory
if ([string]::IsNullOrWhiteSpace($Workspace)) {
    $Workspace = (Get-Location).Path
} else {
    if (-not (Test-Path $Workspace -PathType Container)) {
        Write-Host "Error: Workspace path does not exist: $Workspace" -ForegroundColor Red
        exit 1
    }
    $Workspace = (Resolve-Path $Workspace).Path
}

$TargetBase = Join-Path $Workspace ".github\copilot"

# Build source list
$Sources = @()

$AgentsDir = Join-Path $ScriptDir "agents"
if (Test-Path $AgentsDir) {
    Get-ChildItem -Path $AgentsDir -Filter "*.md" -File | ForEach-Object {
        $Sources += @{
            Source = $_.FullName
            DestRel = "agents\$($_.Name)"
        }
    }
}

$FeatureFactorySkill = Join-Path $ScriptDir "skills\feature-factory\SKILL.md"
if (Test-Path $FeatureFactorySkill) {
    $Sources += @{
        Source = $FeatureFactorySkill
        DestRel = "skills\feature-factory\SKILL.md"
    }
}

if ($Sources.Count -eq 0) {
    Write-Host "No agents or skills found in $ScriptDir" -ForegroundColor Red
    exit 1
}

$Script:Linked = 0
$Script:Copied = 0
$Script:Skipped = 0
$Script:Overwritten = 0

function Write-Status {
    param([string]$Status, [string]$Message, [string]$Color = "White")
    Write-Host "  [$Status] " -ForegroundColor $Color -NoNewline
    Write-Host $Message
}

function Install-One {
    param([string]$Source, [string]$DestRel)

    $Dest = Join-Path $TargetBase $DestRel
    $DestDir = Split-Path -Parent $Dest
    $Replacing = $false

    if (Test-Path $Dest -ErrorAction SilentlyContinue) {
        if ($Force) {
            $Replacing = $true
        } else {
            Write-Status "skip" "$Dest (already exists; use -Force to overwrite)" "Cyan"
            $Script:Skipped++
            return
        }
    }

    if ($Copy) {
        if ($DryRun) {
            if ($Replacing) { Write-Status "overwrite-copy" $Dest "Yellow" }
            else { Write-Status "copy" $Dest "Green" }
        } else {
            if (-not (Test-Path $DestDir)) {
                New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
            }
            if ($Replacing) { Remove-Item -Path $Dest -Force }
            Copy-Item -Path $Source -Destination $Dest
            if ($Replacing) { Write-Status "overwrite-copy" $Dest "Yellow" }
            else { Write-Status "copy" $Dest "Green" }
        }
        if ($Replacing) { $Script:Overwritten++ } else { $Script:Copied++ }
    } else {
        if ($DryRun) {
            if ($Replacing) { Write-Status "overwrite-link" "$Dest -> $Source" "Yellow" }
            else { Write-Status "link" "$Dest -> $Source" "Green" }
        } else {
            if (-not (Test-Path $DestDir)) {
                New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
            }
            if ($Replacing) { Remove-Item -Path $Dest -Force }
            # Creating symlink requires admin privileges on some Windows versions unless developer mode is enabled
            try {
                New-Item -ItemType SymbolicLink -Path $Dest -Target $Source | Out-Null
                if ($Replacing) { Write-Status "overwrite-link" "$Dest -> $Source" "Yellow" }
                else { Write-Status "link" "$Dest -> $Source" "Green" }
            } catch {
                Write-Host "Failed to create symlink. This may require Developer Mode or Administrator privileges on Windows. Use -Copy instead." -ForegroundColor Red
                throw $_
            }
        }
        if ($Replacing) { $Script:Overwritten++ } else { $Script:Linked++ }
    }
}

Write-Host ""
Write-Host "Agent Hub -> GitHub Copilot Sync" -ForegroundColor White
Write-Host "Workspace: " -NoNewline; Write-Host $Workspace -ForegroundColor Cyan
Write-Host "Target:    " -NoNewline; Write-Host $TargetBase -ForegroundColor Cyan
Write-Host "Mode:      " -NoNewline
if ($Copy) { Write-Host "copy" } else { Write-Host "symlink" }
if ($DryRun) { Write-Host "(dry run - no files will be modified)" -ForegroundColor Yellow }
Write-Host ""

foreach ($entry in $Sources) {
    Install-One -Source $entry.Source -DestRel $entry.DestRel
}

Write-Host ""
Write-Host "Done. " -ForegroundColor White -NoNewline
if ($Copy) {
    Write-Host "$Script:Copied copied" -ForegroundColor Green -NoNewline
} else {
    Write-Host "$Script:Linked linked" -ForegroundColor Green -NoNewline
}
Write-Host ", " -NoNewline
Write-Host "$Script:Skipped skipped" -ForegroundColor Cyan -NoNewline
Write-Host ", " -NoNewline
Write-Host "$Script:Overwritten overwritten" -ForegroundColor Yellow
