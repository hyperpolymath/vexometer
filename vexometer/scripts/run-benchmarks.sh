#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/benchmarks/results"
LATEST_JSON="$RESULTS_DIR/latest.json"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
STAMPED_JSON="$RESULTS_DIR/$TIMESTAMP.json"
PROFILE_FILE="${VEXOMETER_VERISIM_PROFILE_FILE:-$ROOT_DIR/config/verisim-profile.env}"

LOCAL_VERISIM_STARTED=0
LOCAL_VERISIM_PID=""
LOCAL_VERISIM_LOG=""

log_info() {
  echo "$*"
}

log_warn() {
  echo "$*" >&2
}

load_profile() {
  if [[ "${VEXOMETER_BENCH_USE_PROFILE:-1}" != "1" ]]; then
    return
  fi

  if [[ -f "$PROFILE_FILE" ]]; then
    while IFS='=' read -r raw_key raw_value; do
      if [[ -z "$raw_key" ]]; then
        continue
      fi
      if [[ "$raw_key" =~ ^[[:space:]]*# ]]; then
        continue
      fi
      if [[ ! "$raw_key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        continue
      fi

      local key
      key="$(printf '%s' "$raw_key" | tr -d '[:space:]')"
      local value="$raw_value"

      if [[ -z "${!key+x}" ]]; then
        export "$key=$value"
      fi
    done < <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$PROFILE_FILE" || true)

    log_info "using verisim profile: $PROFILE_FILE"
  fi
}

find_free_port() {
  local host="$1"
  local min_port="$2"
  local max_port="$3"
  local port=""

  if (( min_port <= 0 || max_port <= 0 || min_port > max_port )); then
    return 1
  fi

  for port in $(seq "$min_port" "$max_port"); do
    if ! (echo >"/dev/tcp/$host/$port") >/dev/null 2>&1; then
      echo "$port"
      return 0
    fi
  done

  return 1
}

detect_verisim_home() {
  local candidate=""

  if [[ -n "${VERISIM_HOME:-}" ]]; then
    candidate="$VERISIM_HOME"
    if [[ -f "$candidate/justfile" ]]; then
      (cd "$candidate" && pwd)
      return 0
    fi
  fi

  for candidate in \
    "$ROOT_DIR/../../nextgen-databases/verisimdb" \
    "$ROOT_DIR/../../verisimdb" \
    "$ROOT_DIR/../verisimdb"
  do
    if [[ -f "$candidate/justfile" ]]; then
      (cd "$candidate" && pwd)
      return 0
    fi
  done

  return 1
}

resolve_verisim_launch_cmd() {
  if [[ -n "${VERISIM_API_CMD:-}" ]]; then
    printf '%s\n' "$VERISIM_API_CMD"
    return 0
  fi

  if command -v verisim-api >/dev/null 2>&1; then
    printf '%s\n' "verisim-api"
    return 0
  fi

  local home=""
  if home="$(detect_verisim_home)"; then
    printf 'cd %q && just serve\n' "$home"
    return 0
  fi

  return 1
}

wait_for_verisim_health() {
  local api_url="$1"
  local pid="$2"
  local timeout_s="$3"
  local elapsed=0

  while (( elapsed < timeout_s )); do
    if curl -fsS --max-time 2 "$api_url/health" >/dev/null 2>&1; then
      return 0
    fi

    if ! kill -0 "$pid" >/dev/null 2>&1; then
      return 1
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  return 1
}

stop_local_verisim() {
  if [[ "$LOCAL_VERISIM_STARTED" != "1" ]]; then
    return
  fi

  if [[ -n "$LOCAL_VERISIM_PID" ]] && kill -0 "$LOCAL_VERISIM_PID" >/dev/null 2>&1; then
    kill "$LOCAL_VERISIM_PID" >/dev/null 2>&1 || true
    wait "$LOCAL_VERISIM_PID" 2>/dev/null || true
  fi

  if [[ -n "$LOCAL_VERISIM_LOG" ]]; then
    log_info "stopped local verisim instance (log: $LOCAL_VERISIM_LOG)"
  else
    log_info "stopped local verisim instance"
  fi
}

start_local_verisim() {
  local host="${VEXOMETER_BENCH_VERISIM_HOST:-127.0.0.1}"
  local min_port="${VEXOMETER_BENCH_VERISIM_PORT_MIN:-18080}"
  local max_port="${VEXOMETER_BENCH_VERISIM_PORT_MAX:-18999}"
  local timeout_s="${VEXOMETER_BENCH_VERISIM_START_TIMEOUT_S:-45}"
  local runtime_dir="$ROOT_DIR/.verisim-local"
  local launch_cmd=""

  launch_cmd="$(resolve_verisim_launch_cmd)" || {
    log_warn "could not resolve a verisim launcher (set VERISIM_API_CMD or VERISIM_HOME)"
    return 1
  }

  local port=""
  port="$(find_free_port "$host" "$min_port" "$max_port")" || {
    log_warn "no free verisim port found in range $min_port-$max_port"
    return 1
  }

  local api_url="http://$host:$port/api/v1"
  local log_file="$runtime_dir/verisim.log"
  local pid_file="$runtime_dir/verisim.pid"

  mkdir -p "$runtime_dir"

  log_info "starting repo-local verisim instance on $api_url"

  (
    export VERISIM_HOST="$host"
    export VERISIM_PORT="$port"
    nohup bash -lc "$launch_cmd" >"$log_file" 2>&1 &
    echo $! >"$pid_file"
  )

  local pid=""
  pid="$(cat "$pid_file")"

  if ! wait_for_verisim_health "$api_url" "$pid" "$timeout_s"; then
    log_warn "local verisim instance did not become healthy in ${timeout_s}s"
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
      wait "$pid" 2>/dev/null || true
    fi
    log_warn "verisim start log tail:"
    tail -n 40 "$log_file" >&2 || true
    return 1
  fi

  export VERISIM_API_URL="$api_url"
  LOCAL_VERISIM_STARTED=1
  LOCAL_VERISIM_PID="$pid"
  LOCAL_VERISIM_LOG="$log_file"
  trap stop_local_verisim EXIT

  log_info "local verisim instance ready: $VERISIM_API_URL"
  return 0
}

prepare_verisim_endpoint() {
  local mode
  mode="$(printf '%s' "${VEXOMETER_BENCH_VERISIM_MODE:-auto}" | tr '[:upper:]' '[:lower:]')"

  if [[ -n "${VERISIM_API_URL:-}" ]]; then
    log_info "using configured verisim endpoint: $VERISIM_API_URL"
    return 0
  fi

  case "$mode" in
    disabled|off|none)
      log_warn "verisim publish disabled by VEXOMETER_BENCH_VERISIM_MODE=$mode"
      return 1
      ;;
    external)
      export VERISIM_API_URL="${VEXOMETER_BENCH_VERISIM_EXTERNAL_URL:-http://127.0.0.1:18080/api/v1}"
      log_info "using external verisim endpoint: $VERISIM_API_URL"
      return 0
      ;;
    auto)
      start_local_verisim
      return $?
      ;;
    *)
      log_warn "unknown VEXOMETER_BENCH_VERISIM_MODE=$mode"
      return 1
      ;;
  esac
}

load_profile

export VEXOMETER_BENCH_DB_BACKEND="${VEXOMETER_BENCH_DB_BACKEND:-verisimdb}"

mkdir -p "$RESULTS_DIR"

cd "$ROOT_DIR"

log_info "== building benchmark runner =="
gprbuild -p -P tests/vexometer_bench.gpr

log_info "== running benchmarks =="
./bin/benchmark_runner > "$LATEST_JSON"
cp "$LATEST_JSON" "$STAMPED_JSON"

log_info "benchmark summary: $LATEST_JSON"
log_info "timestamped copy: $STAMPED_JSON"
log_info "case reports: $RESULTS_DIR/cases"

if [[ "${VEXOMETER_BENCH_DB_BACKEND}" == "verisimdb" ]]; then
  if prepare_verisim_endpoint; then
    log_info "== publishing benchmark summary to verisimdb =="
    if ! ./scripts/publish-bench-to-verisim.sh "$LATEST_JSON"; then
      if [[ "${VEXOMETER_BENCH_REQUIRE_DB:-0}" == "1" ]]; then
        log_warn "verisimdb publish failed and VEXOMETER_BENCH_REQUIRE_DB=1"
        exit 1
      fi
      log_warn "warning: verisimdb publish failed (continuing)"
    fi
  else
    if [[ "${VEXOMETER_BENCH_REQUIRE_DB:-0}" == "1" ]]; then
      log_warn "verisimdb endpoint unavailable and VEXOMETER_BENCH_REQUIRE_DB=1"
      exit 1
    fi
    log_warn "warning: verisimdb endpoint unavailable; publish skipped"
  fi
fi
