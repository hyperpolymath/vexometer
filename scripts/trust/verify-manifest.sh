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

failed=0

for component in "${components[@]}"; do
  component_dir="$ROOT_DIR/$component"
  manifest="$component_dir/.trust/trust-manifest.sha256"

  if [[ ! -f "$manifest" ]]; then
    echo "missing trust manifest: $manifest" >&2
    echo "  fix: ./scripts/trust/generate-manifest.sh $component" >&2
    echo "  (or regenerate every component: just trust-generate)" >&2
    failed=1
    continue
  fi

  if output=$(cd "$component_dir" && sha256sum -c .trust/trust-manifest.sha256 2>&1); then
    echo "trust manifest verified: $component"
  else
    echo "trust manifest verification failed: $component" >&2
    # Show the drifted/missing entries and any unexpected diagnostics
    # (e.g. a corrupt manifest), but not the OK noise or sha256sum's
    # redundant WARNING summary line.
    grep -Ev ': OK$|^sha256sum: WARNING: ' <<<"$output" | sed 's/^/  /' >&2 || true
    echo "  fix: ./scripts/trust/generate-manifest.sh $component" >&2
    echo "  (or regenerate every component: just trust-generate)" >&2
    echo "  then commit the updated $component/.trust/trust-manifest.sha256 in the SAME PR" >&2
    failed=1
  fi
done

exit "$failed"
