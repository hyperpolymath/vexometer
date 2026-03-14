;; SPDX-License-Identifier: PMPL-1.0-or-later
(state
  (metadata
    (version "0.2.0")
    (last-updated "2026-02-28")
    (status active))
  (project-context
    (name "vexometer")
    (canonical-product-title "The Vexometer: Irritation Surface Analyser for LLMs and related tools")
    (canonical-product-name "ISA")
    (legacy-product-name "Vexometer")
    (overall-completion-percentage 70))
  (component-status
    (component
      (name "isa-core")
      (path "vexometer")
      (status in-progress)
      (completion-percentage 80))
    (component
      (name "isa-satellites-hub")
      (path "vexometer-satellites")
      (status in-progress)
      (completion-percentage 45))
    (component
      (name "lazy-eliminator")
      (path "lazy-eliminator")
      (status in-progress)
      (completion-percentage 75))
    (component
      (name "satellite-template")
      (path "satellite-template")
      (status stable-template)
      (completion-percentage 90))
    (component
      (name "vext-core")
      (path "vext")
      (status in-progress)
      (completion-percentage 85))
    (component
      (name "vext-email-gateway")
      (path "vext-email-gateway")
      (status prototype)
      (completion-percentage 30))))
