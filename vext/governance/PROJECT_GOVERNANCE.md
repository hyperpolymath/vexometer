<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# Project Governance

**SPDX-License-Identifier: CC-BY-SA-4.0

## 🏛️ Overview

vext uses the **Tri-Perimeter Contribution Framework (TPCF)**, a graduated trust model that balances security, community openness, and sustainable project governance.

TPCF organizes contributors into three concentric perimeters based on trust, expertise, and responsibility.

## 🎯 Governance Philosophy

Our governance is designed to:

- **Foster Community**: Welcome contributors at all skill levels
- **Maintain Quality**: Ensure high standards through graduated responsibilities
- **Enable Security**: Protect critical infrastructure through access controls
- **Promote Transparency**: Make decisions openly and documentably
- **Support Sustainability**: Build long-term project health
- **Respect Autonomy**: Allow contributors to self-organize within guidelines

## 🔷 Three-Perimeter Model

```
┌──────────────────────────────────────────────────────┐
│                                                      │
│   Perimeter 3: Community (Open)                     │
│   ┌──────────────────────────────────────────┐      │
│   │                                          │      │
│   │  Perimeter 2: Active Contributors       │      │
│   │  ┌────────────────────────────────┐     │      │
│   │  │                                │     │      │
│   │  │  Perimeter 1: Core Maintainers │     │      │
│   │  │                                │     │      │
│   │  │  • Write access                │     │      │
│   │  │  • Security decisions          │     │      │
│   │  │  • Release management          │     │      │
│   │  │                                │     │      │
│   │  └────────────────────────────────┘     │      │
│   │                                          │      │
│   │  • Code review                           │      │
│   │  • Issue triage                          │      │
│   │  • Mentoring                             │      │
│   │                                          │      │
│   └──────────────────────────────────────────┘      │
│                                                      │
│   • Fork and PR                                      │
│   • Issues and discussions                           │
│   • Testing and feedback                             │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### Perimeter 1: Core Maintainers

**Access Level**: Full write access to repository

**Responsibilities**:
- Architectural decisions
- Security vulnerability response
- Release management and versioning
- Maintainer onboarding/offboarding
- Conflict resolution
- Strategic direction
- License and legal decisions
- Infrastructure management

**Requirements**:
- Deep expertise in project domain
- Proven track record of quality contributions
- Strong architectural judgment
- Commitment to project values
- Active for 6+ months
- Endorsed by 2+ current core maintainers
- Unanimous approval from existing core team

**Current Members**: See [MAINTAINERS.md](../MAINTAINERS.md)

### Perimeter 2: Active Contributors

**Access Level**: Triage permissions, reviewer status

**Responsibilities**:
- Code review for community PRs
- Issue triage and labeling
- Documentation improvements
- Community support and mentoring
- Testing and quality assurance
- Feature discussions and RFC participation

**Requirements**:
- 5+ merged pull requests
- Consistent quality contributions
- Understanding of codebase architecture
- Adherence to Code of Conduct
- Active for 3+ months
- Recommendation from core maintainer

**Path to Perimeter 1**:
- Demonstrate deep expertise
- Show leadership in specific areas
- Mentor new contributors
- 6+ months as active contributor
- Endorsement by 2+ core maintainers

### Perimeter 3: Community

**Access Level**: Public (fork and pull request)

**Responsibilities**:
- Submit bug reports and feature requests
- Contribute code via pull requests
- Improve documentation
- Test and provide feedback
- Participate in discussions
- Help other community members

**Requirements**:
- None! Everyone is welcome
- Follow Code of Conduct
- Respect community guidelines

**Path to Perimeter 2**:
- Make quality contributions over time
- Demonstrate understanding of project
- Show commitment to community values
- Request promotion after meeting requirements

## 📋 Decision-Making Process

### Minor Decisions

**Who**: Any core maintainer
**Process**: Direct implementation
**Examples**:
- Bug fixes
- Documentation updates
- Small refactors
- Dependency updates

**Timeline**: Immediate

### Major Decisions

**Who**: Consensus among core maintainers
**Process**: RFC (Request for Comments)
**Examples**:
- New features
- Architecture changes
- Breaking changes
- Governance modifications (minor)

**Timeline**: Minimum 7 days for community feedback

**RFC Process**:
1. Create issue with `[RFC]` prefix
2. Detail proposal with rationale
3. Community discussion (7+ days)
4. Core maintainers discuss and vote
5. 2/3 majority required
6. Decision documented and implemented

### Critical Decisions

**Who**: All core maintainers (unanimous)
**Process**: Formal vote with public record
**Examples**:
- License changes
- Major governance changes
- Repository transfers
- Project dissolution

**Timeline**: Minimum 30 days for community feedback

**Voting Process**:
1. Formal proposal with detailed rationale
2. Community feedback period (30 days)
3. Core maintainer discussion
4. Formal vote (+1, 0, -1)
5. Unanimous approval required
6. Public announcement with rationale
7. Implementation timeline

## 🗳️ Voting Guidelines

### Vote Types

- **+1**: Approve
- **0**: Neutral (abstain)
- **-1**: Block (must provide rationale and alternatives)

### Vote Requirements

| Decision Type | Threshold | Participation |
| ------------- | --------- | ------------- |
| Minor | 1 maintainer | Optional |
| Major | 2/3 majority | Encouraged |
| Critical | Unanimous | Required |

### Vote Conduct

- **Good Faith**: Votes based on project best interest
- **Rationale**: Blocks must include detailed reasoning
- **Alternatives**: Blockers should propose alternatives
- **Transparency**: Votes are public record
- **Time Limits**: 7 days for major, 30 days for critical

## 🤝 Conflict Resolution

### Level 1: Direct Discussion
- Contributors discuss directly
- Assume good faith
- Seek mutual understanding
- Document resolution

### Level 2: Mediator
- Uninvolved maintainer mediates
- Facilitate respectful dialogue
- Help find common ground
- Document outcome

### Level 3: Vote
- If mediation fails
- Core maintainers vote
- Decision is binding
- Document reasoning

### Level 4: Code of Conduct
- If conduct violations occur
- See [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md)
- Conduct team handles
- Separate from technical decisions

## 🔐 Security Governance

### Security Team

**Members**: Subset of core maintainers
**Communication**: Private channel for vulnerabilities
**Contact**: security@vext.dev

**Responsibilities**:
- Receive and triage vulnerability reports
- Coordinate security fixes
- Manage disclosure timeline
- Publish security advisories
- Maintain security.txt (RFC 9116)

**Process**: See [SECURITY.md](../SECURITY.md)

### Security Decision Making

- **Immediate Response**: Security team acts independently
- **Coordinated Disclosure**: 90-day maximum timeline
- **Public Advisory**: After fixes are available
- **Retrospectives**: Learn from incidents

## 📊 Transparency and Accountability

### Public Records

All governance decisions are publicly documented:

- **Issues/Discussions**: Technical decisions
- **RFCs**: Major proposals
- **Votes**: Formal voting records
- **Meeting Notes**: Maintainer meetings (if any)
- **CHANGELOG.md**: Version decisions
- **governance/**: Policy documents

### Reporting

- **Quarterly Reports**: Project health metrics
- **Annual Review**: Governance effectiveness
- **Transparency Reports**: Code of Conduct enforcement (anonymized)

### Accountability

- **Code Review**: All changes reviewed
- **Decision Rationale**: Documented reasoning
- **Feedback Loops**: Community input welcomed
- **Appeals Process**: Decisions can be appealed

## 🔄 Governance Evolution

This governance model can evolve:

### Amendment Process

1. **Proposal**: Any core maintainer can propose changes
2. **Discussion**: Minimum 30-day community feedback
3. **Vote**: Unanimous approval from core maintainers
4. **Implementation**: Update documentation
5. **Announcement**: Public communication of changes

### Review Schedule

- **Quarterly**: Light review of processes
- **Annually**: Comprehensive governance review
- **As Needed**: Emergency changes for critical issues

### Version History

| Version | Date       | Changes |
| ------- | ---------- | ------- |
| 1.0     | 2025-01-01 | Initial TPCF governance model |

## 🌟 Community Values

Our governance embodies these values:

### Emotional Safety
- **Psychological Safety**: Safe to experiment, question, disagree
- **Anxiety Reduction**: Clear processes, predictable outcomes
- **Stress Management**: Sustainable pace, no crunch culture
- **Compassionate Communication**: Assume good intent

### Inclusivity
- **Welcoming**: All backgrounds and skill levels
- **Accessibility**: Remove barriers to contribution
- **Diversity**: Actively seek diverse perspectives
- **Respect**: Value all contributions

### Quality
- **Excellence**: High standards with support
- **Testing**: Comprehensive test coverage
- **Review**: Thoughtful code review
- **Documentation**: Clear and complete

### Sustainability
- **Long-term**: Build for the future
- **Maintainer Health**: Prevent burnout
- **Succession**: Plan for transitions
- **Community**: Build resilient community

## 📚 Related Documents

- [MAINTAINERS.md](../MAINTAINERS.md) - Current team structure
- [CONTRIBUTING.md](../CONTRIBUTING.md) - How to contribute
- [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) - Community standards
- [SECURITY.md](../SECURITY.md) - Security policies

## 📞 Contact

- **Governance Questions**: governance@vext.dev
- **Maintainer Application**: maintainers@vext.dev
- **General**: hello@vext.dev

## 📄 License

This governance document is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

---

**Last Updated**: 2025-01-01
**Version**: 1.0
**Next Review**: 2025-04-01

Governance maintained by: Core Maintainers (see [MAINTAINERS.md](../MAINTAINERS.md))
