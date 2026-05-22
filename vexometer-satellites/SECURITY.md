<!-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell -->
<!-- SPDX-License-Identifier: MPL-2.0 -->

# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |

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

## Scope

### This Repository

This umbrella repository contains:
- Documentation only (no executable code)
- JSON schema definitions for protocols
- Satellite registry metadata

Security concerns:
- Malicious satellite registry entries
- Protocol specification attacks
- Documentation injection

### Individual Satellites

Each satellite has its own SECURITY.md. Report satellite-specific vulnerabilities to that satellite's maintainers.

## Security Measures

### Documentation Integrity

- All protocol specs version-controlled
- Changes reviewed by maintainers
- SPDX headers track provenance

### Satellite Registry

- Links verified before merge
- Status updates require proof (repo existence, CI passing)
- No executable code in registry metadata

### Protocol Design

- vexometer-trace-v1: Read-only format (no code execution)
- vexometer-efficacy-v1: Statistical claims only (no side effects)
- JSON schemas validated against injection attacks

## Threat Model

This repository coordinates 12+ independent satellites. Threat vectors:

1. **Malicious satellite registration**: Attacker adds backdoored satellite to registry
   - *Mitigation*: Manual review of all registry additions

2. **Protocol manipulation**: Attacker modifies integration protocol to allow code injection
   - *Mitigation*: Version-controlled specs, schema validation

3. **Documentation injection**: Attacker embeds malicious links/scripts in docs
   - *Mitigation*: AsciiDoc parser security, link verification

4. **Supply chain attack**: Attacker compromises satellite template
   - *Mitigation*: vex-satellite-template has independent security review

## Satellite Security Standards

All registered satellites MUST:

- Include SECURITY.md
- Pass OpenSSF Scorecard
- Use memory-safe languages (Rust, Ada, Haskell, Elixir)
- Pin all dependencies with SHA hashes
- Enable branch protection (required reviews)

Satellites failing security standards will be marked ⚠️ in registry.
