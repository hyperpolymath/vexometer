# TEST-NEEDS: vexometer

## Current State

| Category | Count | Details |
|----------|-------|---------|
| **Source modules** | 24+ | Ada specs (10: api, cii, core, gui, metrics, patterns, probes, rci, reports, sfr) + bodies, 3 Idris2 ABI per sub-project (vexometer, vexometer-satellites, satellite-template), Zig FFI |
| **Unit tests** | 1 file | test_runner.adb (~36 assertions) |
| **Integration tests** | 0 | None |
| **E2E tests** | 0 | None |
| **Benchmarks** | 0 | None |

## What's Missing

### P2P Tests
- [ ] No tests for vexometer <-> satellite communication
- [ ] No tests for probe -> metrics -> reports pipeline

### E2E Tests (CRITICAL)
- [ ] No test running vexometer against a real project and generating metrics
- [ ] No test for satellite deployment and data collection

### Aspect Tests
- [ ] **Security**: Metrics collection tool with no security tests (data exfiltration, probe sandboxing)
- [ ] **Performance**: No benchmarks for metrics collection overhead
- [ ] **Concurrency**: No tests for concurrent probe execution
- [ ] **Error handling**: No tests for unreachable satellites, malformed metrics

### Build & Execution
- [ ] No Ada compilation verification test
- [ ] All Zig FFI tests are template placeholders
- [ ] No Idris2 ABI compilation test

### Benchmarks Needed
- [ ] Metrics collection throughput
- [ ] Probe execution latency
- [ ] Report generation time

### Self-Tests
- [ ] No self-diagnostic mode

## FLAGGED ISSUES
- **24 Ada source files with 1 test file (36 assertions)** = severely undertested
- **10 Ada spec files (api, metrics, probes, reports, etc.) = 3.6 tests per module**
- **3 sub-projects (vexometer, satellites, template) with tests only in main project**
- **All Zig FFI tests are template copies** -- not real tests

## Priority: P1 (HIGH)

## FAKE-FUZZ ALERT

- `tests/fuzz/placeholder.txt` is a scorecard placeholder inherited from rsr-template-repo — it does NOT provide real fuzz testing
- Replace with an actual fuzz harness (see rsr-template-repo/tests/fuzz/README.adoc) or remove the file
- Priority: P2 — creates false impression of fuzz coverage
