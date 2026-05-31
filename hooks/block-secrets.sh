#!/usr/bin/env bash
# block-secrets.sh — pre-commit hook that refuses to commit files and content
# that look like secrets.
#
# Install in a project:
#   cp <hub>/hooks/block-secrets.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# Or symlink so hub updates flow in automatically:
#   ln -sf <hub>/hooks/block-secrets.sh .git/hooks/pre-commit
#
# If a block is a false positive, review the file, then commit with --no-verify.

set -euo pipefail

staged=$(git diff --cached --name-only --diff-filter=ACM)
if [[ -z "$staged" ]]; then
  exit 0
fi

# Block by filename pattern.
blocked=()
while IFS= read -r file; do
  case "$file" in
    .env.example|.env.sample) continue ;;
    .env|.env.*|*.key|*.pem|*.pfx|*.p12|credentials.*|secrets.*|*.tfstate|*.tfstate.backup)
      blocked+=("$file")
      ;;
  esac
done <<< "$staged"

if (( ${#blocked[@]} > 0 )); then
  echo "block-secrets: refusing to commit files that look like secrets:" >&2
  for f in "${blocked[@]}"; do
    echo "  - $f" >&2
  done
  echo "Review the file. If intentional, commit with --no-verify." >&2
  exit 1
fi

# Block by content pattern in the staged diff.
diff=$(git diff --cached --no-color)
fail=0

match() {
  local name="$1" pattern="$2"
  if echo "$diff" | grep -E -q "$pattern"; then
    echo "block-secrets: detected $name in the staged diff." >&2
    echo "  pattern: $pattern" >&2
    fail=1
  fi
}

match "AWS access key"   'AKIA[0-9A-Z]{16}'
match "PEM private key"  '-----BEGIN (RSA |EC |OPENSSH |DSA |)PRIVATE KEY-----'
match "GitHub token"     '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}'
match "Slack token"      'xox[abprs]-[0-9a-zA-Z-]{10,}'
match "generic API key"  '(api[_-]?key|apikey)["'\'']?[[:space:]]*[:=][[:space:]]*["'\''][A-Za-z0-9_\-]{20,}["'\'']'

if (( fail )); then
  echo "Aborting commit. Review the listed pattern; commit with --no-verify only if intentional." >&2
  exit 1
fi

exit 0
