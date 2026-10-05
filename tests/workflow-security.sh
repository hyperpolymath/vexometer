#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
checker="$root/scripts/check-workflow-security.sh"
expect_failure() {
  if bash "$checker" "$tmp" > "$tmp/result" 2>&1; then
    echo "FAIL: $1 was accepted" >&2
    exit 1
  fi
}
expect_failure 'empty workflow directory'
cat > "$tmp/test.yml" <<'YAML'
# SPDX-License-Identifier: MPL-2.0
permissions: {contents: read}
jobs:
  lint:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
      - uses: ./local-action
YAML
bash "$checker" "$tmp"
sed -i '1i# This workflow is managed by gh actions-lock.' "$tmp/test.yml"
expect_failure 'displaced SPDX header'
sed -i '1d' "$tmp/test.yml"
sed -i '/^permissions:/d' "$tmp/test.yml"
expect_failure 'missing permissions'
sed -i '2i permissions: read-all' "$tmp/test.yml"
sed -i 's/@3d3c42e5aac5ba805825da76410c181273ba90b1/@v7.0.1 # a comment is not a pin/' "$tmp/test.yml"
expect_failure 'tagged step action with comment'
cat > "$tmp/test.yml" <<'YAML'
# SPDX-License-Identifier: MPL-2.0
permissions: {contents: read}
jobs:
  shared:
    uses: 'owner/repo/.github/workflows/check.yml@main'
YAML
expect_failure 'quoted unpinned reusable workflow'
sed -i 's/@main/@3d3c42e5aac5ba805825da76410c181273ba90b1/' "$tmp/test.yml"
mv "$tmp/test.yml" "$tmp/test.yaml"
bash "$checker" "$tmp"
echo 'Workflow security regression tests passed'
