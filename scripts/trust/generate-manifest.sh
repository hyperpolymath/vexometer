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
  component_dir="$ROOT_DIR/$component"
  manifest_dir="$component_dir/.trust"
  manifest="$manifest_dir/trust-manifest.sha256"

  if [[ ! -d "$component_dir" ]]; then
    echo "missing component directory: $component" >&2
    exit 1
  fi

  inputs=(
    "README.adoc"
    "ROADMAP.adoc"
    "SECURITY.adoc"
    "contractiles/must/Mustfile"
    "contractiles/trust/Trustfile.a2ml"
  )

  if [[ -f "$component_dir/contractiles/dust/Dustfile" ]]; then
    inputs+=("contractiles/dust/Dustfile")
  fi
  if [[ -f "$component_dir/RSR_OUTLINE.adoc" ]]; then
    inputs+=("RSR_OUTLINE.adoc")
  fi
  if [[ -f "$component_dir/docs/CITATIONS.adoc" ]]; then
    inputs+=("docs/CITATIONS.adoc")
  fi

  mkdir -p "$manifest_dir"

  {
    echo "# trust-manifest v1"
    echo "# component=$component"
    echo "# generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    (cd "$component_dir" && sha256sum "${inputs[@]}")
  } > "$manifest"

  echo "wrote $manifest"
done
