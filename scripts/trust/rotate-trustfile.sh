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

generated_date="$(date -u +%Y-%m-%d)"
generated="${generated_date}T00:00:00Z"
expires="$(date -u -d "$generated_date +1 year" +%Y-%m-%dT00:00:00Z)"
version="$(date -u +%Y.%m)"

for component in "${components[@]}"; do
  trustfile="$ROOT_DIR/$component/contractiles/trust/Trustfile.a2ml"

  if [[ ! -f "$trustfile" ]]; then
    echo "missing trustfile: $trustfile" >&2
    exit 1
  fi

  sed -i -E "s/^version: \".*\"$/version: \"$version\"/" "$trustfile"
  sed -i -E "s/^  generated: \".*\"$/  generated: \"$generated\"/" "$trustfile"
  sed -i -E "s/^  expires: \".*\"$/  expires: \"$expires\"/" "$trustfile"

  echo "rotated trustfile metadata: $trustfile"
done

"$ROOT_DIR/scripts/trust/generate-manifest.sh" "${components[@]}"
