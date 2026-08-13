#!/usr/bin/env sh
set -eu

# SafePaste pre-commit secret scan.
# This is a lightweight guard for obvious accidental credentials. It is not a
# comprehensive secret detection system and should be paired with review/tests.

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PROJECT_DIR="$ROOT_DIR/SafePaste"

if [ ! -d "$PROJECT_DIR" ]; then
  exit 0
fi

STAGED_FILES="$(git diff --cached --name-only --diff-filter=ACMR | grep '^SafePaste/' || true)"

if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

PATTERN='(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{20,}|-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|password[[:space:]]*[:=][[:space:]]*["'\'']?[^"'\'']{8,}|api[_-]?key[[:space:]]*[:=][[:space:]]*["'\'']?[A-Za-z0-9_./+=-]{16,})'

FOUND=0

for file in $STAGED_FILES; do
  case "$file" in
    *.png|*.jpg|*.jpeg|*.gif|*.ico|*.pdf|*.zip)
      continue
      ;;
  esac

  if git show ":$file" 2>/dev/null | grep -E -n "$PATTERN" >/tmp/safepaste-secret-scan.txt 2>/dev/null; then
    echo "SafePaste pre-commit hook: possible secret in $file"
    cat /tmp/safepaste-secret-scan.txt
    FOUND=1
  fi
done

rm -f /tmp/safepaste-secret-scan.txt

if [ "$FOUND" -ne 0 ]; then
  echo "Commit blocked. Review the flagged values or document why they are harmless test fixtures."
  exit 1
fi

exit 0
