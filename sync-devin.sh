#!/usr/bin/env bash
# sync-devin.sh — sync agent-hub agents and the feature-factory skill into a
# Devin workspace as workflows. Default is symlink so hub updates flow into
# the workspace automatically.
#
# Devin workflows live in <workspace>/.devin/workflows/ and require only a
# `description:` field in frontmatter. The Claude-specific frontmatter on the
# agent files (tools, model, version, ...) is ignored by Devin.
#
# Legacy `.windsurf/workflow/` directories still work in Devin Desktop and are
# left untouched if they already exist; new syncs use `.devin/workflows/.

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
  echo -e "${BOLD}Usage:${NC} ./sync-devin.sh [options] [workspace]"
  echo ""
  echo "Sync agent-hub agents and the feature-factory skill into a Devin"
  echo "workspace as workflows. Default is symlink so hub updates flow in."
  echo ""
  echo -e "${BOLD}Arguments:${NC}"
  echo "  workspace   Path to a Devin workspace (default: current directory)."
  echo "              Will create <workspace>/.devin/workflows/ if missing."
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  -c, --copy        Copy files instead of symlinking"
  echo "  -f, --force       Overwrite existing files/links"
  echo "  -d, --dry-run     Show what would happen without writing"
  echo "  -h, --help        Show this help message"
  echo ""
  echo -e "${BOLD}Examples:${NC}"
  echo "  ./sync-devin.sh                            # Sync to ./.devin/workflows/"
  echo "  ./sync-devin.sh /path/to/project           # Sync to a specific workspace"
  echo "  ./sync-devin.sh -f /path/to/project        # Overwrite existing links"
  echo "  ./sync-devin.sh --copy /path/to/project    # Copy instead of symlink"
  echo "  ./sync-devin.sh -d                         # Dry run"
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

# Default workspace = current directory.
WORKSPACE_INPUT="${WORKSPACE:-$(pwd)}"
WORKSPACE="$(cd "$WORKSPACE_INPUT" 2>/dev/null && pwd)" || {
  echo -e "${RED}Workspace path does not exist: $WORKSPACE_INPUT${NC}" >&2
  exit 1
}

TARGET="$WORKSPACE/.devin/workflows"

# Build the source list: every agent + the orchestrator skill (renamed).
SOURCES=()
for f in "$SCRIPT_DIR/agents/"*.md; do
  [[ -f "$f" ]] && SOURCES+=("$f|$(basename "$f")")
done

if [[ -f "$SCRIPT_DIR/skills/feature-factory/SKILL.md" ]]; then
  SOURCES+=("$SCRIPT_DIR/skills/feature-factory/SKILL.md|feature-factory.md")
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
  local dest_name="$2"
  local dest="$TARGET/$dest_name"
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
      mkdir -p "$TARGET"
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
      mkdir -p "$TARGET"
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
echo -e "${BOLD}Agent Hub → Devin Sync${NC}"
echo -e "Workspace: ${CYAN}$WORKSPACE${NC}"
echo -e "Target:    ${CYAN}$TARGET${NC}"
echo -e "Mode:      $([[ "$COPY" == true ]] && echo "copy" || echo "symlink")"
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}(dry run - no files will be modified)${NC}"
fi
echo ""

for entry in "${SOURCES[@]}"; do
  src="${entry%|*}"
  name="${entry##*|}"
  install_one "$src" "$name"
done

echo ""
if [[ "$COPY" == true ]]; then
  echo -e "${BOLD}Done.${NC} ${GREEN}$copied copied${NC}, ${CYAN}$skipped skipped${NC}, ${YELLOW}$overwritten overwritten${NC}"
else
  echo -e "${BOLD}Done.${NC} ${GREEN}$linked linked${NC}, ${CYAN}$skipped skipped${NC}, ${YELLOW}$overwritten overwritten${NC}"
fi
