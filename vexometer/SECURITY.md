<!-- SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell -->
<!-- SPDX-License-Identifier: MPL-2.0 -->

# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

**Do not report security vulnerabilities through public GitLab issues.**

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

### Language Choice
- Ada 2022 with SPARK subset for memory safety
- No pointer arithmetic
- Strong type checking at compile time

### Dependencies
- Minimal dependency tree
- All dependencies audited
- Nix for reproducible builds

### API Security
- API keys never logged or stored in plaintext
- Local-first architecture minimises data transmission
- No telemetry without explicit consent

## Threat Model

Vexometer processes potentially sensitive:
- User prompts
- Model responses
- API credentials

We assume:
- Local execution is trusted
- Remote APIs may be compromised
- Pattern databases may be manipulated

Mitigations are documented in `docs/SPECIFICATION.md`.
