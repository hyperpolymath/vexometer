# SPDX-License-Identifier: PMPL-1.0-or-later
# vexometer unified justfile
# Author: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

# Default recipe: list available commands
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

# [AUTO-GENERATED] Multi-arch / RISC-V target
build-riscv:
	@echo "Building for RISC-V..."
	cross build --target riscv64gc-unknown-linux-gnu

# Run panic-attacker pre-commit scan
assail:
    @command -v panic-attack >/dev/null 2>&1 && panic-attack assail . || echo "panic-attack not found — install from https://github.com/hyperpolymath/panic-attacker"
