;;; SPDX-License-Identifier: MPL-2.0
;;; manifest.scm — Generic Guix manifest for RSR-compliant projects
;;;
;;; Usage:
;;;   guix shell -m manifest.scm
;;;

(specifications->manifest
  '(;; Core development tools
    "git"
    "just"
    "nickel"
    "curl"
    "bash"
    "coreutils"

    ;; Rust toolchain (this satellite is a Rust crate)
    "rust"
    "rust:cargo"
    "rust:tools"
    "gcc-toolchain"

    ;; Documentation
    "asciidoctor"
    "pandoc"

    ;; Common build dependencies
    "openssl"
    "zlib"
    "pkg-config"))
