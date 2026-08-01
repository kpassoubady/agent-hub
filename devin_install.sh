#!/usr/bin/env bash
# devin_install.sh — Devin workspace sync wrapper.
# See sync-devin.sh for the underlying implementation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/sync-devin.sh" "$@"
