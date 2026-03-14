;; SPDX-License-Identifier: PMPL-1.0-or-later
(ecosystem
  (metadata
    (version "0.2.0")
    (last-updated "2026-02-28"))
  (project
    (name "vexometer")
    (purpose "Measure and reduce AI assistant irritation surfaces and support verifiable communication workflows")
    (role toolkit-monorepo))
  (components
    (component
      (name "isa-core")
      (path "vexometer")
      (role measurement-hub))
    (component
      (name "isa-satellites-hub")
      (path "vexometer-satellites")
      (role intervention-registry))
    (component
      (name "satellite-template")
      (path "satellite-template")
      (role scaffold))
    (component
      (name "lazy-eliminator")
      (path "lazy-eliminator")
      (role intervention))
    (component
      (name "vext-core")
      (path "vext")
      (role protocol-core))
    (component
      (name "vext-email-gateway")
      (path "vext-email-gateway")
      (role protocol-bridge))))
