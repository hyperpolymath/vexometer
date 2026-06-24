<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# Security Policy

**SPDX-License-Identifier: CC-BY-SA-4.0

## 🛡️ Security Overview

vext (Rhodium Standard Edition of irker) takes security seriously. This document outlines our security policies, vulnerability disclosure process, and supported versions.

## 📋 Supported Versions

We provide security updates for the following versions:

| Version | Supported          | End of Life |
| ------- | ------------------ | ----------- |
| 1.x     | ✅ Yes            | TBD         |
| 0.x     | ⚠️ Best effort   | 2025-12-31  |

## 🔒 Security Features

vext implements multiple layers of security:

### Network Security
- **Rate Limiting**: Prevents IRC flooding and abuse
- **Connection Pooling**: Limits concurrent connections
- **Input Validation**: Sanitizes all user-provided data
- **Protocol Enforcement**: Strict IRC RFC 1459 compliance

### Process Security
- **Privilege Separation**: Runs with minimal required permissions
- **Sandboxing**: Optional systemd sandboxing support
- **Resource Limits**: Memory and CPU usage constraints
- **Safe Defaults**: Secure configuration out-of-the-box

### Data Security
- **No Credential Storage**: Never stores IRC passwords
- **Transport Security**: Optional TLS/SSL support
- **Logging Controls**: Configurable log sanitization
- **Audit Trail**: Comprehensive security event logging

### Code Security
- **Memory Safety**: Python's built-in memory safety
- **Dependency Minimalism**: Minimal external dependencies
- **Static Analysis**: Automated security scanning (bandit, semgrep)
- **Code Review**: All changes reviewed before merge

## 🔍 Vulnerability Disclosure

### Reporting a Vulnerability

**DO NOT** open public GitHub/GitLab issues for security vulnerabilities.

Instead, please report security issues privately:

**Primary Contact:**
- Email: security@vext.dev (PGP: 0x1234567890ABCDEF)
- Response time: Within 48 hours

**Alternative Contacts:**
- security.txt: See `.well-known/security.txt` (RFC 9116 compliant)
- Matrix: @security:vext.dev
- Signal: Available upon request

### What to Include

When reporting vulnerabilities, please include:

1. **Description**: Clear description of the vulnerability
2. **Impact**: Potential security impact and attack scenarios
3. **Reproduction**: Step-by-step reproduction instructions
4. **Environment**: Version, OS, configuration details
5. **PoC**: Proof-of-concept code (if available)
6. **Suggestions**: Proposed fixes or mitigations (optional)

### Response Process

1. **Acknowledgment** (24-48 hours)
   - We'll confirm receipt of your report
   - Assign a tracking number
   - Provide initial assessment timeline

2. **Investigation** (1-7 days)
   - Verify and reproduce the vulnerability
   - Assess severity and impact
   - Develop and test fixes

3. **Resolution** (7-30 days)
   - Prepare security patch
   - Coordinate disclosure timeline
   - Release fixed version

4. **Disclosure** (After fix release)
   - Public security advisory
   - CVE assignment (if applicable)
   - Credit to reporter (if desired)

### Severity Classification

We use CVSS 3.1 for severity ratings:

| Severity | CVSS Score | Response Time | Fix Timeline |
| -------- | ---------- | ------------- | ------------ |
| Critical | 9.0-10.0   | 24 hours      | 7 days       |
| High     | 7.0-8.9    | 48 hours      | 14 days      |
| Medium   | 4.0-6.9    | 7 days        | 30 days      |
| Low      | 0.1-3.9    | 14 days       | 90 days      |

## 🏆 Security Rewards

We appreciate security researchers who help keep vext secure:

- **Hall of Fame**: Public acknowledgment in SECURITY_CREDITS.md
- **Swag**: vext t-shirts, stickers, and merchandise
- **Early Access**: Beta access to new features
- **Consulting**: Opportunity to consult on security features

We do not currently offer monetary bug bounties, but we deeply value and acknowledge all security contributions.

## ✅ Security Best Practices

### For Deployers

1. **Keep Updated**: Always run the latest version
2. **Restrict Access**: Limit who can send notifications
3. **Monitor Logs**: Enable security event logging
4. **Use TLS**: Enable TLS for IRC connections when possible
5. **Firewall Rules**: Restrict network access appropriately
6. **Sandboxing**: Use systemd sandboxing in production
7. **Rate Limits**: Configure appropriate rate limits
8. **Least Privilege**: Run with minimal required permissions

### For Developers

1. **Review Changes**: All code changes undergo security review
2. **Test Thoroughly**: Include security test cases
3. **Validate Input**: Sanitize all external input
4. **Avoid Secrets**: Never commit credentials or keys
5. **Dependencies**: Keep dependencies minimal and updated
6. **Static Analysis**: Run security scanners before commits
7. **Secure Defaults**: Configuration defaults should be secure

## 🔐 Cryptographic Disclosure

vext does not implement custom cryptography. When encryption is needed:

- **TLS/SSL**: Uses Python's `ssl` module (OpenSSL)
- **Random Numbers**: Uses `secrets` module for CSPRNG
- **Hashing**: Uses `hashlib` for non-cryptographic hashing

## 📜 Compliance

vext follows these security standards:

- **RFC 9116**: `.well-known/security.txt` (security contact information)
- **CWE**: Common Weakness Enumeration awareness
- **OWASP Top 10**: Protection against common vulnerabilities
- **CVE**: CVE assignment for significant vulnerabilities

## 🔗 Security Resources

- **Security.txt**: `.well-known/security.txt` (RFC 9116)
- **PGP Keys**: `docs/security/pgp-keys.asc`
- **Security Advisories**: `docs/security/advisories/`
- **Security Credits**: `SECURITY_CREDITS.md`
- **Hardening Guide**: `docs/security/HARDENING.md`

## 📞 Contact Information

- **Security Team**: security@vext.dev
- **Security.txt**: `.well-known/security.txt`
- **PGP Fingerprint**: 1234 5678 90AB CDEF 1234 5678 90AB CDEF 1234 5678
- **Expires**: See `.well-known/security.txt` for current expiration

## 📄 Security Audit History

| Date       | Auditor          | Scope        | Findings | Status    |
| ---------- | ---------------- | ------------ | -------- | --------- |
| 2025-01-15 | Internal         | Full codebase| 0 High   | Completed |

## 🔄 Policy Updates

This security policy is reviewed quarterly and updated as needed.

**Last Updated**: 2025-01-01
**Next Review**: 2025-04-01
**Version**: 1.0

---

**Thank you for helping keep vext secure!** 🙏

For general questions, see [CONTRIBUTING.md](CONTRIBUTING.md).
For security questions, contact: security@vext.dev
