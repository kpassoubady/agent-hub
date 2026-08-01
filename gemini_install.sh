#!/usr/bin/env bash
set -euo pipefail

GEMINI_HOME="${GEMINI_HOME:-$HOME/.gemini}"
PLUGIN_DIR="$GEMINI_HOME/config/plugins/agent-hub"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ALL_MODULES=(agents skills templates hooks)

usage() {
  echo -e "${BOLD}Usage:${NC} ./gemini_install.sh [options] [modules...]"
  echo ""
  echo -e "${BOLD}Modules:${NC} agents skills templates hooks"
  echo "  If no modules specified, all available modules are installed."
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  -f, --force         Overwrite existing files (default: skip)"
  echo "  -d, --dry-run       Show what would be installed without copying"
  echo "  -p, --path PATH     Install into PATH instead of ~/.gemini"
  echo "                      (use <project>/.gemini for per-project install)"
  echo "  -h, --help          Show this help message"
  echo ""
  echo -e "${BOLD}Examples:${NC}"
  echo "  ./gemini_install.sh                              # Install everything to ~/.gemini"
  echo "  ./gemini_install.sh agents                       # Install only agents"
  echo "  ./gemini_install.sh -f agents skills             # Force overwrite agents and skills"
  echo "  ./gemini_install.sh -d                           # Dry run"
  echo "  ./gemini_install.sh -p /path/to/project/.gemini  # Per-project install"
}

FORCE=false
DRY_RUN=false
MODULES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)   FORCE=true; shift ;;
    -d|--dry-run) DRY_RUN=true; shift ;;
    -p|--path)
      [[ -z "${2:-}" ]] && { echo -e "${RED}--path requires an argument${NC}"; exit 1; }
      GEMINI_HOME="$2"
      PLUGIN_DIR="$GEMINI_HOME/config/plugins/agent-hub"
      shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo -e "${RED}Unknown option: $1${NC}"; usage; exit 1 ;;
    *)            MODULES+=("$1"); shift ;;
  esac
done

if [[ ${#MODULES[@]} -eq 0 ]]; then
  for mod in "${ALL_MODULES[@]}"; do
    [[ -d "$SCRIPT_DIR/$mod" ]] && MODULES+=("$mod")
  done
fi

for mod in "${MODULES[@]}"; do
  if [[ ! -d "$SCRIPT_DIR/$mod" ]]; then
    echo -e "${RED}Module '$mod' not found in repo. Skipping.${NC}"
  fi
done

copied=0
skipped=0
overwritten=0

install_file() {
  local src="$1"
  local dest="$2"

  [[ "$(basename "$src")" == ".DS_Store" ]] && return

  local dest_dir
  dest_dir="$(dirname "$dest")"

  if [[ -f "$dest" ]]; then
    if [[ "$FORCE" == true ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${YELLOW}[overwrite]${NC} $dest"
      else
        mkdir -p "$dest_dir"
        cp "$src" "$dest"
        echo -e "  ${YELLOW}[overwrite]${NC} $dest"
      fi
      overwritten=$((overwritten + 1))
    else
      echo -e "  ${CYAN}[skip]${NC} $dest (already exists)"
      skipped=$((skipped + 1))
    fi
  else
    if [[ "$DRY_RUN" == true ]]; then
      echo -e "  ${GREEN}[copy]${NC} $dest"
    else
      mkdir -p "$dest_dir"
      cp "$src" "$dest"
      echo -e "  ${GREEN}[copy]${NC} $dest"
    fi
    copied=$((copied + 1))
  fi
}

echo ""
echo -e "${BOLD}Agent Hub → Gemini/Antigravity Installer${NC}"
echo -e "Target: ${CYAN}$PLUGIN_DIR${NC}"
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}(dry run - no files will be modified)${NC}"
fi
echo ""

if [[ "$DRY_RUN" == false ]]; then
  mkdir -p "$PLUGIN_DIR"
  cat << 'EOF' > "$PLUGIN_DIR/plugin.json"
{
  "name": "agent-hub",
  "description": "Reusable Claude Code agents, skills, and templates adapted for Gemini/Antigravity"
}
EOF
  echo -e "  ${GREEN}[write]${NC} $PLUGIN_DIR/plugin.json"
else
  echo -e "  ${GREEN}[write]${NC} $PLUGIN_DIR/plugin.json"
fi
echo ""

for mod in "${MODULES[@]}"; do
  [[ ! -d "$SCRIPT_DIR/$mod" ]] && continue

  echo -e "${BOLD}[$mod]${NC}"

  while IFS= read -r -d '' file; do
    rel_path="${file#"$SCRIPT_DIR/$mod/"}"
    dest="$PLUGIN_DIR/$mod/$rel_path"
    install_file "$file" "$dest"
  done < <(find "$SCRIPT_DIR/$mod" -type f -print0)

  echo ""
done

echo -e "${BOLD}Done.${NC} ${GREEN}$copied copied${NC}, ${CYAN}$skipped skipped${NC}, ${YELLOW}$overwritten overwritten${NC}"
