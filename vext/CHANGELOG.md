# Changelog

**SPDX-License-Identifier: PMPL-1.0-or-later

All notable changes to vext will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- RSR (Rhodium Standard Repository) compliance framework
- Comprehensive documentation suite (README, INSTALLATION, USAGE, FEATURES)
- Palimpsest dual licensing (PMPL-1.0-or-later)
- Tri-Perimeter Contribution Framework (TPCF) governance
- RFC 9116 compliant `.well-known/security.txt`
- AI training policy (`.well-known/ai.txt`)
- Team attribution (`.well-known/humans.txt`)
- Automated RSR compliance checker (`tools/rsr_checker.py`)
- Nix flakes for reproducible builds (`flake.nix`)
- Justfile for build automation
- GitLab CI/CD configuration
- Comprehensive security policy (SECURITY.md)
- Code of Conduct with emotional safety framework
- Contribution guidelines (CONTRIBUTING.md)
- Maintainer documentation (MAINTAINERS.md)

### Changed
- Forked from irker to vext (Rhodium Standard Edition)
- Modernized documentation structure
- Enhanced security policies and procedures
- Improved governance model

### Deprecated
- (None yet)

### Removed
- (None yet)

### Fixed
- (None yet)

### Security
- Implemented comprehensive security.txt (RFC 9116)
- Added vulnerability disclosure process
- Defined security review procedures

## [1.0.0] - 2025-01-01

### Added
- Initial release of vext (Rhodium Standard Edition)
- Fork from irker with modernization focus
- Complete documentation overhaul
- RSR Bronze level compliance achieved
- RSR Silver level compliance achieved
- Community governance framework (TPCF)
- Automated build and testing infrastructure
- Security-first design principles

### Changed
- Rebranded from irker to vext
- Updated all documentation to modern standards
- Enhanced configuration options
- Improved error handling and logging

## [0.1.0] - 2025-01-01

### Added
- Initial fork from irker
- Basic project structure
- Core IRC notification functionality
- Multi-VCS support (Git, Mercurial, SVN)
- JSON protocol support
- TCP and UDP communication
- Rate limiting and flood prevention
- Connection pooling
- Multi-channel broadcasting
- Color formatting support

### Technical Debt
- Documentation needs modernization
- Security policies need formalization
- Build system needs standardization
- Governance model needs definition

---

## Version History Summary

| Version | Date       | Significance | RSR Level |
| ------- | ---------- | ------------ | --------- |
| 1.0.0   | 2025-01-01 | Initial release with RSR compliance | Silver |
| 0.1.0   | 2025-01-01 | Fork from irker | None |

## Release Notes Archive

Detailed release notes for each version are available in `docs/releases/`:
- [v1.0.0 Release Notes](docs/releases/v1.0.0.md)

## Migration Guides

### From irker to vext

See [docs/migration/FROM_IRKER.md](docs/migration/FROM_IRKER.md) for detailed migration instructions.

**Quick Summary**:
- vext is backward-compatible with irker configuration
- No breaking changes in core functionality
- Enhanced features are opt-in
- Migration is primarily documentation and governance updates

**Key Differences**:
- Modernized documentation
- Formal security policies
- Governance framework
- Reproducible builds
- CI/CD automation

## Compatibility Matrix

| vext Version | Python Version | Supported VCS | IRC Servers |
| ------------ | -------------- | ------------- | ----------- |
| 1.0.0        | 3.6+           | Git, Hg, SVN  | RFC 1459    |
| 0.1.0        | 3.6+           | Git, Hg, SVN  | RFC 1459    |

## Deprecation Policy

We follow a gradual deprecation process:

1. **Announcement**: Feature marked as deprecated in changelog
2. **Warning Period**: Minimum 2 minor versions or 6 months
3. **Deprecation**: Feature issues warnings when used
4. **Removal**: Feature removed in next major version

### Current Deprecations
- (None)

### Planned Deprecations
- (None)

## Security Updates

Security updates are released as soon as fixes are available and tested.

### Security Advisories

| Date       | Severity | CVE | Description | Fixed In |
| ---------- | -------- | --- | ----------- | -------- |
| (None yet) | -        | -   | -           | -        |

See [SECURITY.md](SECURITY.md) for vulnerability disclosure process.

## Breaking Changes

We avoid breaking changes whenever possible. When necessary, they are:
- Documented in detail
- Announced at least one major version in advance
- Include migration guides
- Provide backward compatibility shims when feasible

### Major Version Breaking Changes

**2.0.0** (Future):
- (None planned yet)

**1.0.0**:
- Repository rename: irker → vext
- License change: BSD-2-Clause → PMPL-1.0-or-later (Palimpsest)
  - Note: Both are permissive; users can choose MIT for backward compatibility

## Contribution Credits

See [CONTRIBUTORS.md](CONTRIBUTORS.md) for full list of contributors.

### Major Contributors by Version

**1.0.0**:
- [Lead Maintainer] - Project lead, RSR compliance, documentation
- [Core Developer 1] - IRC protocol, network layer
- [Core Developer 2] - Build systems, CI/CD

**0.1.0**:
- Eric S. Raymond - Original irker author

## Release Channels

### Stable
- **Version**: 1.0.0
- **Support**: Full support with security updates
- **Recommended For**: Production use

### Development
- **Branch**: `main`
- **Stability**: May contain breaking changes
- **Recommended For**: Testing, early adopters

### Long-Term Support (LTS)
- **Version**: (None yet)
- **Support**: Extended security and bug fix support
- **Recommended For**: Enterprise deployments

## Changelog Maintenance

This changelog is:
- **Updated**: With every release
- **Format**: [Keep a Changelog](https://keepachangelog.com/)
- **Versioning**: [Semantic Versioning](https://semver.org/)
- **Maintained By**: Release managers (see [MAINTAINERS.md](MAINTAINERS.md))

## Comparison with Upstream (irker)

| Feature | irker | vext | Notes |
| ------- | ----- | ---- | ----- |
| Core IRC functionality | ✅ | ✅ | Fully compatible |
| Multi-VCS support | ✅ | ✅ | Git, Hg, SVN |
| JSON protocol | ✅ | ✅ | Identical |
| Documentation | Basic | Comprehensive | Major improvement |
| Security policies | Informal | Formal | RFC 9116 compliant |
| Build system | Basic | Modern | Nix, just, CI/CD |
| Governance | None | TPCF | Formal framework |
| Testing | Limited | Comprehensive | Automated testing |
| RSR compliance | None | Silver | Structured standards |

## Historical Context

**vext** is a modernized fork of **irker** by Eric S. Raymond:
- **Original Project**: https://gitlab.com/esr/irker
- **Fork Date**: 2025-01-01
- **Fork Reason**: Active maintenance, comprehensive documentation, modern standards
- **Compatibility**: Full backward compatibility with irker
- **Acknowledgment**: We thank Eric S. Raymond for creating irker

## Future Roadmap

See [docs/roadmap/ROADMAP.md](docs/roadmap/ROADMAP.md) for detailed future plans.

**Upcoming**:
- 1.1.0: Enhanced monitoring and metrics
- 1.2.0: Additional IRC protocol extensions (SASL, TLS)
- 2.0.0: Architectural improvements, potential breaking changes

---

**Changelog Maintained By**: Release Team
**Last Updated**: 2025-01-01
**Format Version**: 1.0.0 (Keep a Changelog)

For questions about releases, contact: release@vext.dev
