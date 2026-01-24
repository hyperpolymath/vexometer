;; SPDX-License-Identifier: PMPL-1.0
;; STATE.scm - Current project state

(define project-state
  `((metadata
      ((version . "0.1.0")
       (schema-version . "1")
       (created . "2025-12-02T21:40:13+00:00")
       (updated . "2026-01-24T00:00:00+00:00")
       (project . "vexometer")
       (repo . "vexometer")))

    (project-context
      ((name . "Vexometer: Irritation Surface Analyser")
       (tagline . "Rigorous tool for quantifying AI assistant irritation surfaces")
       (tech-stack . ("Ada 2022" "GtkAda" "Alire" "GNAT" "Guix" "Nix"))))

    (current-position
      ((phase . "Specification Complete - Implementation Needed")
       (overall-completion . 40)
       (components
         ((specifications . 100)     ;; All .ads files complete
          (implementations . 0)       ;; No .adb files yet
          (documentation . 100)       ;; README, SATELLITES, METRICS, SPECIFICATION complete
          (data-files . 100)          ;; patterns/ and probes/ exist
          (build-system . 100)        ;; alire.toml, vexometer.gpr ready
          (satellite-system . 5)))    ;; Only template exists
       (working-features
         ("10 metric specifications defined"
          "Pattern catalog structure ready"
          "Probe suite structure ready"
          "Satellite architecture documented"
          "Build configuration complete"))))

    (route-to-mvp
      ((milestones
        ((v0.1-specs . ((items . ("Ada package specifications" "Documentation" "Build system"))
                        (status . "completed")))
         (v0.2-impl . ((items . ("Implement .adb bodies for all packages"
                                 "Pattern detection engine"
                                 "Probe execution system"
                                 "API client implementations"
                                 "Metric calculation logic"))
                       (status . "pending")))
         (v0.3-gui . ((items . ("GtkAda GUI implementation" "Report generation" "Visualization"))
                      (status . "pending")))
         (v0.4-satellites . ((items . ("vex-lazy-eliminator" "vex-hallucination-guard" "vex-sycophancy-shield"))
                             (status . "pending")))
         (v1.0-release . ((items . ("All 10 metrics operational" "At least 3 satellites" "LMSYS integration proposal"))
                          (status . "pending")))))))

    (blockers-and-issues
      ((critical
         ("No .adb implementation files - only specifications exist"))
       (high
         ("Satellite repos not created (only template exists)"
          "ECOSYSTEM.scm was corrupted (fixed 2026-01-24)"))
       (medium
         ("No test suite implementation"
          "Pattern JSON files incomplete"
          "Probe JSON files incomplete"))
       (low
         ("LMSYS Arena integration not yet proposed"
          "No baseline scores for common models"))))

    (critical-next-actions
      ((immediate
         ("Commit ECOSYSTEM.scm fix"
          "Create vexometer-satellites umbrella repo"
          "Implement vex-lazy-eliminator (first satellite)"))
       (this-week
         ("Implement core vexometer.adb main entry point"
          "Implement vexometer-patterns.adb detection engine"
          "Implement vexometer-metrics.adb calculation logic"))
       (this-month
         ("Complete all .adb implementation files"
          "Implement at least 3 satellites"
          "Test ISA score calculation on sample LLM outputs"))))

    (session-history
      ((session-001
         ((date . "2026-01-24")
          (accomplishments
            ("Fixed corrupted ECOSYSTEM.scm - replaced badge text with proper ecosystem definition"
             "Identified all 12 satellite repos missing from GitHub"
             "Confirmed vex-satellite-template exists as only satellite-related repo"
             "Updated STATE.scm with accurate project status"))
          (next-session . "Create umbrella repo and first satellite implementation")))))
