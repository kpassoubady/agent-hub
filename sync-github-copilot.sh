#!/usr/bin/env bash
# sync-github-copilot.sh — sync agent-hub agents and skills into a
# GitHub Copilot workspace, or into the user-global Copilot config.
# Default is symlink so hub updates flow into the target automatically.
#
# Project level (default): <workspace>/.github/copilot/agents/ and skills/
# Global level (--global):  ~/.copilot/agents/ and skills/
#                           (override the base with COPILOT_HOME)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COPILOT_HOME="${COPILOT_HOME:-$HOME/.copilot}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
  echo -e "${BOLD}Usage:${NC} ./sync-github-copilot.sh [options] [workspace]"
  echo ""
  echo "Sync agent-hub agents and the feature-factory skill into a Copilot"
  echo "workspace. Default is symlink so hub updates flow in."
  echo ""
  echo -e "${BOLD}Arguments:${NC}"
  echo "  workspace   Path to a project workspace (default: current directory)."
  echo "              Ignored with --global. Targets <workspace>/.github/copilot/."
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  -g, --global      Sync to the user-global Copilot config (~/.copilot)"
  echo "                    instead of a project's .github/copilot/"
  echo "  -c, --copy        Copy files instead of symlinking"
  echo "  -f, --force       Overwrite existing files/links"
  echo "  -d, --dry-run     Show what would happen without writing"
  echo "  -h, --help        Show this help message"
  echo ""
  echo -e "${BOLD}Examples:${NC}"
  echo "  ./sync-github-copilot.sh                            # Project: ./.github/copilot/"
  echo "  ./sync-github-copilot.sh /path/to/project           # Project: a specific workspace"
  echo "  ./sync-github-copilot.sh --global                   # Global:  ~/.copilot/"
  echo "  ./sync-github-copilot.sh -g -f                      # Global, overwrite existing"
  echo "  ./sync-github-copilot.sh --copy /path/to/project    # Project, copy instead of symlink"
  echo "  ./sync-github-copilot.sh -d                         # Dry run"
}

GLOBAL=false
COPY=false
FORCE=false
DRY_RUN=false
WORKSPACE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--global)  GLOBAL=true; shift ;;
    -c|--copy)    COPY=true; shift ;;
    -f|--force)   FORCE=true; shift ;;
    -d|--dry-run) DRY_RUN=true; shift ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo -e "${RED}Unknown option: $1${NC}"; usage; exit 1 ;;
    *)
      [[ -n "$WORKSPACE" ]] && { echo -e "${RED}Only one workspace path is allowed${NC}"; exit 1; }
      WORKSPACE="$1"; shift ;;
  esac
done

# Resolve the sync base directory.
if [[ "$GLOBAL" == true ]]; then
  [[ -n "$WORKSPACE" ]] && { echo -e "${RED}A workspace path cannot be combined with --global${NC}"; exit 1; }
  BASE_DIR="$COPILOT_HOME"
  SCOPE_LABEL="global (~/.copilot)"
else
  WORKSPACE_INPUT="${WORKSPACE:-$(pwd)}"
  WORKSPACE="$(cd "$WORKSPACE_INPUT" 2>/dev/null && pwd)" || {
    echo -e "${RED}Workspace path does not exist: $WORKSPACE_INPUT${NC}" >&2
    exit 1
  }
  BASE_DIR="$WORKSPACE/.github/copilot"
  SCOPE_LABEL="project"
fi

# Build the source list: every agent + the feature-factory skill
SOURCES=()
for f in "$SCRIPT_DIR/agents/"*.md; do
  [[ -f "$f" ]] && SOURCES+=("$f|agents/$(basename "$f")")
done

if [[ -f "$SCRIPT_DIR/skills/feature-factory/SKILL.md" ]]; then
  SOURCES+=("$SCRIPT_DIR/skills/feature-factory/SKILL.md|skills/feature-factory/SKILL.md")
fi

if [[ ${#SOURCES[@]} -eq 0 ]]; then
  echo -e "${RED}No agents or skills found in $SCRIPT_DIR${NC}"
  exit 1
fi

linked=0
copied=0
skipped=0
overwritten=0

install_one() {
  local src="$1"
  local dest_rel="$2"
  local dest="$BASE_DIR/$dest_rel"
  local target_dir
  target_dir="$(dirname "$dest")"
  local replacing=false

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ "$FORCE" == true ]]; then
      replacing=true
    else
      echo -e "  ${CYAN}[skip]${NC} $dest (already exists; use --force to overwrite)"
      skipped=$((skipped + 1))
      return
    fi
  fi

  if [[ "$COPY" == true ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo -e "  $([[ "$replacing" == true ]] && echo -e "${YELLOW}[overwrite-copy]${NC}" || echo -e "${GREEN}[copy]${NC}") $dest"
    else
      mkdir -p "$target_dir"
      [[ "$replacing" == true ]] && rm -f "$dest"
      cp "$src" "$dest"
      echo -e "  $([[ "$replacing" == true ]] && echo -e "${YELLOW}[overwrite-copy]${NC}" || echo -e "${GREEN}[copy]${NC}") $dest"
    fi
    if [[ "$replacing" == true ]]; then
      overwritten=$((overwritten + 1))
    else
      copied=$((copied + 1))
    fi
  else
    if [[ "$DRY_RUN" == true ]]; then
      echo -e "  $([[ "$replacing" == true ]] && echo -e "${YELLOW}[overwrite-link]${NC}" || echo -e "${GREEN}[link]${NC}") $dest -> $src"
    else
      mkdir -p "$target_dir"
      [[ "$replacing" == true ]] && rm -f "$dest"
      ln -s "$src" "$dest"
      echo -e "  $([[ "$replacing" == true ]] && echo -e "${YELLOW}[overwrite-link]${NC}" || echo -e "${GREEN}[link]${NC}") $dest -> $src"
    fi
    if [[ "$replacing" == true ]]; then
      overwritten=$((overwritten + 1))
    else
      linked=$((linked + 1))
    fi
  fi
}

echo ""
echo -e "${BOLD}Agent Hub → GitHub Copilot Sync${NC}"
echo -e "Scope:  ${CYAN}$SCOPE_LABEL${NC}"
echo -e "Target: ${CYAN}$BASE_DIR/${NC}"
echo -e "Mode:   $([[ "$COPY" == true ]] && echo "copy" || echo "symlink")"
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}(dry run - no files will be modified)${NC}"
fi
echo ""

for entry in "${SOURCES[@]}"; do
  src="${entry%|*}"
  dest_rel="${entry##*|}"
  install_one "$src" "$dest_rel"
done

echo ""
if [[ "$COPY" == true ]]; then
  echo -e "${BOLD}Done.${NC} ${GREEN}$copied copied${NC}, ${CYAN}$skipped skipped${NC}, ${YELLOW}$overwritten overwritten${NC}"
else
  echo -e "${BOLD}Done.${NC} ${GREEN}$linked linked${NC}, ${CYAN}$skipped skipped${NC}, ${YELLOW}$overwritten overwritten${NC}"
fi
