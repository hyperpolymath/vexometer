# PROOF-NEEDS.md
<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->

## Current State

- **LOC**: ~32,000
- **Languages**: Rust, ReScript, Idris2, Zig
- **Existing ABI proofs**: `lazy-eliminator/src/abi/*.idr` (template-level)
- **Dangerous patterns**:
  - `vext/vext-tools/src/bindings/Std.res`: 2 `Obj.magic` for CLI argument parsing
  - `vext/vext-tools/src/hooks/Git.res`: 1 `Obj.magic` for notification serialization

## What Needs Proving

### Lazy Eliminator Analysis (lazy-eliminator/)
- `analyzer.rs`, `detection.rs`, `patterns.rs` — static analysis for lazy evaluation elimination
- Prove: analysis correctly identifies lazy evaluation patterns (no false negatives)
- Prove: elimination suggestions preserve program semantics

### Trace System (lazy-eliminator/src/trace.rs)
- Execution tracing — prove traces are faithful to execution order

### Fuzz Target (lazy-eliminator/fuzz/)
- Fuzzing exists but formal proofs of analysis correctness would be stronger

### Vext Tools Obj.magic
- Minor — CLI argument parsing and notification serialization
- Low priority but should use typed bindings

## Recommended Prover

- **Idris2** for analysis correctness specification
- **Lean4** alternative for the semantic preservation proofs

## Priority

**LOW** — Developer tooling. Analysis correctness is desirable but false positives/negatives are inconveniences, not safety issues. The `Obj.magic` uses are minimal and non-critical.

## Template ABI Cleanup (2026-03-29)

Template ABI removed -- was creating false impression of formal verification.
The removed files (Types.idr, Layout.idr, Foreign.idr) contained only RSR template
scaffolding with unresolved {{PROJECT}}/{{AUTHOR}} placeholders and no domain-specific proofs.
