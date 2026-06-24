<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
<!-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell -->
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

**Do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to: **security@jewell.dev**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

You will receive a response within 48 hours. If confirmed, we will:
1. Acknowledge the report
2. Work on a fix
3. Release a patch
4. Credit you (unless you prefer anonymity)

## Security Measures

### Language Safety

- Rust provides memory safety without GC
- No unsafe code blocks in core library
- All dependencies audited via cargo-audit

### Input Validation

- Code analysis is read-only (no execution)
- File paths validated before reading
- Regex patterns compiled once, validated

### Dependencies

- tree-sitter: Parser generator (trusted, maintained by GitHub)
- clap: CLI parsing (widely used, audited)
- serde: Serialization (de facto standard, audited)

All dependencies pinned with Cargo.lock for reproducibility.

## Threat Model

This tool analyzes potentially untrusted code:

1. **Malicious code patterns**: Analyzer reads but never executes code
2. **Path traversal**: File paths validated, no symlink following
3. **ReDoS attacks**: Regex patterns designed to avoid catastrophic backtracking
4. **Supply chain**: Dependencies audited, Cargo.lock committed

## Disclosure Policy

- We follow responsible disclosure
- 90-day disclosure timeline after patch release
- Security advisories published via GitHub Security Advisories
