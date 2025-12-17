;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;; SPDX-License-Identifier: AGPL-3.0-or-later
;;
;; Vexometer - Irritation Surface Analyser
;; GNU Guix package definition (RSR primary package manager)
;;
;; Usage:
;;   guix shell -f guix.scm      # Enter dev environment
;;   guix build -f guix.scm      # Build package
;;   guix pack -f guix.scm       # Create relocatable tarball

(use-modules (guix packages)
             (guix gexp)
             (guix git-download)
             (guix build-system gnu)
             ((guix licenses) #:prefix license:)
             (gnu packages ada)
             (gnu packages gtk)
             (gnu packages pkg-config)
             (gnu packages version-control)
             (gnu packages build-tools)
             (gnu packages curl)
             (gnu packages tls)
             (gnu packages documentation)
             (gnu packages shellutils))

(define-public vexometer
  (package
    (name "vexometer")
    (version "0.2.0-dev")
    (source (local-file "." "vexometer-checkout"
                        #:recursive? #t
                        #:select? (lambda (file stat)
                                    (not (or (string-suffix? ".git" file)
                                             (string-suffix? "obj" file)
                                             (string-suffix? "bin" file))))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (replace 'build
            (lambda _
              (invoke "gprbuild" "-P" "vexometer.gpr"
                      "-XVEXOMETER_BUILD_MODE=release")))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                ;; AUnit tests would run here
                (display "Tests not yet implemented\n"))))
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (bin (string-append out "/bin"))
                     (share (string-append out "/share/vexometer")))
                (mkdir-p bin)
                (mkdir-p share)
                (install-file "bin/vexometer" bin)
                (copy-recursively "data" share)))))))
    (native-inputs
     (list gprbuild
           pkg-config))
    (inputs
     (list gnat
           gtkada
           gtk+
           gnatcoll
           aws-ada
           curl
           openssl))
    (propagated-inputs
     (list just))
    (synopsis "Irritation Surface Analyser for AI assistants")
    (description
     "Vexometer measures AI assistant 'irritation surfaces' - the friction,
annoyances, and failures that make AI interactions frustrating.  It provides
quantified metrics across dimensions including temporal intrusion (TII),
linguistic pathology (LPS), epistemic failure (EFR), paternalism (PQ),
telemetry anxiety (TAI), interaction coherence (ICS), completion integrity
(CII), strategic rigidity (SRS), scope fidelity (SFR), and recovery
competence (RCI).

Vexometer diagnoses; it does not prescribe treatment.  Intervention tools
(satellites) are developed in separate repositories.")
    (home-page "https://gitlab.com/hyperpolymath/vexometer")
    (license license:agpl3+)))

;; Return the package for `guix build -f guix.scm`
vexometer
