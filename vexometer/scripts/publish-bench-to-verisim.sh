#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <benchmark-json-path>" >&2
  exit 1
fi

JSON_PATH="$1"
API_URL="${VERISIM_API_URL:-http://127.0.0.1:18080/api/v1}"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ENTITY_ID="vexometer-benchmark-${TIMESTAMP//[:T-]/}"

if [[ ! -f "$JSON_PATH" ]]; then
  echo "benchmark json not found: $JSON_PATH" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl not found" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found" >&2
  exit 1
fi

PAYLOAD_FILE="$(mktemp)"
trap 'rm -f "$PAYLOAD_FILE"' EXIT

jq -n \
  --arg id "$ENTITY_ID" \
  --arg ts "$TIMESTAMP" \
  --slurpfile summary "$JSON_PATH" '
  {
    id: $id,
    category: "benchmark",
    document: {
      title: "ISA benchmark run",
      content: ($summary[0] | tostring),
      tags: ["isa", "vexometer", "benchmark", "dogfood"]
    },
    graph: { edges: [] },
    vector: {
      embedding: [
        (($summary[0].analysis_cases | map(.avg_ms) | add) / ($summary[0].analysis_cases | length)),
        (($summary[0].analysis_cases | map(.isa_mean) | add) / ($summary[0].analysis_cases | length)),
        ($summary[0].loader_benchmarks.patterns_load_avg_ms // 0)
      ]
    },
    semantic: {
      types: ["https://hyperpolymath.dev/schema/ISABenchmarkRun"],
      properties: {
        tool: "vexometer",
        schema: ($summary[0].schema // "vexometer-benchmark-v1"),
        backend: ($summary[0].database_backend // "verisimdb")
      }
    },
    temporal: {
      created: $ts,
      modified: $ts,
      version: 1
    },
    provenance: {
      origin: "vexometer/scripts/run-benchmarks.sh",
      actor: "dogfood-runner",
      chain: ["benchmark", "isa", "verisimdb"]
    },
    spatial: {
      lat: 51.5074,
      lon: -0.1278,
      label: "local-dogfood"
    }
  }
' > "$PAYLOAD_FILE"

if curl -sf -X POST "$API_URL/hexads" \
  -H "Content-Type: application/json" \
  -d @"$PAYLOAD_FILE" >/dev/null; then
  echo "published benchmark to verisimdb: $ENTITY_ID"
else
  echo "failed to publish benchmark to verisimdb at $API_URL" >&2
  exit 1
fi
