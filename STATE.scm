;; SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell
;; SPDX-License-Identifier: AGPL-3.0-or-later
;;
;; STATE.scm - Vexometer Project State Checkpoint
;; Download at session end, upload at session start.
;; https://github.com/hyperpolymath/state.scm

;;;============================================================================
;;; METADATA
;;;============================================================================

(metadata
  (format-version "1.0.0")
  (schema "state.scm/v1")
  (created "2024-12-08")
  (updated "2024-12-08")
  (generator "claude-opus-4"))

;;;============================================================================
;;; PROJECT IDENTITY
;;;============================================================================

(project
  (name "vexometer")
  (tagline "Irritation Surface Analyser for AI Assistants")
  (version "0.1.0")
  (language "Ada 2022")
  (license "AGPL-3.0-or-later")
  (repository "https://gitlab.com/hyperpolymath/vexometer"))

;;;============================================================================
;;; CURRENT POSITION
;;;============================================================================

(current-position
  (phase "architecture-complete")
  (completion-percent 15)
  (summary "All package specifications defined; no implementations exist yet")

  (what-exists
    ;; Ada package specifications (interfaces only)
    (specs
      ("src/vexometer.ads" "Root package with version and philosophy")
      ("src/vexometer-core.ads" "Core types: metrics, findings, analysis config")
      ("src/vexometer-patterns.ads" "Pattern detection engine with regex")
      ("src/vexometer-probes.ads" "Behavioural probe system")
      ("src/vexometer-api.ads" "LLM API clients (Ollama, OpenAI, Anthropic, etc.)")
      ("src/vexometer-metrics.ads" "Statistical functions and ISA calculation")
      ("src/vexometer-reports.ads" "Report generation (JSON, HTML, Markdown, CSV, LaTeX)")
      ("src/vexometer-gui.ads" "GtkAda interface specification"))

    ;; Implementation (minimal)
    (bodies
      ("src/vexometer.adb" "Main entry point - CLI skeleton only"))

    ;; Data definitions
    (data
      ("data/patterns/paternalism.json" "12 paternalism detection patterns")
      ("data/patterns/linguistic_pathology.json" "Sycophancy/hedging patterns")
      ("data/probes/behavioural_probes.json" "Probe test suite definitions"))

    ;; Infrastructure
    (infra
      ("flake.nix" "Nix development environment")
      ("justfile" "Build tasks: build, run, test, validate")
      ("vexometer.gpr" "GNAT project file")))

  (what-missing
    ;; Package bodies (implementations)
    ("vexometer-core.adb" "ISA calculation, score aggregation")
    ("vexometer-patterns.adb" "Regex matching, pattern loading from JSON")
    ("vexometer-probes.adb" "Probe loading, execution, scoring")
    ("vexometer-api.adb" "HTTP clients for LLM providers")
    ("vexometer-metrics.adb" "Statistical functions, normalisation")
    ("vexometer-reports.adb" "Report generation in all formats")
    ("vexometer-gui.adb" "Full GtkAda GUI implementation")
    ;; Tests
    ("tests/*" "No test suite exists yet")))

;;;============================================================================
;;; ROUTE TO MVP v1
;;;============================================================================

(mvp-v1
  (goal "Analyse text for irritation patterns via CLI; compare models via Ollama")
  (scope
    "CLI-first approach. No GUI required for v1. Local-only (Ollama) API.
     JSON and Markdown report output. Basic probe suite execution.")

  (milestones
    (milestone
      (id "M1")
      (name "Core Implementation")
      (status "pending")
      (tasks
        ("Implement vexometer-core.adb: Calculate_ISA, Calculate_Category_Scores, Aggregate_Profile")
        ("Implement vexometer-metrics.adb: Mean, Standard_Deviation, Median, Percentile")
        ("Unit tests for score calculation")))

    (milestone
      (id "M2")
      (name "Pattern Engine")
      (status "pending")
      (tasks
        ("Implement vexometer-patterns.adb: Analyse_Text using GNAT.Regpat")
        ("JSON pattern file loader")
        ("Load_From_Directory to scan data/patterns/")
        ("Heuristic analysers: Detect_Repetition, Estimate_Sycophancy_Density")))

    (milestone
      (id "M3")
      (name "CLI Analysis")
      (status "pending")
      (tasks
        ("Wire up 'vexometer analyse' command")
        ("Read text from stdin or file")
        ("Output findings to stdout in JSON or human-readable format")
        ("Support --format flag for output selection")))

    (milestone
      (id "M4")
      (name "Ollama API Client")
      (status "pending")
      (tasks
        ("Implement vexometer-api.adb: Ollama provider only")
        ("Send_Prompt with HTTP POST to localhost:11434")
        ("Parse JSON response, extract response text")
        ("Handle connection errors gracefully")))

    (milestone
      (id "M5")
      (name "Probe Runner")
      (status "pending")
      (tasks
        ("Implement vexometer-probes.adb: Load_From_File, built-in probes")
        ("Wire up 'vexometer probe MODEL' command")
        ("Run probe suite, collect responses, analyse each")
        ("Output summary with pass/fail for each probe")))

    (milestone
      (id "M6")
      (name "Reports")
      (status "pending")
      (tasks
        ("Implement vexometer-reports.adb: JSON and Markdown formats")
        ("Generate_Report, Generate_Comparison_Report")
        ("Wire up 'vexometer report' command")))))

;;;============================================================================
;;; KNOWN ISSUES
;;;============================================================================

(issues
  (issue
    (id "I1")
    (severity "blocker")
    (title "No package bodies exist")
    (description "All .ads files define interfaces but no .adb implementations.
                  The project will not compile to a working binary."))

  (issue
    (id "I2")
    (severity "major")
    (title "No test infrastructure")
    (description "AUnit framework referenced in justfile but no tests exist.
                  Need to set up test project and initial test cases."))

  (issue
    (id "I3")
    (severity "major")
    (title "GtkAda dependency not verified")
    (description "GUI spec imports Gtk.* packages but GtkAda may not build
                  correctly in current Nix environment. Needs testing."))

  (issue
    (id "I4")
    (severity "minor")
    (title "HTTP client library unspecified")
    (description "API package needs HTTP client. Options: AWS, GNAT.Sockets
                  with manual HTTP, or external binding. Decision needed."))

  (issue
    (id "I5")
    (severity "minor")
    (title "JSON parsing library unspecified")
    (description "Need JSON parser for pattern files and API responses.
                  Options: GNATCOLL.JSON, external binding. Decision needed.")))

;;;============================================================================
;;; QUESTIONS FOR USER
;;;============================================================================

(questions
  (question
    (id "Q1")
    (topic "MVP scope")
    (text "Should MVP v1 be strictly CLI-only, or include a minimal GUI?")
    (options
      ("cli-only" "Focus on CLI, defer GUI entirely")
      ("minimal-gui" "Basic single-window text analysis GUI")
      ("full-gui" "Complete GUI as designed in vexometer-gui.ads")))

  (question
    (id "Q2")
    (topic "API priority")
    (text "Which API providers should be implemented for v1 beyond Ollama?")
    (options
      ("ollama-only" "Local Ollama only - maximum privacy")
      ("ollama-openai" "Add OpenAI for baseline comparison")
      ("ollama-anthropic" "Add Anthropic (Claude) for self-reference")
      ("all-local" "All local providers: Ollama, LMStudio, llama.cpp")))

  (question
    (id "Q3")
    (topic "HTTP library")
    (text "Which HTTP client approach for API calls?")
    (options
      ("aws" "AWS (Ada Web Server) - full-featured but heavy")
      ("gnat-sockets" "GNAT.Sockets with manual HTTP - lightweight")
      ("curl-binding" "Binding to libcurl - proven, external dep")))

  (question
    (id "Q4")
    (topic "Testing")
    (text "Should tests be written as development proceeds (TDD) or added after MVP?")
    (options
      ("tdd" "Test-driven: write tests first for each component")
      ("parallel" "Write tests alongside implementation")
      ("post-mvp" "Get MVP working first, add tests later")))

  (question
    (id "Q5")
    (topic "Pattern coverage")
    (text "Current patterns cover LPS and PQ. Should other categories be expanded for v1?")
    (options
      ("lps-pq-only" "Focus on Linguistic Pathology and Paternalism")
      ("add-epi" "Add Epistemic Failure patterns")
      ("all-categories" "Patterns for all 6 metric categories"))))

;;;============================================================================
;;; LONG-TERM ROADMAP
;;;============================================================================

(roadmap
  (phase
    (id "v1.0")
    (name "MVP Release")
    (status "in-progress")
    (goals
      "Working CLI tool that can:
       - Analyse text for irritation patterns
       - Query local Ollama models with probes
       - Generate JSON/Markdown reports
       - Compare multiple models"))

  (phase
    (id "v1.x")
    (name "Expanded API Support")
    (status "planned")
    (goals
      "Add remaining API providers:
       - OpenAI, Anthropic, Google, Mistral (proprietary)
       - Together, Groq, HuggingFace (open-weight hosted)
       - LMStudio, llama.cpp, LocalAI, Koboldcpp (local)"))

  (phase
    (id "v2.0")
    (name "GUI Release")
    (status "planned")
    (goals
      "Full GtkAda GUI as designed:
       - Radar chart visualisation
       - Real-time analysis
       - Model comparison table
       - Finding highlighting in response text
       - Export functionality"))

  (phase
    (id "v2.x")
    (name "Advanced Analysis")
    (status "planned")
    (goals
      "Semantic analysis beyond regex:
       - Competence mismatch detection
       - Context coherence measurement
       - Response verbosity analysis
       - Hallucination detection heuristics"))

  (phase
    (id "v3.0")
    (name "SPARK Verification")
    (status "planned")
    (goals
      "Add SPARK annotations for formal verification:
       - Prove absence of runtime errors
       - Verify metric calculation correctness
       - Certified score computation"))

  (phase
    (id "v3.x")
    (name "Community & Integration")
    (status "planned")
    (goals
      "Ecosystem integration:
       - LMArena submission format
       - Community probe contributions
       - CI integration for model testing
       - Academic paper dataset format")))

;;;============================================================================
;;; CRITICAL NEXT ACTIONS
;;;============================================================================

(critical-next
  (action
    (priority 1)
    (task "Implement vexometer-core.adb with Calculate_ISA")
    (rationale "Foundation for all other components"))

  (action
    (priority 2)
    (task "Implement vexometer-patterns.adb with Analyse_Text")
    (rationale "Core pattern matching needed for any analysis"))

  (action
    (priority 3)
    (task "Wire up 'vexometer analyse' CLI command")
    (rationale "First user-facing functionality"))

  (action
    (priority 4)
    (task "Choose and integrate JSON parsing library")
    (rationale "Blocks pattern file loading and API response handling"))

  (action
    (priority 5)
    (task "Set up AUnit test project skeleton")
    (rationale "Enable verified development going forward")))

;;;============================================================================
;;; SESSION FILES
;;;============================================================================

(session-files
  (created
    ("STATE.scm" "This state checkpoint file"))
  (modified ())
  (read
    ("src/vexometer.ads")
    ("src/vexometer.adb")
    ("src/vexometer-core.ads")
    ("src/vexometer-patterns.ads")
    ("src/vexometer-probes.ads")
    ("src/vexometer-api.ads")
    ("src/vexometer-gui.ads")
    ("src/vexometer-metrics.ads")
    ("src/vexometer-reports.ads")
    ("data/patterns/paternalism.json")
    ("justfile")
    ("README.adoc")))

;;; End of STATE.scm
