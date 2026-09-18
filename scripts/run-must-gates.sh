#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

for component in "${components[@]}"; do
  echo "== must-gate: $component =="
  component_dir="$ROOT_DIR/$component"
  mustfile="$component_dir/contractiles/must/Mustfile"
  manifest="$component_dir/.trust/trust-manifest.sha256"

  test -f "$mustfile"
  test -f "$component_dir/README.adoc"
  test -f "$component_dir/ROADMAP.adoc"
  test -f "$component_dir/SECURITY.adoc"
  test -f "$component_dir/contractiles/trust/Trustfile.a2ml"
  test -f "$manifest"

  rg -n "security@|security/advisories/new" "$component_dir/SECURITY.adoc" >/dev/null
  (cd "$component_dir" && sha256sum -c .trust/trust-manifest.sha256 >/dev/null)

  files=(
    "$component_dir/README.adoc"
    "$component_dir/ROADMAP.adoc"
    "$component_dir/SECURITY.adoc"
  )

  if [[ -f "$component_dir/RSR_OUTLINE.adoc" ]]; then
    files+=("$component_dir/RSR_OUTLINE.adoc")
  fi
  if [[ -f "$component_dir/docs/CITATIONS.adoc" ]]; then
    files+=("$component_dir/docs/CITATIONS.adoc")
  fi

  if rg -n "rsr-template-repo|\\{\\{PROJECT\\}\\}|contents of Trustfile here" "${files[@]}" >/dev/null; then
    echo "template drift detected in $component" >&2
    exit 1
  fi

done

echo "all must gates passed"
