<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- TOPOLOGY.md — Project architecture map and completion dashboard -->
<!-- Last updated: 2026-02-28 -->

# VEX Toolkit (vexometer) — Project Topology

> Naming convention: **The Vexometer: Irritation Surface Analyser (ISA) for LLMs and related tools** is the canonical title, and **vexometer** remains the compatibility identifier in repo/package/CLI/protocol names.

## System Architecture

```
                        ┌─────────────────────────────────────────┐
                        │              OPERATOR / AI              │
                        │        (Analysis, Comm, Intervention)   │
                        └───────────────────┬─────────────────────┘
                                            │ Signal / Event
                                            ▼
                        ┌─────────────────────────────────────────┐
                        │           VEX TOOLKIT HUB               │
                        │                                         │
                        │  ┌───────────┐  ┌───────────────────┐  │
                        │  │ ISA       │  │  Lazy             │  │
                        │  │ (Metrics) │  │  Eliminator       │  │
                        │  └─────┬─────┘  └────────┬──────────┘  │
                        │        │                 │              │
                        │  ┌─────▼─────┐  ┌────────▼──────────┐  │
                        │  │ Vext      │  │  Satellite        │  │
                        │  │ (Protocol)│  │  Intervention     │  │
                        │  └─────┬─────┘  └────────┬──────────┘  │
                        └────────│─────────────────│──────────────┘
                                 │                 │
                                 ▼                 ▼
                        ┌─────────────────────────────────────────┐
                        │           EXTERNAL INTERFACES           │
                        │  ┌───────────┐  ┌───────────────────┐  │
                        │  │ Traditional│ │  Verified         │  │
                        │  │ Email     │  │  Endpoints        │  │
                        │  └───────────┘  └───────────────────┘  │
                        └─────────────────────────────────────────┘

                        ┌─────────────────────────────────────────┐
                        │          REPO INFRASTRUCTURE            │
                        │  Justfile Automation  .machine_readable/ │
                        │  Docs + Roadmaps      Monorepo Hygiene   │
                        └─────────────────────────────────────────┘
```

## Completion Dashboard

```
COMPONENT                          STATUS              NOTES
─────────────────────────────────  ──────────────────  ─────────────────────────────────
ISA & INTERVENTION
  ISA (vexometer analyser)          ████████░░  80%    Core metrics, JSON loaders, and CLI/report wiring implemented
  ISA Satellites                    █████░░░░░  45%    Protocol/docs exist; most satellites still planned
  Lazy Eliminator                   ████████░░  75%    Core analyzer tested; polish/integration pending
  Satellite Template                █████████░  90%    Template structure stable by design

VEXT PROTOCOL
  Vext (Core Protocol)              ████████░░  85%    Core Rust tests passing
  Vext Email Gateway                ███░░░░░░░  30%    Prototype; not production-wired yet
  Neutrality Proofs                 ██░░░░░░░░  25%    Proof direction defined; implementation in progress

REPO INFRASTRUCTURE
  Justfile Automation               █████████░  90%    Main flows and trust-manifest gates wired
  .machine_readable/                █████████░  90%    Metadata aligned to current monorepo
  Consolidation (2026)              ██████████ 100%    6 repos successfully merged

─────────────────────────────────────────────────────────────────────────────
OVERALL:                            ███████░░░  ~70%   Core operational; ecosystem integration still maturing
```

## Key Dependencies

```
Lazy Patterns ───► Eliminator Engine ──► ISA Score ───► Intervention
     │                   │                   │                    │
     ▼                   ▼                   ▼                    ▼
Comm Event ──────► Vext Protocol ──────► Email Gateway ──────► Recipient
```

## Update Protocol

This file is maintained by both humans and AI agents. When updating:

1. **After completing a component**: Change its bar and percentage
2. **After adding a component**: Add a new row in the appropriate section
3. **After architectural changes**: Update the ASCII diagram
4. **Date**: Update the `Last updated` comment at the top of this file

Progress bars use: `█` (filled) and `░` (empty), 10 characters wide.
Percentages: 0%, 10%, 20%, ... 100% (in 10% increments).
