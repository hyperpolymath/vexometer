;; SPDX-License-Identifier: PMPL-1.0
;; ECOSYSTEM.scm - Project relationship mapping

(ecosystem
  (version "1.0")
  (name "vexometer")
  (type "diagnostic-instrument")
  (purpose "Quantify AI assistant irritation surfaces with 10 measurable metrics (ISA score)")

  (position-in-ecosystem
    (role "hub")
    (layer "application")
    (description "Diagnostic instrument for measuring LLM user experience degradation. Hub for satellite intervention system."))

  (related-projects
    ((name . "vex-lazy-eliminator")
     (relationship . "potential-consumer")
     (description . "Completeness enforcement satellite (reduces CII, LPS)"))
    ((name . "vex-hallucination-guard")
     (relationship . "potential-consumer")
     (description . "Factual claim verification satellite (reduces EFR)"))
    ((name . "vex-sycophancy-shield")
     (relationship . "potential-consumer")
     (description . "Epistemic commitment tracking satellite (reduces LPS, EFR)"))
    ((name . "vex-confidence-calibrator")
     (relationship . "potential-consumer")
     (description . "Structured uncertainty satellite (reduces EFR)"))
    ((name . "vex-specification-anchor")
     (relationship . "potential-consumer")
     (description . "Immutable requirements ledger satellite (reduces SFR, ICS)"))
    ((name . "vex-instruction-persistence")
     (relationship . "potential-consumer")
     (description . "System instruction compliance satellite (reduces TII, ICS)"))
    ((name . "vex-backtrack-enabler")
     (relationship . "potential-consumer")
     (description . "Low-friction restart support satellite (reduces SRS, ICS)"))
    ((name . "vex-context-firewall")
     (relationship . "potential-consumer")
     (description . "Truth maintenance satellite (reduces EFR, ICS)"))
    ((name . "vex-scope-governor")
     (relationship . "potential-consumer")
     (description . "Scope contract enforcement satellite (reduces SFR, PQ)"))
    ((name . "vex-error-recovery")
     (relationship . "potential-consumer")
     (description . "Strategy variation on failure satellite (reduces RCI)"))
    ((name . "vex-verbosity-compressor")
     (relationship . "potential-consumer")
     (description . "Information density optimisation satellite (reduces LPS, TII)"))
    ((name . "vex-clarification-gate")
     (relationship . "potential-consumer")
     (description . "Risk-weighted ambiguity handling satellite (reduces PQ, TII)"))
    ((name . "vexometer-satellites")
     (relationship . "sibling-standard")
     (description . "Umbrella documentation hub for satellite system"))
    ((name . "lmsys-chatbot-arena")
     (relationship . "inspiration")
     (description . "Chatbot evaluation arena - proposed ISA integration target")))

  (what-this-is
    "A diagnostic instrument that measures ten dimensions of AI assistant user experience degradation: TII (Temporal Intrusion), LPS (Linguistic Pathology), EFR (Epistemic Failure Rate), PQ (Paternalism Quotient), TAI (Telemetry Anxiety), ICS (Interaction Coherence), CII (Completion Integrity), SRS (Strategic Rigidity), SFR (Scope Fidelity Ratio), RCI (Recovery Competence Index). Produces ISA scores from 0-100 where lower is better. Provides vexometer-trace-v1 format for satellite validation.")

  (what-this-is-not
    "An intervention system (satellites provide interventions). A benchmark of capability (complements MMLU/HumanEval with UX metrics). A subjective opinion tool (uses pattern detection, behavioral probes, and statistical validation). A single-metric system (aggregates 10 independent dimensions)."))
