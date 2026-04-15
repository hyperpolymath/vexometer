# SPDX-License-Identifier: PMPL-1.0-or-later
# vexometer unified justfile
# Author: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

# Default recipe: list available commands
import? "contractile.just"

default:
    @just --list

# Build the vexometer (Ada)
build-vexometer:
    cd vexometer && just build

# Build vext (Rust)
build-vext:
    cd vext && cargo build --release

# Build the lazy eliminator
build-lazy-eliminator:
    cd lazy-eliminator && just build

# Build all components
build-all: build-vexometer build-vext build-lazy-eliminator

# Run vexometer tests
test-vexometer:
    cd vexometer && just test

# Run vexometer benchmarks
bench-vexometer:
    cd vexometer && just bench

# Run vext tests
test-vext:
    cd vext && (cargo test --offline || cargo test)

# Run lazy-eliminator tests
test-lazy-eliminator:
    cd lazy-eliminator && just test

# vext-email-gateway status check
test-vext-email-gateway:
    @echo "vext-email-gateway is currently prototype-stage and not part of the required test-all gate."
    @echo "See vext-email-gateway/README.adoc and ROADMAP.adoc for current wiring status."

# Run all tests
test-all: test-vexometer test-vext test-lazy-eliminator

# Run benchmark suites
bench-all: bench-vexometer

# Clean all build artifacts
clean:
    cd vext && cargo clean
    cd vexometer && just clean || true
    cd lazy-eliminator && just clean || true

# Check formatting across Rust components
fmt-check:
    cd vext && cargo fmt -- --check

# Run clippy on Rust components
lint:
    cd vext && cargo clippy -- -D warnings

# Run contractiles Mustfile invariants across all components
must-all:
    ./scripts/run-must-gates.sh

# Generate trust manifests for all components
trust-generate:
    ./scripts/trust/generate-manifest.sh

# Verify trust manifests for all components
trust-verify:
    ./scripts/trust/verify-manifest.sh

# Sign trust manifests (minisign or gpg required)
trust-sign:
    ./scripts/trust/sign-manifest.sh

# Rotate Trustfile metadata timestamps and regenerate manifests
trust-rotate:
    ./scripts/trust/rotate-trustfile.sh

# Full CI-equivalent local gate
ci-gate: must-all trust-verify test-all

# Run panic-attacker pre-commit scan
assail:
    @command -v panic-attack >/dev/null 2>&1 && panic-attack assail . || echo "panic-attack not found — install from https://github.com/hyperpolymath/panic-attacker"

# Self-diagnostic — checks dependencies, permissions, paths
doctor:
    @echo "Running diagnostics for vexometer..."
    @echo "Checking required tools..."
    @command -v just >/dev/null 2>&1 && echo "  [OK] just" || echo "  [FAIL] just not found"
    @command -v git >/dev/null 2>&1 && echo "  [OK] git" || echo "  [FAIL] git not found"
    @echo "Checking for hardcoded paths..."
    @grep -rn '$HOME\|$ECLIPSE_DIR' --include='*.rs' --include='*.ex' --include='*.res' --include='*.gleam' --include='*.sh' . 2>/dev/null | head -5 || echo "  [OK] No hardcoded paths"
    @echo "Diagnostics complete."

# Auto-repair common issues
heal:
    @echo "Attempting auto-repair for vexometer..."
    @echo "Fixing permissions..."
    @find . -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    @echo "Cleaning stale caches..."
    @rm -rf .cache/stale 2>/dev/null || true
    @echo "Repair complete."

# Guided tour of key features
tour:
    @echo "=== vexometer Tour ==="
    @echo ""
    @echo "1. Project structure:"
    @ls -la
    @echo ""
    @echo "2. Available commands: just --list"
    @echo ""
    @echo "3. Read README.adoc for full overview"
    @echo "4. Read EXPLAINME.adoc for architecture decisions"
    @echo "5. Run 'just doctor' to check your setup"
    @echo ""
    @echo "Tour complete! Try 'just --list' to see all available commands."

# Open feedback channel with diagnostic context
help-me:
    @echo "=== vexometer Help ==="
    @echo "Platform: $(uname -s) $(uname -m)"
    @echo "Shell: $SHELL"
    @echo ""
    @echo "To report an issue:"
    @echo "  https://github.com/hyperpolymath/vexometer/issues/new"
    @echo ""
    @echo "Include the output of 'just doctor' in your report."


# Print the current CRG grade (reads from READINESS.md '**Current Grade:** X' line)
crg-grade:
    @grade=$$(grep -oP '(?<=\*\*Current Grade:\*\* )[A-FX]' READINESS.md 2>/dev/null | head -1); \
    [ -z "$$grade" ] && grade="X"; \
    echo "$$grade"

# Generate a shields.io badge markdown for the current CRG grade
# Looks for '**Current Grade:** X' in READINESS.md; falls back to X
crg-badge:
    @grade=$$(grep -oP '(?<=\*\*Current Grade:\*\* )[A-FX]' READINESS.md 2>/dev/null | head -1); \
    [ -z "$$grade" ] && grade="X"; \
    case "$$grade" in \
      A) color="brightgreen" ;; B) color="green" ;; C) color="yellow" ;; \
      D) color="orange" ;; E) color="red" ;; F) color="critical" ;; \
      *) color="lightgrey" ;; esac; \
    echo "[![CRG $$grade](https://img.shields.io/badge/CRG-$$grade-$$color?style=flat-square)](https://github.com/hyperpolymath/standards/tree/main/component-readiness-grades)"
