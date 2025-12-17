<!-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell -->
<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->

# Vexometer Roadmap

**Version**: 0.2.0-dev
**Phase**: Extending Metrics
**Updated**: 2025-12-17

## Current Status

Vexometer is the **hub** of the irritation surface analysis ecosystem. It measures AI assistant friction, annoyances, and failures through quantified metrics. **It diagnoses; it does not prescribe treatment.**

### Completed (v0.1.0)

- Core ISA (Irritation Surface Analyser) framework
- Original 6 metrics implemented:
  - **TII** - Temporal Intrusion Index (time-wasting behaviours)
  - **LPS** - Linguistic Pathology Score (verbal tics, padding, sycophancy)
  - **EFR** - Epistemic Failure Rate (hallucination, false confidence)
  - **PQ** - Paternalism Quotient (over-helping, unsolicited warnings)
  - **TAI** - Telemetry Anxiety Index (privacy concerns)
  - **ICS** - Interaction Coherence Score (conversation flow)
- RSR compliance infrastructure
- Basic measurement pipeline
- Pattern detection framework
- Model comparison and ranking
- GtkAda GUI framework
- Multi-provider API client (local + remote LLMs)

---

## In Progress (v0.2.0)

### Extended Metrics (v2)

Four additional metrics to complete diagnostic coverage:

| Metric | Name | Status | Description |
|--------|------|--------|-------------|
| **CII** | Completion Integrity Index | Specification complete | Incomplete outputs, placeholders, lazy generation |
| **SRS** | Strategic Rigidity Score | Specification complete | Backtrack resistance, sunk-cost patching |
| **SFR** | Scope Fidelity Ratio | Specification complete | Scope creep/collapse, request alignment |
| **RCI** | Recovery Competence Index | Specification complete | Error recovery quality, strategy variation |

### Next Steps

1. Implement CII detection patterns for common languages
2. Implement SRS event classification and tracking
3. Implement SFR scope comparison algorithm
4. Implement RCI approach fingerprinting
5. Create satellite integration interface specification
6. Document metric calculation methodology

---

## Planned (v0.3.0)

### Satellite Integration Interface

- **vexometer-trace-v1** protocol specification
- **vexometer-efficacy-v1** protocol for satellite reporting
- **vexometer-metrics-v1** subscription protocol
- Before/after trace validation
- Metric reduction percentage reporting

### Satellite Ecosystem (Independent Repos)

| Satellite | Reduces | Status | Purpose |
|-----------|---------|--------|---------|
| vex-lazy-eliminator | CII, LPS | Planned | Completeness enforcement |
| vex-hallucination-guard | EFR | Planned | Factual verification layer |
| vex-sycophancy-shield | LPS, EFR | Planned | Epistemic commitment tracking |
| vex-confidence-calibrator | EFR | Planned | Structured uncertainty |
| vex-specification-anchor | SFR, ICS | Planned | Immutable requirements ledger |
| vex-instruction-persistence | TII, ICS | Planned | System instruction compliance |
| vex-backtrack-enabler | SRS, ICS | Planned | Low-friction restart support |
| vex-context-firewall | EFR, ICS | Planned | Truth maintenance |
| vex-scope-governor | SFR, PQ | Planned | Scope contract enforcement |
| vex-error-recovery | RCI | Planned | Strategy variation on failure |
| vex-verbosity-compressor | LPS, TII | Planned | Information density optimisation |
| vex-clarification-gate | PQ, TII | Planned | Risk-weighted ambiguity handling |

---

## Future Considerations (v1.0.0)

- SPARK formal verification for metric calculations
- Full AUnit test coverage
- Container distribution (Podman/Docker)
- API bindings for integration (Rust, Elixir)
- Real-time analysis mode
- Benchmark suite with curated LLM interactions
- Public metric comparison database

---

## Architecture Decisions

| ADR | Decision | Status | Rationale |
|-----|----------|--------|-----------|
| ADR-001 | RSR Compliance | Accepted | RSR Gold target, SHA-pinned actions, SPDX headers |
| ADR-002 | Satellite Architecture | Accepted | Keep vexometer pure diagnostic; interventions in satellites |
| ADR-003 | Metric Normalisation | Accepted | All metrics 0-1 scale, lower is better |
| ADR-004 | Language Choice | Accepted | Ada/SPARK for formal verification of metric calculations |

---

## Technical Stack

- **Language**: Ada 2022 with SPARK annotations
- **Build**: gprbuild + Alire
- **GUI**: GtkAda
- **Package Management**: Guix (primary) / Nix (fallback)
- **CI/CD**: GitHub Actions (SHA-pinned) + GitLab CI
- **Standard**: RSR (Rhodium Standard Repository)

---

## Contributing

See [CONTRIBUTING.adoc](CONTRIBUTING.adoc) for guidelines. Vexometer follows a cathedral development model.

## Related Projects

- [rhodium-standard-repositories](https://github.com/hyperpolymath/rhodium-standard-repositories) - Repository standard
- [vexometer-satellites](https://gitlab.com/hyperpolymath/vexometer-satellites) - Satellite index
