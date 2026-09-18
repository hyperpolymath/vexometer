#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ $# -gt 0 ]]; then
  components=("$@")
else
  components=(
    "vexometer"
    "vext"
    "vext-email-gateway"
    "vexometer-satellites"
    "lazy-eliminator"
    "vexometer-efficacy"
    "verbosity-compressor"
    "satellite-template"
  )
fi

for component in "${components[@]}"; do
  manifest="$ROOT_DIR/$component/.trust/trust-manifest.sha256"

  if [[ ! -f "$manifest" ]]; then
    echo "missing trust manifest: $manifest" >&2
    exit 1
  fi

  if command -v minisign >/dev/null 2>&1; then
    minisign -Sm "$manifest"
    echo "signed with minisign: $manifest.minisig"
  elif command -v gpg >/dev/null 2>&1; then
    gpg --armor --detach-sign --yes -o "$manifest.asc" "$manifest"
    echo "signed with gpg: $manifest.asc"
  else
    echo "no signing tool found (expected minisign or gpg)" >&2
    exit 1
  fi
done
