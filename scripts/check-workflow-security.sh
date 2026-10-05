#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Keep first-line licensing, explicit permissions and immutable action refs mandatory.
set -euo pipefail
workflow_dir="${1:-.github/workflows}"
shopt -s nullglob
files=("$workflow_dir"/*.yml "$workflow_dir"/*.yaml)
if ((${#files[@]} == 0)); then
  echo "ERROR: no workflows found in $workflow_dir" >&2
  exit 1
fi
failed=0
for file in "${files[@]}"; do
  if ! head -1 "$file" | grep -q '^# SPDX-License-Identifier:'; then
    echo "ERROR: $file missing first-line SPDX header"
    failed=1
  fi
  if ! grep -q '^permissions:' "$file"; then
    echo "ERROR: $file missing top-level permissions declaration"
    failed=1
  fi
  # Match both step-level and job-level uses, including quoted scalar refs.
  while IFS= read -r ref; do
    case "$ref" in
      ./*) continue ;;
      docker://*@sha256:*)
        if [[ "$ref" =~ @sha256:[a-f0-9]{64}$ ]]; then continue; fi ;;
      *)
        if [[ "$ref" =~ @[a-f0-9]{40}$ ]]; then continue; fi ;;
    esac
    echo "ERROR: $file has unpinned action: $ref"
    failed=1
  done < <(sed -nE "s/^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*['\"]?([^'\"[:space:]#]+).*/\2/p" "$file")
done
if ((failed)); then exit 1; fi
echo 'All workflows have first-line SPDX headers, permissions and immutable action refs'
