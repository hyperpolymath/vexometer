# TEST-NEEDS: vexometer

## Current State

| Category | Count | Details |
|----------|-------|---------|
| **Source modules** | 24+ | Ada specs (10: api, cii, core, gui, metrics, patterns, probes, rci, reports, sfr) + bodies, 3 Idris2 ABI per sub-project (vexometer, vexometer-satellites, satellite-template), Zig FFI |
| **Unit tests** | 4 files | test_runner.adb (~36 assertions) + 3 analyzer.rs unit tests |
| **E2E tests** | 1 file | e2e_test.rs (16 tests - full pipeline analysis, multi-language, CII calc) |
| **Property tests** | 1 file | property_test.rs (16 tests - proptest: analysis never panics, CII ranges, determinism) |
| **Aspect tests** | 1 file | aspect_test.rs (20 tests - security, robustness, concurrency) |
| **Benchmarks** | 1 file | detection_bench.rs (Criterion: throughput, language detection, CII calc) |

## What's Completed (CRG D→C Blitz)

### ✓ Lazy-Eliminator (Rust sub-project) - CRG C Achieved
- [x] **Unit tests** (3): Python TODO, Rust unimplemented, complete code
- [x] **E2E tests** (16): Full pipeline, multi-language, CII calculation, detections
- [x] **Property tests** (16): Analysis never panics, CII in [0,1], determinism, summary consistency
- [x] **Aspect tests** (20): Security (null bytes, ReDoS), robustness (unicode, line endings, BOM), concurrency (shared analyzer, consistent results), performance
- [x] **Benchmarks** (Criterion): Single-file throughput (100/1000/10000 lines), language detection, config loading, pattern matching, CII calc, multi-language

### Test Summary
- **Total tests**: 55 tests across all categories (unit + e2e + property + aspect)
- **Pass rate**: 100% (3+16+16+20=55 tests passing)
- **Coverage**: detection.rs, analyzer.rs, language.rs, patterns.rs, config.rs fully tested
- **CRG Grade**: C (comprehensive test coverage, property tests, benchmarks baselined)

## Remaining Work (Ada/Idris2 ABI)

### P2P Tests (Ada)
- [ ] No tests for vexometer <-> satellite communication
- [ ] No tests for probe -> metrics -> reports pipeline

### E2E Tests (Ada, CRITICAL)
- [ ] No test running vexometer against a real project and generating metrics
- [ ] No test for satellite deployment and data collection

### Build & Execution
- [ ] No Ada compilation verification test
- [ ] All Zig FFI tests are template placeholders
- [ ] No Idris2 ABI compilation test

## Priority: P1 (Ada/Idris2 testing)

## Status

**lazy-eliminator (Rust)**: CRG C complete — 55 tests (unit+E2E+property+aspect), benchmarks baselined
**vexometer (Ada)**: Remaining work for full project CRG C (satellite comms, E2E pipeline)
