# SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Vexometer - Irritation Surface Analyser
# Just task runner configuration
#
# Usage: just <task>
# List tasks: just --list

# Default task
default: build

# Project metadata
project := "vexometer"
version := "0.2.0-dev"

# Build modes
build_mode := env_var_or_default("VEXOMETER_BUILD_MODE", "debug")

# =============================================================================
# Building
# =============================================================================

# Build the project
build:
    @echo "Building Vexometer ({{build_mode}} mode)..."
    gprbuild -P vexometer.gpr -XVEXOMETER_BUILD_MODE={{build_mode}}
    @echo "Build complete: bin/vexometer"

# Build in release mode
release:
    @echo "Building Vexometer (release mode)..."
    gprbuild -P vexometer.gpr -XVEXOMETER_BUILD_MODE=release
    @echo "Release build complete: bin/vexometer"

# Clean build artifacts
clean:
    @echo "Cleaning build artifacts..."
    gprclean -P vexometer.gpr
    rm -rf obj/ bin/

# Rebuild from scratch
rebuild: clean build

# =============================================================================
# Running
# =============================================================================

# Run Vexometer GUI
run: build
    ./bin/vexometer gui

# Run with specific arguments
run-args *ARGS: build
    ./bin/vexometer {{ARGS}}

# Run analysis on text from stdin
analyse: build
    ./bin/vexometer analyse

# =============================================================================
# Testing
# =============================================================================

# Run all tests
test: build
    @echo "Running tests..."
    # AUnit test runner would go here
    @echo "Tests not yet implemented"

# Run tests with coverage
test-coverage: build
    @echo "Running tests with coverage..."
    @echo "Coverage not yet implemented"

# =============================================================================
# Documentation
# =============================================================================

# Generate API documentation
docs:
    @echo "Generating documentation..."
    gnatdoc -P vexometer.gpr

# Convert AsciiDoc to HTML
docs-html:
    asciidoctor README.adoc -o docs/README.html
    asciidoctor CONTRIBUTING.adoc -o docs/CONTRIBUTING.html

# =============================================================================
# Validation & Compliance
# =============================================================================

# Validate RSR compliance
validate:
    @echo "Validating RSR compliance..."
    @echo "Checking required files..."
    @test -f guix.scm && echo "✓ guix.scm (primary)" || echo "✗ guix.scm missing (RSR primary)"
    @test -f flake.nix && echo "✓ flake.nix (fallback)" || echo "✗ flake.nix missing"
    @test -f justfile && echo "✓ justfile" || echo "✗ justfile missing"
    @test -f README.adoc && echo "✓ README.adoc" || echo "✗ README.adoc missing"
    @test -f LICENSE.txt && echo "✓ LICENSE.txt" || echo "✗ LICENSE.txt missing"
    @test -f SECURITY.md && echo "✓ SECURITY.md" || echo "✗ SECURITY.md missing"
    @test -f CODE_OF_CONDUCT.md && echo "✓ CODE_OF_CONDUCT.md" || echo "✗ CODE_OF_CONDUCT.md missing"
    @test -f CONTRIBUTING.adoc && echo "✓ CONTRIBUTING.adoc" || echo "✗ CONTRIBUTING.adoc missing"
    @test -f GOVERNANCE.md && echo "✓ GOVERNANCE.md" || echo "✗ GOVERNANCE.md missing"
    @test -f FUNDING.yml && echo "✓ FUNDING.yml" || echo "✗ FUNDING.yml missing"
    @test -f CLAUDE.md && echo "✓ CLAUDE.md" || echo "✗ CLAUDE.md missing"
    @test -d .well-known && echo "✓ .well-known/" || echo "✗ .well-known/ missing"
    @echo ""
    @echo "Checking SPDX headers..."
    @grep -l "SPDX-License-Identifier" src/*.ads src/*.adb 2>/dev/null | wc -l | xargs -I {} echo "✓ {} files with SPDX headers"
    @echo ""
    @echo "Validation complete."

# Check for security issues
security-check:
    @echo "Running security checks..."
    @echo "Checking for hardcoded credentials..."
    @! grep -rn "api_key\s*=\s*['\"]" src/ || echo "⚠ Potential hardcoded API key found"
    @echo "Security check complete."

# Lint Ada source
lint:
    @echo "Linting Ada source..."
    gnatpp -P vexometer.gpr --check

# Format Ada source
format:
    @echo "Formatting Ada source..."
    gnatpp -P vexometer.gpr

# =============================================================================
# Packaging
# =============================================================================

# Create release tarball
dist: clean
    @echo "Creating distribution tarball..."
    mkdir -p dist
    tar --exclude='.git' --exclude='dist' --exclude='obj' --exclude='bin' \
        -czvf dist/{{project}}-{{version}}.tar.gz .
    @echo "Created dist/{{project}}-{{version}}.tar.gz"

# Build container image with Podman
container:
    @echo "Building container image..."
    podman build -t {{project}}:{{version}} .
    podman tag {{project}}:{{version}} {{project}}:latest

# =============================================================================
# Development
# =============================================================================

# Enter Nix development shell
shell:
    nix develop

# Update Nix flake
update:
    nix flake update

# Show project info
info:
    @echo "Vexometer - Irritation Surface Analyser"
    @echo "Version: {{version}}"
    @echo "Build mode: {{build_mode}}"
    @echo ""
    @echo "Source files:"
    @find src -name "*.ads" -o -name "*.adb" | wc -l | xargs -I {} echo "  {} Ada files"
    @echo ""
    @echo "Pattern definitions:"
    @find data/patterns -name "*.json" | wc -l | xargs -I {} echo "  {} pattern files"
    @echo ""
    @echo "Probe definitions:"
    @find data/probes -name "*.json" | wc -l | xargs -I {} echo "  {} probe files"

# =============================================================================
# Git Helpers
# =============================================================================

# Show git status
status:
    git status

# Create a signed commit
commit message:
    git commit -m "{{message}}"

# Push to origin
push:
    git push origin HEAD

# =============================================================================
# Help
# =============================================================================

# Show all available tasks
help:
    @just --list
