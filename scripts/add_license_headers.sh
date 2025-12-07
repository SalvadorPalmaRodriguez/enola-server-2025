#!/usr/bin/env bash
set -euo pipefail
# Adds license header (scripts/license_header.txt) to all executable shell scripts under the repo's scripts/ and enola/ directories.
# Dry-run by default. Use --apply to write changes.

DRY_RUN=1
if [[ "${1:-}" == "--apply" ]]; then
  DRY_RUN=0
fi

HEADER_FILE="$(dirname "$0")/license_header.txt"
if [[ ! -f "$HEADER_FILE" ]]; then
  echo "Header file not found: $HEADER_FILE"
  exit 2
fi

echo "Header source: $HEADER_FILE"

find_targets=("./scripts" "./enola" )

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

for dir in "${find_targets[@]}"; do
  if [[ ! -d "$dir" ]]; then
    continue
  fi
  while IFS= read -r -d '' file; do
    # Only act on shell scripts (shebang) and executable files
    if head -n1 "$file" | grep -qE '^#!.*(sh|bash)'; then
      echo "Processing: $file"
      if grep -qF "Licensed under: ENOLA SERVER" "$file" 2>/dev/null || grep -qF "Copyright (c) 2025" "$file" 2>/dev/null; then
        echo "  -> Already contains header, skipping"
        continue
      fi
      if [[ $DRY_RUN -eq 1 ]]; then
        echo "  -> [dry-run] Would prepend header to $file"
      else
        echo "  -> Prepending header to $file"
        cat "$HEADER_FILE" > "$tmpfile"
        echo "" >> "$tmpfile"
        cat "$file" >> "$tmpfile"
        mv "$tmpfile" "$file"
        chmod +x "$file"
      fi
    fi
  done < <(find "$dir" -type f -perm /u=x,g=x,o=x -print0)
done

echo "Done. Dry-run: $DRY_RUN (use --apply to modify files)"
