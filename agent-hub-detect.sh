#!/usr/bin/env bash
# agent-hub-detect.sh — scan a project and write .agenthub-config.yaml.
#
# Auto-detects: language, framework, project shape (full-stack | backend-only |
# frontend-only | library), default test/lint/typecheck commands, and suggested
# source folders.
#
# Re-run with --force to refresh from auto-detection (overwrites manual edits).

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
  echo -e "${BOLD}Usage:${NC} ./agent-hub-detect.sh [options] [project-path]"
  echo ""
  echo "Scans a project, detects its shape and conventions, and writes"
  echo ".agenthub-config.yaml at the project root."
  echo ""
  echo -e "${BOLD}Arguments:${NC}"
  echo "  project-path   Path to the project to scan (default: current directory)"
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  -f, --force       Overwrite an existing .agenthub-config.yaml"
  echo "  -d, --dry-run     Print to stdout instead of writing"
  echo "  -h, --help        Show this help"
  echo ""
  echo -e "${BOLD}Detected shapes:${NC}"
  echo "  full-stack       backend + frontend"
  echo "  backend-only     server framework detected, no frontend"
  echo "  frontend-only    static site / client lib hitting external API"
  echo "  library          no server framework, no UI framework"
}

PROJECT_DIR=""
FORCE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)   FORCE=true; shift ;;
    -d|--dry-run) DRY_RUN=true; shift ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo -e "${RED}Unknown option: $1${NC}" >&2; usage; exit 1 ;;
    *)
      [[ -n "$PROJECT_DIR" ]] && { echo -e "${RED}Only one project path allowed${NC}" >&2; exit 1; }
      PROJECT_DIR="$1"; shift ;;
  esac
done

PROJECT_INPUT="${PROJECT_DIR:-$(pwd)}"
PROJECT_DIR="$(cd "$PROJECT_INPUT" 2>/dev/null && pwd)" || {
  echo -e "${RED}Project path does not exist: $PROJECT_INPUT${NC}" >&2
  exit 1
}

CONFIG_PATH="$PROJECT_DIR/.agenthub-config.yaml"

if [[ -f "$CONFIG_PATH" && "$FORCE" == false && "$DRY_RUN" == false ]]; then
  echo -e "${RED}$CONFIG_PATH already exists.${NC}" >&2
  echo "Use --force to overwrite, or --dry-run to preview." >&2
  exit 1
fi

# ----- helpers -----

has_dep_in_package_json() {
  local pkg="$1"
  [[ -f "$PROJECT_DIR/package.json" ]] || return 1
  grep -E "\"$pkg\"[[:space:]]*:" "$PROJECT_DIR/package.json" >/dev/null 2>&1
}

has_dir() { [[ -d "$PROJECT_DIR/$1" ]]; }

first_existing_dir() {
  for d in "$@"; do
    [[ -d "$PROJECT_DIR/$d" ]] && { echo "$d"; return; }
  done
  echo "$1"
}

# ----- language and framework -----

detect_language() {
  if   [[ -f "$PROJECT_DIR/pyproject.toml" || -f "$PROJECT_DIR/setup.py" || -f "$PROJECT_DIR/requirements.txt" ]]; then echo python
  elif [[ -f "$PROJECT_DIR/package.json" ]]; then echo node
  elif [[ -f "$PROJECT_DIR/Gemfile" ]]; then echo ruby
  elif [[ -f "$PROJECT_DIR/go.mod" ]]; then echo go
  elif [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then echo rust
  elif [[ -f "$PROJECT_DIR/pom.xml" || -f "$PROJECT_DIR/build.gradle" || -f "$PROJECT_DIR/build.gradle.kts" ]]; then echo java
  else echo unknown
  fi
}

detect_framework() {
  local lang="$1"
  case "$lang" in
    python)
      [[ -f "$PROJECT_DIR/pyproject.toml" ]] && { echo pyproject; return; }
      [[ -f "$PROJECT_DIR/setup.py" ]] && { echo setup.py; return; }
      [[ -f "$PROJECT_DIR/requirements.txt" ]] && { echo requirements; return; }
      echo unknown
      ;;
    node)
      [[ -f "$PROJECT_DIR/next.config.js"   || -f "$PROJECT_DIR/next.config.ts"   || -f "$PROJECT_DIR/next.config.mjs" ]] && { echo next; return; }
      [[ -f "$PROJECT_DIR/nuxt.config.js"   || -f "$PROJECT_DIR/nuxt.config.ts" ]] && { echo nuxt; return; }
      [[ -f "$PROJECT_DIR/astro.config.mjs" || -f "$PROJECT_DIR/astro.config.ts" ]] && { echo astro; return; }
      [[ -f "$PROJECT_DIR/vite.config.js"   || -f "$PROJECT_DIR/vite.config.ts"   || -f "$PROJECT_DIR/vite.config.mjs" ]] && { echo vite; return; }
      [[ -f "$PROJECT_DIR/svelte.config.js" ]] && { echo svelte; return; }
      echo node
      ;;
    *) echo "$lang" ;;
  esac
}

# ----- backend / frontend detection -----

detect_backend() {
  local lang="$1"
  case "$lang" in
    python|go|rust|java|ruby) return 0 ;;
    node)
      for dep in express koa fastify hapi @nestjs/core next nuxt astro remix; do
        has_dep_in_package_json "$dep" && return 0
      done
      for dir in src/server src/api backend server api app/api; do
        has_dir "$dir" && return 0
      done
      return 1
      ;;
    *)
      for dir in src/server backend api server; do has_dir "$dir" && return 0; done
      return 1
      ;;
  esac
}

detect_frontend() {
  local lang="$1"
  case "$lang" in
    node)
      for dep in react vue svelte @angular/core solid-js qwik lit preact next nuxt astro remix sveltekit; do
        has_dep_in_package_json "$dep" && return 0
      done
      for cfg in vite.config.js vite.config.ts vite.config.mjs next.config.js nuxt.config.js astro.config.mjs svelte.config.js; do
        [[ -f "$PROJECT_DIR/$cfg" ]] && return 0
      done
      for dir in src/web src/components src/client frontend web client; do
        has_dir "$dir" && return 0
      done
      return 1
      ;;
    *)
      for dir in frontend web client static/js; do has_dir "$dir" && return 0; done
      return 1
      ;;
  esac
}

find_server_framework() {
  local lang="$1"
  case "$lang" in
    python)
      grep -qiE "^(flask|fastapi|django|tornado|bottle|aiohttp|sanic|starlette)" "$PROJECT_DIR/requirements.txt" 2>/dev/null && return 0
      grep -qiE "\"?(flask|fastapi|django|tornado|bottle|aiohttp|sanic|starlette)\"?" "$PROJECT_DIR/pyproject.toml" 2>/dev/null && return 0
      return 1
      ;;
    go)
      grep -qE "gin-gonic|labstack/echo|gofiber|go-chi/chi|httprouter" "$PROJECT_DIR/go.mod" 2>/dev/null && return 0
      return 1
      ;;
    rust)
      grep -qE "axum|actix-web|warp|rocket|tide" "$PROJECT_DIR/Cargo.toml" 2>/dev/null && return 0
      return 1
      ;;
    ruby)
      grep -qE "rails|sinatra|hanami|roda" "$PROJECT_DIR/Gemfile" 2>/dev/null && return 0
      return 1
      ;;
    java)
      for f in pom.xml build.gradle build.gradle.kts; do
        [[ -f "$PROJECT_DIR/$f" ]] && grep -qE "spring-boot|micronaut|quarkus|jersey" "$PROJECT_DIR/$f" 2>/dev/null && return 0
      done
      return 1
      ;;
  esac
  return 1
}

derive_shape() {
  local has_be="$1" has_fe="$2" lang="$3"
  if   [[ "$has_be" == true  && "$has_fe" == true  ]]; then echo full-stack
  elif [[ "$has_be" == false && "$has_fe" == true  ]]; then echo frontend-only
  elif [[ "$has_be" == true  && "$has_fe" == false ]]; then
    if [[ "$lang" == node ]]; then
      for dep in next nuxt astro remix sveltekit; do
        has_dep_in_package_json "$dep" && { echo full-stack; return; }
      done
      echo backend-only
    else
      if find_server_framework "$lang"; then echo backend-only
      else echo library
      fi
    fi
  else
    echo library
  fi
}

# ----- test framework / folders / commands -----

detect_test_framework() {
  local lang="$1"
  case "$lang" in
    python)
      grep -qE "pytest" "$PROJECT_DIR/pyproject.toml" "$PROJECT_DIR/requirements.txt" 2>/dev/null && { echo pytest; return; }
      [[ -d "$PROJECT_DIR/tests" || -d "$PROJECT_DIR/test" ]] && { echo pytest; return; }
      echo unittest
      ;;
    node)
      for dep in playwright cypress vitest jest mocha; do
        has_dep_in_package_json "$dep" && { echo "$dep"; return; }
      done
      echo npm-test
      ;;
    go)    echo go-test ;;
    rust)  echo cargo-test ;;
    ruby)
      [[ -f "$PROJECT_DIR/Gemfile" ]] && grep -q "rspec" "$PROJECT_DIR/Gemfile" && { echo rspec; return; }
      echo minitest
      ;;
    java)  echo junit ;;
    *)     echo unknown ;;
  esac
}

suggest_backend_folder() {
  local lang="$1"
  case "$lang" in
    python)
      local proj_name
      proj_name=$(basename "$PROJECT_DIR")
      if [[ -d "$PROJECT_DIR/$proj_name" && -f "$PROJECT_DIR/$proj_name/__init__.py" ]]; then
        echo "$proj_name"
      elif [[ -d "$PROJECT_DIR/src" ]]; then
        echo src
      else
        local first
        first=$(find "$PROJECT_DIR" -maxdepth 2 -name __init__.py -not -path "*/test*" -not -path "*/venv/*" -not -path "*/.venv/*" 2>/dev/null | head -1)
        if [[ -n "$first" ]]; then dirname "$first" | sed "s|^$PROJECT_DIR/||"
        else echo src
        fi
      fi
      ;;
    node)  first_existing_dir src/server src/api backend server api src/backend src ;;
    go)    first_existing_dir cmd internal pkg ;;
    rust)  first_existing_dir src ;;
    ruby)  first_existing_dir app lib ;;
    java)  first_existing_dir src/main/java src ;;
    *)     first_existing_dir src lib ;;
  esac
}

suggest_frontend_folder() {
  first_existing_dir src/web src/components src/client frontend web client src
}

suggest_test_folder() {
  first_existing_dir tests test spec __tests__ src/tests
}

suggest_test_command() {
  case "$1" in
    python) echo "pytest" ;;
    node)   echo "npm test" ;;
    go)     echo "go test ./..." ;;
    rust)   echo "cargo test" ;;
    ruby)   echo "bundle exec rspec" ;;
    java)   echo "mvn test" ;;
    *)      echo "echo 'no test command configured'" ;;
  esac
}

suggest_typecheck_command() {
  case "$1" in
    python) echo "mypy ." ;;
    node)   echo "npm run typecheck" ;;
    go)     echo "go vet ./..." ;;
    rust)   echo "cargo check" ;;
    java)   echo "mvn compile" ;;
    *)      echo "" ;;
  esac
}

suggest_lint_command() {
  case "$1" in
    python) echo "ruff check" ;;
    node)   echo "npm run lint" ;;
    go)     echo "golangci-lint run" ;;
    rust)   echo "cargo clippy" ;;
    ruby)   echo "bundle exec rubocop" ;;
    java)   echo "mvn checkstyle:check" ;;
    *)      echo "" ;;
  esac
}

# ----- run detection -----

LANGUAGE=$(detect_language)
FRAMEWORK=$(detect_framework "$LANGUAGE")

HAS_BACKEND="false"
detect_backend "$LANGUAGE" && HAS_BACKEND="true"

HAS_FRONTEND="false"
detect_frontend "$LANGUAGE" && HAS_FRONTEND="true"

SHAPE=$(derive_shape "$HAS_BACKEND" "$HAS_FRONTEND" "$LANGUAGE")
TEST_FRAMEWORK=$(detect_test_framework "$LANGUAGE")

BACKEND_FOLDER=$(suggest_backend_folder "$LANGUAGE")
FRONTEND_FOLDER=$(suggest_frontend_folder)
TEST_FOLDER=$(suggest_test_folder)

TEST_CMD=$(suggest_test_command "$LANGUAGE")
TYPECHECK_CMD=$(suggest_typecheck_command "$LANGUAGE")
LINT_CMD=$(suggest_lint_command "$LANGUAGE")

# ----- summarize -----
echo "" >&2
echo -e "${BOLD}Agent Hub Project Detector${NC}" >&2
echo -e "Project:        ${CYAN}$PROJECT_DIR${NC}" >&2
echo -e "Language:       ${CYAN}$LANGUAGE${NC}" >&2
echo -e "Framework:      ${CYAN}$FRAMEWORK${NC}" >&2
echo -e "Shape:          ${CYAN}$SHAPE${NC}" >&2
echo -e "Test framework: ${CYAN}$TEST_FRAMEWORK${NC}" >&2
echo "" >&2

# ----- generate yaml -----
TODAY=$(date +%Y-%m-%d)

build_yaml() {
  cat <<EOF
# Auto-generated by agent-hub-detect.sh on $TODAY
# Edit freely. Re-run with --force to refresh from auto-detection.

project:
  # Which agents apply to this project:
  #   full-stack | backend-only | frontend-only | library
  shape: $SHAPE
  # Advisory hints — agents use these to pick conventions.
  language: $LANGUAGE
  framework: $FRAMEWORK
EOF

  if [[ "$SHAPE" != "frontend-only" ]]; then
    cat <<EOF

backend:
  folders:
    - $BACKEND_FOLDER
  test-command: $TEST_CMD
EOF
    [[ -n "$TYPECHECK_CMD" ]] && echo "  typecheck-command: $TYPECHECK_CMD"
    [[ -n "$LINT_CMD"      ]] && echo "  lint-command: $LINT_CMD"
  fi

  if [[ "$SHAPE" == "full-stack" || "$SHAPE" == "frontend-only" ]]; then
    cat <<EOF

frontend:
  folders:
    - $FRONTEND_FOLDER
  test-command: npm test
  typecheck-command: npm run typecheck
  lint-command: npm run lint
EOF
  else
    cat <<EOF

# Frontend section commented out — project shape is $SHAPE.
# Uncomment and adjust when adding a frontend.
# frontend:
#   folders:
#     - src/web
#   test-command: npm test
#   typecheck-command: npm run typecheck
#   lint-command: npm run lint
EOF
  fi

  cat <<EOF

test:
  folders:
    - $TEST_FOLDER
  acceptance-framework: $TEST_FRAMEWORK
  command: $TEST_CMD
EOF
}

YAML_CONTENT=$(build_yaml)

if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}(dry run — printed to stdout, no file written)${NC}" >&2
  echo "" >&2
  echo "$YAML_CONTENT"
else
  echo "$YAML_CONTENT" > "$CONFIG_PATH"
  echo -e "${GREEN}Wrote $CONFIG_PATH${NC}" >&2
  echo "" >&2
  echo -e "${BOLD}Next steps:${NC}" >&2
  echo "  1. Review the config and adjust folder/command lists if needed." >&2
  echo "  2. In Claude Code or Windsurf, run: /feature-factory <feature description>" >&2
fi
