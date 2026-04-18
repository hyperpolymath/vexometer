# Maintainers

**SPDX-License-Identifier: PMPL-1.0-or-later

This document lists the maintainers of the vext project and their areas of responsibility.

## 🏛️ Governance Model

vext uses the **Tri-Perimeter Contribution Framework (TPCF)**, a graduated trust model that balances security with openness. See [governance/PROJECT_GOVERNANCE.md](governance/PROJECT_GOVERNANCE.md) for full details.

### Perimeter 1: Core Maintainers
**Responsibilities**: Architecture decisions, security reviews, release management, strategic direction

### Perimeter 2: Active Contributors
**Responsibilities**: Code review, issue triage, documentation, community support

### Perimeter 3: Community
**Responsibilities**: Contributions, testing, feedback, bug reports

## 👥 Core Maintainers (Perimeter 1)

### Lead Maintainer

**Name**: [Primary Maintainer]
- **Email**: lead@vext.dev
- **GitHub**: @maintainer
- **GitLab**: @maintainer
- **Areas**: Overall project direction, releases, security
- **Timezone**: UTC-5 (EST/EDT)
- **Active Since**: 2025-01

### Core Team

**Name**: [Core Developer 1]
- **Email**: dev1@vext.dev
- **GitHub**: @dev1
- **GitLab**: @dev1
- **Areas**: IRC protocol implementation, network layer
- **Timezone**: UTC+0 (GMT)
- **Active Since**: 2025-01

**Name**: [Core Developer 2]
- **Email**: dev2@vext.dev
- **GitHub**: @dev2
- **GitLab**: @dev2
- **Areas**: Build systems, CI/CD, release automation
- **Timezone**: UTC+8 (CST)
- **Active Since**: 2025-01

## 🌟 Active Contributors (Perimeter 2)

Active contributors have demonstrated consistent, quality contributions and assist with:
- Code review
- Issue triage
- Documentation improvements
- Community support

**Name**: [Contributor 1]
- **GitHub**: @contributor1
- **Areas**: Documentation, user support
- **Active Since**: 2025-01

**Name**: [Contributor 2]
- **GitHub**: @contributor2
- **Areas**: Testing, quality assurance
- **Active Since**: 2025-01

## 📋 Areas of Responsibility

### IRC Protocol & Network Layer
**Lead**: [Core Developer 1]
- IRC RFC 1459 implementation
- Connection management
- Protocol extensions (TLS, SASL)

**Reviewers**: @dev1, @lead

### Configuration & CLI
**Lead**: [Core Developer 2]
- Command-line interface
- Configuration file parsing
- Daemon management

**Reviewers**: @dev2, @lead

### VCS Integrations
**Lead**: [Core Developer 1]
- Git hooks
- Mercurial integration
- Subversion support

**Reviewers**: @dev1, @contributor1

### Build & Release
**Lead**: [Core Developer 2]
- Justfile, Makefile
- Nix flakes
- CI/CD pipelines
- Release process

**Reviewers**: @dev2, @lead

### Documentation
**Lead**: [Contributor 1]
- README, guides, tutorials
- API documentation
- Examples and recipes

**Reviewers**: @contributor1, @dev2

### Security
**Lead**: [Lead Maintainer]
- Security reviews
- Vulnerability assessment
- Security advisories

**Reviewers**: @lead, @dev1 (security team only)

### Community & Support
**Lead**: [Contributor 1]
- Issue triage
- Discussion moderation
- User support

**Reviewers**: @contributor1, @contributor2

## 🔐 Security Team

The security team handles confidential security issues:

- **Lead**: [Lead Maintainer] (lead@vext.dev)
- **Members**: [Core Developer 1] (dev1@vext.dev)
- **Contact**: security@vext.dev
- **PGP Keys**: See `.well-known/security.txt`

See [SECURITY.md](SECURITY.md) for vulnerability disclosure process.

## 🗳️ Decision Making

### Minor Decisions
- **Who**: Any core maintainer
- **Process**: Direct commit or self-merge PR
- **Examples**: Bug fixes, documentation updates, small refactors

### Major Decisions
- **Who**: Consensus among core maintainers
- **Process**: RFC (Request for Comments) in issues/discussions
- **Examples**: Architecture changes, new features, breaking changes
- **Timeline**: Minimum 7 days for community feedback

### Critical Decisions
- **Who**: All core maintainers must agree
- **Process**: Formal vote with public record
- **Examples**: License changes, governance changes, repository transfers
- **Timeline**: Minimum 30 days for community feedback

### Voting Process
1. **Proposal**: Create RFC with detailed rationale
2. **Discussion**: Community feedback period (7-30 days)
3. **Vote**: Core maintainers vote (+1, 0, -1)
4. **Resolution**:
   - Major: 2/3 majority
   - Critical: Unanimous
5. **Record**: Document decision and rationale

### Conflict Resolution
If consensus cannot be reached:
1. **Mediation**: Uninvolved maintainer mediates
2. **Vote**: Formal vote if mediation fails
3. **Escalation**: Community vote for governance changes

## 🚀 Release Process

### Release Managers
- **Primary**: [Lead Maintainer]
- **Backup**: [Core Developer 2]

### Release Schedule
- **Major** (X.0.0): Annually or as needed
- **Minor** (x.Y.0): Quarterly (Jan, Apr, Jul, Oct)
- **Patch** (x.y.Z): As needed for bug fixes
- **Security**: Immediately upon fix availability

### Release Checklist
1. All tests pass
2. Documentation updated
3. CHANGELOG.md updated
4. Version numbers bumped
5. Security review completed
6. Release notes prepared
7. Tagged and signed with GPG
8. Uploaded to package repositories
9. Announced to community

See `docs/release/RELEASE_PROCESS.md` for detailed steps.

## 🎓 Becoming a Maintainer

### Path to Perimeter 2 (Active Contributor)
**Requirements**:
- 5+ merged pull requests
- Consistent quality contributions
- Understanding of codebase and architecture
- Adherence to Code of Conduct
- Active for 3+ months

**Process**:
1. Express interest to existing maintainers
2. Current maintainers discuss and vote
3. Invitation extended if consensus reached
4. Onboarding and mentorship period

### Path to Perimeter 1 (Core Maintainer)
**Requirements**:
- All Perimeter 2 requirements
- Deep expertise in project domain
- Strong architectural judgment
- Proven leadership and mentorship
- Consistent contributions for 6+ months
- Endorsement by 2+ current core maintainers

**Process**:
1. Nomination by existing core maintainer
2. Discussion among core team
3. Unanimous approval required
4. Public announcement
5. Access granted incrementally

## 📤 Stepping Down

Maintainers may step down voluntarily:

1. **Announce** intent to step down (minimum 2 weeks notice)
2. **Transfer** responsibilities to other maintainers
3. **Document** ongoing work and context
4. **Update** this document
5. **Retain** emeritus status if desired

### Emeritus Maintainers
Former maintainers who retain advisory role:
- Listed in CONTRIBUTORS.md
- May be consulted on major decisions
- Retain community respect and recognition

## 🔄 Inactive Maintainers

If a maintainer is inactive for 6+ months without notice:
1. Attempt to contact via multiple channels
2. If no response after 30 days, mark as inactive
3. Redistribute responsibilities
4. Offer emeritus status
5. Remove write access (can be restored upon return)

## 📊 Maintainer Statistics

**Current Team Size**:
- Perimeter 1 (Core): 3 maintainers
- Perimeter 2 (Active): 2 contributors
- Perimeter 3 (Community): Open to all

**Geographic Distribution**:
- Americas: 1
- Europe: 1
- Asia: 1

**Timezone Coverage**: 24-hour coverage across all timezones

## 📞 Contacting Maintainers

### General Inquiries
- **Email**: maintainers@vext.dev
- **Matrix**: #vext-dev:matrix.org
- **Discussions**: GitHub/GitLab discussions

### Specific Areas
- **Security**: security@vext.dev
- **Releases**: release@vext.dev
- **Governance**: governance@vext.dev

### Individual Contact
Contact individual maintainers for their specific areas of responsibility. See email addresses above.

## 🙏 Acknowledgments

We thank all maintainers, past and present, for their contributions:

- **Current Maintainers**: See lists above
- **Emeritus Maintainers**: Listed in CONTRIBUTORS.md
- **All Contributors**: Listed in CONTRIBUTORS.md

## 📄 Historical Context

### Original Project
vext is a Rhodium Standard Edition fork of **irker** by Eric S. Raymond:
- Original repository: https://gitlab.com/esr/irker
- Original author: Eric S. Raymond (esr)
- Fork date: 2025-01-01
- Fork rationale: Modernization, active maintenance, comprehensive documentation

We acknowledge and thank Eric S. Raymond for creating irker and releasing it under an open source license.

## 📝 Document History

- **2025-01-01**: Initial version for vext fork
- **Version**: 1.0
- **Next Review**: 2025-04-01

---

**This document is maintained by**: [Lead Maintainer]
**Last Updated**: 2025-01-01

For questions about governance, see [governance/PROJECT_GOVERNANCE.md](governance/PROJECT_GOVERNANCE.md).
For questions about contributing, see [CONTRIBUTING.md](CONTRIBUTING.md).
