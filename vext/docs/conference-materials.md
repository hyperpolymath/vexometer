# Conference Materials - vext

**SPDX-License-Identifier: MPL-2.0

This document contains talk proposals, abstracts, and presentation materials for vext (Rhodium Standard Edition of irker).

## 🎤 Talk Proposals

### 1. IRC Notifications Done Right: Introducing vext

**Target Conferences**: FOSDEM, PyCon, OSCON

**Duration**: 30 minutes

**Abstract**:

Version control notifications are essential for team coordination, but most solutions create IRC join/leave spam or require complex integrations. vext (Rhodium Standard Edition of irker) solves this with a lightweight daemon that maintains persistent IRC connections while accepting notifications via simple JSON over TCP/UDP.

This talk introduces vext's architecture, demonstrates integration with Git/Mercurial/SVN, and showcases the Tri-Perimeter Contribution Framework (TPCF) governance model that makes the project sustainable and welcoming.

**Key Takeaways**:
- How persistent IRC connections reduce channel noise
- Integrating vext with your VCS infrastructure
- Building sustainable open source projects with TPCF

**Audience**: DevOps engineers, sysadmins, open source maintainers

### 2. Tri-Perimeter Contribution Framework: Graduated Trust in Open Source

**Target Conferences**: FOSDEM (Community Devroom), OSCON, All Things Open

**Duration**: 20 minutes (Lightning talk)

**Abstract**:

How do you balance open contribution with security and project quality? The Tri-Perimeter Contribution Framework (TPCF) implements graduated trust with three concentric circles: Core Maintainers (Perimeter 1), Active Contributors (Perimeter 2), and Community (Perimeter 3).

Drawing from vext's implementation, this talk presents TPCF as a governance pattern that welcomes newcomers while protecting critical infrastructure. Learn how to apply TPCF to your own projects for sustainable, inclusive growth.

**Key Takeaways**:
- Three-perimeter trust model fundamentals
- Practical implementation in small/medium projects
- Measuring governance effectiveness

**Audience**: Project maintainers, community managers, governance enthusiasts

### 3. Rhodium Standard Repository: Excellence in Open Source Packaging

**Target Conferences**: PyCon, FOSDEM, SCALE

**Duration**: 45 minutes

**Abstract**:

What makes a repository "production-ready"? The Rhodium Standard Repository (RSR) framework defines Bronze, Silver, Gold, and Platinum compliance levels covering documentation, security, build systems, testing, and governance.

This talk walks through vext's journey to RSR Silver compliance, demonstrating automated compliance checking, Nix-based reproducible builds, RFC 9116 security.txt implementation, and Palimpsest dual licensing. Attendees will learn actionable steps to elevate their own projects.

**Key Takeaways**:
- RSR compliance levels and requirements
- Automated compliance verification tooling
- Practical path from Bronze to Silver compliance

**Audience**: Python developers, DevOps, project maintainers

## 📊 Slide Deck Outlines

### Talk 1: IRC Notifications Done Right (30 min)

**Slide Structure**:

1. **Title** (1 min)
   - vext: Rhodium Standard Edition of irker
   - Speaker introduction

2. **Problem Statement** (3 min)
   - IRC join/leave spam from per-commit scripts
   - Delayed notifications with cron-based solutions
   - Complex setups with dedicated bots

3. **Solution: vext Architecture** (5 min)
   - Persistent daemon maintains IRC connections
   - JSON protocol over TCP/UDP
   - VCS hooks send notifications to daemon
   - Demo: Message flow diagram

4. **Integration Examples** (10 min)
   - Git post-receive hook
   - Mercurial integration
   - Subversion post-commit
   - Multi-channel routing
   - Live demo: Push commit, see IRC notification

5. **TPCF Governance** (5 min)
   - Three-perimeter trust model
   - Community, Active Contributors, Core Maintainers
   - Sustainable project health

6. **RSR Compliance** (4 min)
   - Silver level achievement
   - Automated compliance checking
   - Reproducible builds with Nix

7. **Q&A** (2 min)
   - Questions and discussion

## 🎯 Submission Timeline

| Conference | Submission Deadline | Event Date | Status |
| ---------- | ------------------- | ---------- | ------ |
| FOSDEM 2026 | Nov 2025 | Feb 2026 | Planned |
| PyCon US 2026 | Dec 2025 | May 2026 | Planned |
| OSCON 2026 | Jan 2026 | Jul 2026 | Planned |
| SCALE 22x | Jan 2026 | Mar 2026 | Planned |

## 📝 Speaker Bio

**Short (100 words)**:

The vext team maintains the Rhodium Standard Edition of irker, a lightweight IRC notification daemon for version control systems. The project focuses on sustainable open source governance through the Tri-Perimeter Contribution Framework (TPCF) and achieves RSR Silver compliance with comprehensive documentation, security practices, and reproducible builds.

**Long (250 words)**:

The vext project represents a modernized, community-driven fork of irker (by Eric S. Raymond), bringing IRC notifications for version control systems into the era of comprehensive documentation, formal governance, and production-grade quality standards.

Our team implements the Tri-Perimeter Contribution Framework (TPCF), a graduated trust model that welcomes community contributions while maintaining project security and quality. We've achieved Rhodium Standard Repository (RSR) Silver compliance, demonstrating excellence in documentation, security policies (RFC 9116), reproducible builds (Nix), and automated compliance verification.

The project uses Palimpsest dual licensing (MPL-2.0) to support both permissive and copyleft use cases, and maintains backward compatibility with the original irker while adding modern features like comprehensive testing, CI/CD automation, and detailed operational guides.

## 🖼️ Slide Assets

### Diagrams

1. **Architecture Diagram**: VCS → Hook → JSON → Daemon → IRC
2. **TPCF Model**: Three concentric circles showing perimeter levels
3. **Message Flow**: Detailed sequence diagram of notification path

### Code Samples

```python
# Git hook example
#!/usr/bin/env python3
import json, socket

notification = {
    "to": "irc://irc.libera.chat#commits",
    "privmsg": "New commit by alice: Fix authentication bug"
}

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(json.dumps(notification).encode(), ("localhost", 6659))
```

## 📧 Contact for Speaking Engagements

- **Email**: talks@vext.dev
- **Matrix**: #vext:matrix.org
- **General**: hello@vext.dev

---

**Last Updated**: 2025-01-01
**Maintained By**: vext Team
