#!/usr/bin/env bash
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
  echo -e "${BOLD}Usage:${NC} ./install_all.sh [options] [workspace]"
  echo ""
  echo "Install Agent Hub into all supported assistants at once."
  echo ""
  echo "- Claude Code: global ~/.claude (./install.sh)"
  echo "- Gemini/Antigravity: global ~/.gemini plugin (./gemini_install.sh)"
  echo "- Devin: per-workspace .devin/workflows (./sync-devin.sh)"
  echo "- GitHub Copilot: per-workspace .github/copilot (./sync-github-copilot.sh)"
  echo ""
  echo "Run this from a project workspace to sync Devin and Copilot there."
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  -f, --force       Overwrite existing files (default: skip)"
  echo "  -d, --dry-run     Show what would be installed without writing"
  echo "  -g, --global      Install GitHub Copilot globally (~/.copilot) instead of the workspace"
  echo "  -h, --help        Show this help message"
  echo ""
  echo -e "${BOLD}Examples:${NC}"
  echo "  ./install_all.sh                              # Install all tools (project = current dir)"
  echo "  ./install_all.sh /path/to/project             # Sync Devin/Copilot to a specific project"
  echo "  ./install_all.sh -f                           # Force overwrite"
  echo "  ./install_all.sh -d                           # Dry run"
  echo "  ./install_all.sh --global                     # Install Copilot globally"
}

FORCE=false
DRY_RUN=false
GLOBAL=false
WORKSPACE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)   FORCE=true; shift ;;
    -d|--dry-run) DRY_RUN=true; shift ;;
    -g|--global)  GLOBAL=true; shift ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo -e "${RED}Unknown option: $1${NC}"; usage; exit 1 ;;
    *)
      [[ -n "$WORKSPACE" ]] && { echo -e "${RED}Only one workspace path is allowed${NC}"; usage; exit 1; }
      WORKSPACE="$1"; shift ;;
  esac
done

FLAGS=()
[[ "$FORCE" == true ]] && FLAGS+=("-f")
[[ "$DRY_RUN" == true ]] && FLAGS+=("-d")

COPILOT_FLAGS=("${FLAGS[@]}")
[[ "$GLOBAL" == true ]] && COPILOT_FLAGS+=("--global")

echo ""
echo -e "${BOLD}Agent Hub — Install All${NC}"
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}(dry run - no files will be modified)${NC}"
fi
echo ""

echo -e "${YELLOW}=== Claude Code ===${NC}"
"$SCRIPT_DIR/claude_install.sh" "${FLAGS[@]}"
echo ""

echo -e "${YELLOW}=== Gemini / Antigravity ===${NC}"
"$SCRIPT_DIR/gemini_install.sh" "${FLAGS[@]}"
echo ""

echo -e "${YELLOW}=== Devin ===${NC}"
if [[ -n "$WORKSPACE" ]]; then
  "$SCRIPT_DIR/devin_install.sh" "${FLAGS[@]}" "$WORKSPACE"
else
  "$SCRIPT_DIR/devin_install.sh" "${FLAGS[@]}"
fi
echo ""

echo -e "${YELLOW}=== GitHub Copilot ===${NC}"
if [[ -n "$WORKSPACE" ]]; then
  "$SCRIPT_DIR/sync-github-copilot.sh" "${COPILOT_FLAGS[@]}" "$WORKSPACE"
else
  "$SCRIPT_DIR/sync-github-copilot.sh" "${COPILOT_FLAGS[@]}"
fi
echo ""

echo -e "${GREEN}${BOLD}All installations complete.${NC}"
