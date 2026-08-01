#!/usr/bin/env bash
# claude_install.sh — Claude Code installer wrapper.
# See install.sh for the underlying implementation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/install.sh" "$@"
