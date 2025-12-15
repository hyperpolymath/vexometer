;; STATE.scm - Vexometer Development State
;; SPDX-License-Identifier: AGPL-3.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;; Updated: 2025-12-15

(project-state
  (name "vexometer")
  (version "0.2.0-dev")
  (phase "extending-metrics")

  (current-objectives
    (primary "Add CII, SRS, SFR, RCI metrics to complete diagnostic coverage")
    (secondary "Prepare satellite integration interface"))

  (completed-work
    (item "Core ISA framework with TII, LPS, EFR, PQ, TAI, ICS")
    (item "RSR compliance infrastructure")
    (item "Basic measurement pipeline")
    (item "Pattern detection framework")
    (item "Model comparison and ranking"))

  (in-progress
    (item "CII - Completion Integrity Index implementation"
          (status "specification-complete")
          (next "implement detection patterns")
          (file "src/vexometer-cii.ads"))
    (item "SRS - Strategic Rigidity Score implementation"
          (status "specification-complete")
          (next "implement event tracking")
          (file "src/vexometer-srs.ads"))
    (item "SFR - Scope Fidelity Ratio implementation"
          (status "specification-complete")
          (next "implement scope comparison")
          (file "src/vexometer-sfr.ads"))
    (item "RCI - Recovery Competence Index implementation"
          (status "specification-complete")
          (next "implement fingerprinting")
          (file "src/vexometer-rci.ads")))

  (blocked-items)

  (decisions
    (decision
      (date "2025-01")
      (topic "satellite-architecture")
      (outcome "Vexometer measures only; interventions in separate repos")
      (rationale "Keep diagnostic pure, avoid scope creep"))
    (decision
      (date "2025-01")
      (topic "metric-normalisation")
      (outcome "All metrics 0-1 where lower is better")
      (rationale "Consistent interpretation, easy aggregation"))
    (decision
      (date "2025-01")
      (topic "language-choice")
      (outcome "Ada/SPARK for core, with bindings for integration")
      (rationale "Formal verification for metric calculations")))

  (next-actions
    (action "Implement CII detection patterns for common languages")
    (action "Implement SRS event classification and tracking")
    (action "Implement SFR scope comparison algorithm")
    (action "Implement RCI approach fingerprinting")
    (action "Create satellite integration interface specification")
    (action "Document metric calculation methodology")
    (action "Create vexometer-trace-v1 protocol spec")))
