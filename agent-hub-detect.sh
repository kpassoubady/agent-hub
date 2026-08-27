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
  # Prints the first candidate that exists as a real directory, or nothing
  # (empty string) if none exist. Callers must handle the empty case —
  # never fall back to a candidate name that hasn't been confirmed to exist,
  # since that produces a config pointing at a folder the project doesn't have.
  # Always exits 0: under `set -e`, a failing status from the last `[[ ]]`
  # check would otherwise abort the whole script when nothing matches.
  for d in "$@"; do
    [[ -d "$PROJECT_DIR/$d" ]] && { echo "$d"; return 0; }
  done
  return 0
}

# ----- language and framework -----

has_glob() {
  # Returns 0 if any file matching the glob exists in $PROJECT_DIR (non-recursive).
  compgen -G "$PROJECT_DIR/$1" >/dev/null 2>&1
}

has_dotnet_files() {
  for ext in sln slnx csproj fsproj vbproj; do
    has_glob "*.$ext" && return 0
    if find "$PROJECT_DIR" -maxdepth 3 -name "*.$ext" -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -1 | grep -q .; then
      return 0
    fi
  done
  return 1
}

detect_language() {
  if   [[ -f "$PROJECT_DIR/pyproject.toml" || -f "$PROJECT_DIR/setup.py" || -f "$PROJECT_DIR/requirements.txt" ]]; then echo python
  elif [[ -f "$PROJECT_DIR/package.json" ]]; then echo node
  elif [[ -f "$PROJECT_DIR/Gemfile" ]]; then echo ruby
  elif [[ -f "$PROJECT_DIR/go.mod" ]]; then echo go
  elif [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then echo rust
  elif [[ -f "$PROJECT_DIR/pom.xml" || -f "$PROJECT_DIR/build.gradle" || -f "$PROJECT_DIR/build.gradle.kts" ]]; then echo java
  elif has_dotnet_files; then echo dotnet
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
    dotnet)
      if find "$PROJECT_DIR" -maxdepth 3 -name "*.csproj" -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -5 | xargs grep -l "Microsoft.AspNetCore" 2>/dev/null | head -1 | grep -q .; then
        echo aspnetcore
      elif find "$PROJECT_DIR" -maxdepth 3 -name "*.fsproj" -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -1 | grep -q .; then
        echo fsharp
      elif find "$PROJECT_DIR" -maxdepth 3 -name "*.csproj" -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -1 | grep -q .; then
        echo csharp
      else
        echo dotnet
      fi
      ;;
    *) echo "$lang" ;;
  esac
}

# ----- backend / frontend detection -----

detect_backend() {
  local lang="$1"
  case "$lang" in
    python|go|rust|java|ruby|dotnet) return 0 ;;
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
      for dir in src/web src/components src/client frontend web client static templates; do
        has_dir "$dir" && return 0
      done
      return 1
      ;;
    dotnet)
      # Blazor/MAUI-style solutions: a root-level *.Client / *.WebClient / *.UI
      # project folder, rather than a fixed dir name.
      [[ -n "$(dotnet_project_dirs '\.(client|webclient|ui)$' | head -1)" ]] && return 0
      for dir in frontend web client static/js; do has_dir "$dir" && return 0; done
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
    dotnet)
      find "$PROJECT_DIR" -maxdepth 3 -name "*.csproj" -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -10 | xargs grep -lE "Microsoft.AspNetCore|Microsoft.NET.Sdk.Web" 2>/dev/null | head -1 | grep -q . && return 0
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
    dotnet)
      find "$PROJECT_DIR" -maxdepth 3 -name "*.csproj" -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -10 | xargs grep -l "xunit" 2>/dev/null | head -1 | grep -q . && { echo xunit; return; }
      find "$PROJECT_DIR" -maxdepth 3 -name "*.csproj" -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -10 | xargs grep -l "NUnit" 2>/dev/null | head -1 | grep -q . && { echo nunit; return; }
      echo dotnet-test
      ;;
    *)     echo unknown ;;
  esac
}

# dotnet solutions commonly have no top-level `src/` at all — each project
# lives in its own root-level folder (e.g. RecipeApp.Api, RecipeApp.Client).
# List root-level dirs that contain a .csproj/.fsproj, split by naming
# convention so backend/frontend/test projects can be told apart.
dotnet_project_dirs() {
  # dotnet_project_dirs SUFFIX_REGEX -> matching root-level project dirs, one per line
  local suffix_regex="$1" dir base
  find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | while IFS= read -r dir; do
    base=$(basename "$dir")
    compgen -G "$dir/*.csproj" >/dev/null 2>&1 || compgen -G "$dir/*.fsproj" >/dev/null 2>&1 || continue
    [[ -n "$suffix_regex" ]] && ! echo "$base" | grep -qiE "$suffix_regex" && continue
    echo "$base"
  done
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
        if [[ -n "$first" ]]; then
          dirname "$first" | sed "s|^$PROJECT_DIR/||"
        elif compgen -G "$PROJECT_DIR/*.py" >/dev/null 2>&1; then
          # Script-style project with .py files at the root.
          echo "."
        else
          echo src
        fi
      fi
      ;;
    node)   first_existing_dir src/server src/api backend server api src/backend src ;;
    go)     first_existing_dir cmd internal pkg ;;
    rust)   first_existing_dir src ;;
    ruby)   first_existing_dir app lib ;;
    java)   first_existing_dir src/main/java src ;;
    dotnet)
      local d
      d=$(first_existing_dir src)
      if [[ -n "$d" ]]; then
        echo "$d"
      else
        # No src/ dir: fall back to root-level *.csproj project folders,
        # excluding ones that look like the client/shared/test projects.
        # `|| true`: grep exits 1 when every project looks like client/shared/
        # test-only, and pipefail would otherwise abort the whole script.
        dotnet_project_dirs '' | grep -viE '\.(client|web(client)?|ui|shared|tests?)$' || true
      fi
      ;;
    *)      first_existing_dir src lib ;;
  esac
}

suggest_frontend_folder() {
  local lang="$1"
  if [[ "$lang" == dotnet ]]; then
    dotnet_project_dirs '\.(client|webclient|ui)$' | head -1
    return
  fi
  first_existing_dir src/web src/components src/client frontend web client static templates
}

suggest_test_folder() {
  local lang="$1"
  case "$lang" in
    java)   first_existing_dir src/test/java tests test ;;
    dotnet) first_existing_dir tests test ;;
    *)      first_existing_dir tests test spec __tests__ src/tests ;;
  esac
}

suggest_test_command() {
  case "$1" in
    python) echo "pytest" ;;
    node)   echo "npm test" ;;
    go)     echo "go test ./..." ;;
    rust)   echo "cargo test" ;;
    ruby)   echo "bundle exec rspec" ;;
    java)
      [[ -f "$PROJECT_DIR/build.gradle" || -f "$PROJECT_DIR/build.gradle.kts" ]] && { echo "./gradlew test"; return; }
      echo "mvn test"
      ;;
    dotnet) echo "dotnet test" ;;
    *)      echo "echo 'no test command configured'" ;;
  esac
}

suggest_typecheck_command() {
  case "$1" in
    python) echo "mypy ." ;;
    node)   echo "npm run typecheck" ;;
    go)     echo "go vet ./..." ;;
    rust)   echo "cargo check" ;;
    java)
      [[ -f "$PROJECT_DIR/build.gradle" || -f "$PROJECT_DIR/build.gradle.kts" ]] && { echo "./gradlew compileJava"; return; }
      echo "mvn compile"
      ;;
    dotnet) echo "dotnet build --no-restore" ;;
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
    dotnet) echo "dotnet format --verify-no-changes" ;;
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

# suggest_backend_folder can print multiple lines (dotnet multi-project
# solutions with no top-level src/). Collect all of them; BACKEND_FOLDER holds
# just the first, for the overlap checks below which reason about one path.
BACKEND_FOLDERS_DETECTED=()
while IFS= read -r line; do
  [[ -n "$line" ]] && BACKEND_FOLDERS_DETECTED+=("$line")
done < <(suggest_backend_folder "$LANGUAGE")
BACKEND_FOLDER="${BACKEND_FOLDERS_DETECTED[0]:-}"

FRONTEND_FOLDER=$(suggest_frontend_folder "$LANGUAGE")
TEST_FOLDER=$(suggest_test_folder "$LANGUAGE")

# ----- resolve backend/frontend scope overlap -----
# backend.folders and frontend.folders are HARD scope restrictions for their
# builders. If one is nested inside the other, the outer builder is authorised
# to edit the inner one's files. feature-factory's Step 0 gate rejects such a
# config, so never emit one. Narrow the outer side to concrete subfolders.
#
# The common case is a full-stack framework where a single tree (src, or
# Next.js src/app) holds both halves.
is_nested_path() {
  # is_nested_path CHILD PARENT -> 0 when CHILD is inside PARENT
  [[ "$1" != "$2" && "$1" == "$2"/* ]]
}

narrow_backend_folders() {
  # Emit backend folders that exclude the frontend folder. Prefer real
  # framework subfolders; fall back to the sibling dirs of the frontend folder.
  local be="$1" fe="$2" out=()
  for cand in "$be/api" "$be/app/api" "$be/server" "$be/lib" "$be/utils" "$be/services" "$be/db"; do
    [[ -d "$PROJECT_DIR/$cand" ]] && out+=("$cand")
  done
  if [[ ${#out[@]} -eq 0 ]]; then
    # No conventional backend subfolder: take every child of $be except $fe.
    local child rel
    while IFS= read -r child; do
      rel="${child#"$PROJECT_DIR"/}"
      [[ "$rel" == "$fe" ]] && continue
      is_nested_path "$fe" "$rel" && continue
      out+=("$rel")
    done < <(find "$PROJECT_DIR/$be" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  fi
  # Guard the empty case: under bash 3.2, "${out[@]}" on an empty array with
  # `set -u` errors, and printf would otherwise emit one blank line.
  [[ ${#out[@]} -eq 0 ]] && return 0
  printf '%s\n' "${out[@]}"
}

if [[ ${#BACKEND_FOLDERS_DETECTED[@]} -gt 0 ]]; then
  BACKEND_FOLDERS=("${BACKEND_FOLDERS_DETECTED[@]}")
else
  BACKEND_FOLDERS=()
fi
if [[ -n "$FRONTEND_FOLDER" ]]; then
  FRONTEND_FOLDERS=("$FRONTEND_FOLDER")
else
  FRONTEND_FOLDERS=()
fi
OVERLAP_NOTE=""

if [[ "$HAS_BACKEND" == true && "$HAS_FRONTEND" == true && -n "$BACKEND_FOLDER" && -n "$FRONTEND_FOLDER" ]]; then
  if is_nested_path "$FRONTEND_FOLDER" "$BACKEND_FOLDER"; then
    # bash 3.2 (macOS default) has no mapfile — read line-by-line instead.
    narrowed=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && narrowed+=("$line")
    done < <(narrow_backend_folders "$BACKEND_FOLDER" "$FRONTEND_FOLDER")
    if [[ ${#narrowed[@]} -gt 0 ]]; then
      BACKEND_FOLDERS=("${narrowed[@]}")
      OVERLAP_NOTE="# NOTE: '$FRONTEND_FOLDER' sits inside '$BACKEND_FOLDER'. Backend scope was
# narrowed to the folders below so the two builders do not overlap. Review it —
# add any backend folder that was missed, and see frontend.files for shell files."
    else
      OVERLAP_NOTE="# WARNING: '$FRONTEND_FOLDER' sits inside '$BACKEND_FOLDER' and no backend
# subfolder could be derived. Split these by hand before running the factory —
# feature-factory's Step 0 gate rejects overlapping backend/frontend scopes."
    fi
  elif is_nested_path "$BACKEND_FOLDER" "$FRONTEND_FOLDER"; then
    OVERLAP_NOTE="# WARNING: '$BACKEND_FOLDER' sits inside '$FRONTEND_FOLDER'. Narrow
# frontend.folders by hand (list its real subfolders, or move the shared shell
# files to frontend.files) — Step 0 rejects overlapping scopes."
  fi
fi

# Next.js App Router: src/app holds both api/ routes and the page shell. List
# the shell files individually so src/app/api stays outside frontend scope.
FRONTEND_FILES=()
if [[ "$FRAMEWORK" == next ]]; then
  for shell in page.tsx page.jsx layout.tsx layout.jsx globals.css; do
    for base in src/app app; do
      [[ -f "$PROJECT_DIR/$base/$shell" ]] && FRONTEND_FILES+=("$base/$shell")
    done
  done
fi

TEST_CMD=$(suggest_test_command "$LANGUAGE")
TYPECHECK_CMD=$(suggest_typecheck_command "$LANGUAGE")
LINT_CMD=$(suggest_lint_command "$LANGUAGE")

# ----- flag folders that could not be confirmed -----
# suggest_*_folder now returns empty rather than a guessed name when nothing
# on disk matches. That means the project's layout doesn't follow the naming
# conventions this detector knows about — common for a POC/MVP repo that grew
# organically. Surface it instead of silently emitting a folder that doesn't
# exist.
UNCONFIRMED_NOTE=""
missing_sections=()
[[ "$HAS_BACKEND" == true && ${#BACKEND_FOLDERS[@]} -eq 0 ]] && missing_sections+=("backend.folders")
[[ "$HAS_FRONTEND" == true && -z "$FRONTEND_FOLDER" ]] && missing_sections+=("frontend.folders")
[[ -z "$TEST_FOLDER" ]] && missing_sections+=("test.folders")

if [[ ${#missing_sections[@]} -gt 0 ]]; then
  joined=$(printf '%s, ' "${missing_sections[@]}")
  joined="${joined%, }"
  UNCONFIRMED_NOTE="# WARNING: could not confirm a folder for: $joined.
# This project's layout doesn't match a standard convention for $LANGUAGE
# (common in POC/MVP repos that grew ad hoc). Fill in the placeholder(s)
# below by hand — do NOT leave a guessed path that doesn't exist on disk.
# For anything beyond a small addition, consider restructuring into a
# conventional layout (e.g. src/ or server/+client/) before running
# /feature-factory — builders scope themselves strictly to these folders,
# so an unclear layout leads to unclear or incorrect edits."
fi

# ----- summarize -----
echo "" >&2
echo -e "${BOLD}Agent Hub Project Detector${NC}" >&2
echo -e "Project:        ${CYAN}$PROJECT_DIR${NC}" >&2
echo -e "Language:       ${CYAN}$LANGUAGE${NC}" >&2
echo -e "Framework:      ${CYAN}$FRAMEWORK${NC}" >&2
echo -e "Shape:          ${CYAN}$SHAPE${NC}" >&2
echo -e "Test framework: ${CYAN}$TEST_FRAMEWORK${NC}" >&2
echo "" >&2

if [[ -n "$UNCONFIRMED_NOTE" ]]; then
  echo -e "${YELLOW}Could not confirm a real folder for: $joined${NC}" >&2
  echo -e "${YELLOW}This layout doesn't match a standard $LANGUAGE convention — see the${NC}" >&2
  echo -e "${YELLOW}WARNING comment in the generated config for what to do next.${NC}" >&2
  echo "" >&2
fi

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

  if [[ -n "$OVERLAP_NOTE" ]]; then
    echo ""
    echo "$OVERLAP_NOTE"
  fi

  if [[ -n "$UNCONFIRMED_NOTE" ]]; then
    echo ""
    echo "$UNCONFIRMED_NOTE"
  fi

  if [[ "$SHAPE" != "frontend-only" ]]; then
    echo ""
    echo "backend:"
    echo "  folders:"
    if [[ ${#BACKEND_FOLDERS[@]} -gt 0 ]]; then
      for f in "${BACKEND_FOLDERS[@]}"; do echo "    - $f"; done
    else
      echo "    - REPLACE_ME  # no backend folder could be confirmed — see WARNING above"
    fi
    echo "  test-command: $TEST_CMD"
    [[ -n "$TYPECHECK_CMD" ]] && echo "  typecheck-command: $TYPECHECK_CMD"
    [[ -n "$LINT_CMD"      ]] && echo "  lint-command: $LINT_CMD"
  fi

  if [[ "$SHAPE" == "full-stack" || "$SHAPE" == "frontend-only" ]]; then
    echo ""
    echo "frontend:"
    echo "  folders:"
    if [[ ${#FRONTEND_FOLDERS[@]} -gt 0 ]]; then
      for f in "${FRONTEND_FOLDERS[@]}"; do echo "    - $f"; done
    else
      echo "    - REPLACE_ME  # no frontend folder could be confirmed — see WARNING above"
    fi
    if [[ ${#FRONTEND_FILES[@]} -gt 0 ]]; then
      echo "  # Frontend-owned files inside a folder the backend also uses"
      echo "  # (Next.js src/app holds both api/ routes and the page shell)."
      echo "  files:"
      for f in "${FRONTEND_FILES[@]}"; do echo "    - $f"; done
    fi
    echo "  test-command: npm test"
    echo "  typecheck-command: npm run typecheck"
    echo "  lint-command: npm run lint"
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

  echo ""
  echo "test:"
  echo "  folders:"
  if [[ -n "$TEST_FOLDER" ]]; then
    echo "    - $TEST_FOLDER"
  else
    echo "    - REPLACE_ME  # no test folder could be confirmed — see WARNING above"
  fi
  echo "  acceptance-framework: $TEST_FRAMEWORK"
  echo "  command: $TEST_CMD"
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
  if [[ -n "$UNCONFIRMED_NOTE" ]] && printf '%s' "$joined" | grep -q "test\."; then
    echo "  2. No real test setup detected — run /test-bootstrap first." >&2
    echo "  3. In Claude Code or Devin, run: /feature-factory <feature description>" >&2
  else
    echo "  2. In Claude Code or Devin, run: /feature-factory <feature description>" >&2
  fi
fi
