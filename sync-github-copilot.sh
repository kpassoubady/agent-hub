#!/usr/bin/env bash
# sync-github-copilot.sh — sync agent-hub agents and skills into a
# GitHub Copilot workspace. Default is symlink so hub updates flow into
# the workspace automatically.
#
# Copilot agents live in <workspace>/.github/copilot/agents/
# Copilot skills live in <workspace>/.github/copilot/skills/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
  echo "  workspace   Path to a workspace (default: current directory)."
  echo "              Will create <workspace>/.github/copilot/ if missing."
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  -c, --copy        Copy files instead of symlinking"
  echo "  -f, --force       Overwrite existing files/links"
  echo "  -d, --dry-run     Show what would happen without writing"
  echo "  -h, --help        Show this help message"
  echo ""
  echo -e "${BOLD}Examples:${NC}"
  echo "  ./sync-github-copilot.sh                            # Sync to ./.github/copilot/"
  echo "  ./sync-github-copilot.sh /path/to/project           # Sync to a specific workspace"
  echo "  ./sync-github-copilot.sh -f /path/to/project        # Overwrite existing links"
  echo "  ./sync-github-copilot.sh --copy /path/to/project    # Copy instead of symlink"
  echo "  ./sync-github-copilot.sh -d                         # Dry run"
}

COPY=false
FORCE=false
DRY_RUN=false
WORKSPACE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
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

WORKSPACE_INPUT="${WORKSPACE:-$(pwd)}"
WORKSPACE="$(cd "$WORKSPACE_INPUT" 2>/dev/null && pwd)" || {
  echo -e "${RED}Workspace path does not exist: $WORKSPACE_INPUT${NC}" >&2
  exit 1
}

TARGET_AGENTS="$WORKSPACE/.github/copilot/agents"
TARGET_SKILLS="$WORKSPACE/.github/copilot/skills"

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
  local dest="$WORKSPACE/.github/copilot/$dest_rel"
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
echo -e "Workspace: ${CYAN}$WORKSPACE${NC}"
echo -e "Target:    ${CYAN}$WORKSPACE/.github/copilot/${NC}"
echo -e "Mode:      $([[ "$COPY" == true ]] && echo "copy" || echo "symlink")"
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
