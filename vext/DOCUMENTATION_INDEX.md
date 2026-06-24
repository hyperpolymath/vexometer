<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# vext Documentation Index

## Quick Navigation

Welcome to the vext (Rhodium Standard Edition) documentation. This index helps you find the right guide for your needs.

### For New Users

Start here to understand what vext is and get it running:

1. **[README.md](README.md)** (Main Entry Point)
   - Project overview and description
   - Key features and technology stack
   - Installation requirements and basic usage
   - Architecture and design philosophy
   - **Read this first!**

2. **[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)**
   - Step-by-step installation instructions
   - Multiple installation methods (source, package manager, Docker)
   - Post-installation configuration
   - Repository-specific setup for Git, Mercurial, and SVN
   - Troubleshooting installation issues

3. **[USAGE_GUIDE.md](USAGE_GUIDE.md)**
   - Starting and managing the daemon
   - Sending notifications (basic and advanced)
   - Repository hook configuration
   - Configuration management
   - Monitoring and debugging
   - Advanced usage patterns

### For Understanding the Project

Learn more about what vext does and how it works:

4. **[PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)**
   - Problem statement and solution
   - Core concepts and architecture
   - Use cases and advantages
   - Comparison with alternatives
   - Deployment options
   - Roadmap and future enhancements

5. **[FEATURES.md](FEATURES.md)**
   - Comprehensive feature list
   - Multi-version control system support
   - Persistent connection management
   - Flexible communication protocols
   - Advanced features
   - Feature comparison matrix

### For Technical Details

Deep dive into the technical implementation:

6. **[TECHNOLOGY_STACK.md](TECHNOLOGY_STACK.md)**
   - Language and runtime information
   - Core and optional dependencies
   - Architecture components
   - Network protocols (IRC, JSON, HTTP)
   - Data flow architecture
   - Performance characteristics
   - Security technologies
   - Monitoring and observability

## Document Structure

### README.md (800 lines)
**Purpose**: Main project documentation, suitable for GitHub/GitLab README

**Covers**:
- 2-3 paragraph project description
- What irker does
- What vext improves
- Core functionality and use cases
- Key features (12 main features)
- Technology stack overview
- Installation requirements
- Basic usage examples
- Architecture overview
- Configuration options
- Use cases
- Troubleshooting guide
- License and status

**Best For**: Getting started, quick reference, GitHub visibility

---

### PROJECT_OVERVIEW.md (450 lines)
**Purpose**: Executive-level project overview and strategy

**Covers**:
- Executive summary
- Problem statement (5 problems solved)
- Solution approach
- Core concept with diagram
- Primary and secondary use cases
- Technical architecture
- Advantages comparison table
- Technology stack summary
- Installation footprint
- Security considerations
- Performance characteristics
- Scalability approach
- Maintenance model
- Comparison with original irker
- Deployment options
- Roadmap (short, medium, long term)

**Best For**: Understanding project goals, stakeholder communication, planning

---

### FEATURES.md (650 lines)
**Purpose**: Comprehensive feature documentation

**Covers**:
- 12 core features with detailed explanations
- Multi-VCS support (Git, Mercurial, SVN)
- Persistent connection management
- Flexible communication protocols (TCP, UDP, Email)
- JSON protocol details
- Multi-channel broadcasting
- Color formatting
- Configurable formats
- Rate limiting and flood prevention
- Comprehensive logging
- Flexible routing
- Performance optimization
- Security features
- 6 advanced features
- Feature comparison matrix

**Best For**: Feature comparison, capability assessment, planning integrations

---

### TECHNOLOGY_STACK.md (800 lines)
**Purpose**: Technical implementation details

**Covers**:
- Python language and version support
- Core dependencies (standard library only)
- Optional dependencies
- Development tools
- Architecture components with code examples
- Concurrency model and threading
- Event loop pattern
- Network protocols (IRC RFC 1459, JSON, HTTP)
- Data flow pipeline
- State management
- Performance profiles
- Deployment architecture
- System requirements
- Operating system support
- Systemd integration
- Configuration as code
- Security technologies
- Monitoring and observability
- Version management
- Integration points

**Best For**: Architecture understanding, integration planning, deployment design

---

### INSTALLATION_GUIDE.md (550 lines)
**Purpose**: Step-by-step installation and configuration

**Covers**:
- Prerequisites and requirements
- 4 installation methods:
  - From source with virtual environment
  - Package manager (Ubuntu, CentOS, macOS)
  - Docker container deployment
  - System-wide manual installation
- Post-installation configuration:
  - Config file creation
  - Log directory setup
  - Environment variables
- Repository-specific setup:
  - Git post-receive hook
  - Mercurial hook integration
  - Subversion hook configuration
- Testing procedures
- Troubleshooting common issues
- Uninstallation instructions

**Best For**: Getting vext running, setting up hooks, troubleshooting setup issues

---

### USAGE_GUIDE.md (700 lines)
**Purpose**: Operational guide for running vext

**Covers**:
- Quick start (3 steps)
- Daemon management:
  - Command-line options
  - Systemd service management
  - Manual service management
- Sending notifications:
  - Basic notifications
  - Multi-channel routing
  - Color formatting
  - Custom nicknames
  - Python script examples
  - TCP vs UDP
  - Bash script helpers
- Repository hook configuration:
  - Git (basic and advanced)
  - Mercurial
  - Subversion
- Configuration management
- Monitoring and troubleshooting:
  - Status checks
  - IRC connectivity testing
  - Hook debugging
  - Common issues
- Advanced usage patterns
- Performance tuning

**Best For**: Daily operations, troubleshooting, integration examples

---

### DOCUMENTATION_INDEX.md (This File)
**Purpose**: Navigation and organization guide

## File Statistics

- **Total Documentation Files**: 6 markdown files + this index
- **Total Lines**: ~2,935 lines of documentation
- **Total Coverage**:
  - Project overview and strategy
  - Complete feature list
  - Technical architecture
  - Installation procedures
  - Usage and operations
  - Troubleshooting and support

## Quick Reference by Topic

### Installation & Setup
- **Getting Started**: [README.md](README.md) → [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)
- **Docker Setup**: [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md#method-3-docker-container-deployment)
- **Git Hook Setup**: [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md#git-repository-hook-installation)
- **Post-Installation**: [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md#post-installation-configuration)

### Operation & Troubleshooting
- **Starting Daemon**: [USAGE_GUIDE.md](USAGE_GUIDE.md#starting-and-managing-the-daemon)
- **Sending Notifications**: [USAGE_GUIDE.md](USAGE_GUIDE.md#sending-notifications)
- **Debugging Issues**: [USAGE_GUIDE.md](USAGE_GUIDE.md#monitoring-and-troubleshooting)
- **Performance Tuning**: [USAGE_GUIDE.md](USAGE_GUIDE.md#performance-tuning)

### Features & Capabilities
- **Feature List**: [FEATURES.md](FEATURES.md)
- **VCS Support**: [FEATURES.md](FEATURES.md#1-multi-version-control-system-support)
- **Protocols**: [FEATURES.md](FEATURES.md#3-flexible-communication-protocols)
- **Advanced Features**: [FEATURES.md](FEATURES.md#advanced-features)

### Technical Details
- **Architecture**: [TECHNOLOGY_STACK.md](TECHNOLOGY_STACK.md#architecture-components)
- **Performance**: [TECHNOLOGY_STACK.md](TECHNOLOGY_STACK.md#performance-characteristics)
- **Security**: [TECHNOLOGY_STACK.md](TECHNOLOGY_STACK.md#security-technologies)
- **System Requirements**: [TECHNOLOGY_STACK.md](TECHNOLOGY_STACK.md#system-requirements)

### Project Information
- **Overview**: [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)
- **Use Cases**: [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md#use-cases)
- **Roadmap**: [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md#roadmap)

## Document Relationships

```
README.md (Entry Point)
├─ Quick overview
├─ Links to: INSTALLATION_GUIDE.md, USAGE_GUIDE.md
└─ References: FEATURES.md, TECHNOLOGY_STACK.md

PROJECT_OVERVIEW.md (Strategic View)
├─ What and why?
├─ References: README.md
└─ Links to: INSTALLATION_GUIDE.md, FEATURES.md

FEATURES.md (Capabilities)
├─ What can it do?
├─ References: README.md
└─ Links to: USAGE_GUIDE.md, TECHNOLOGY_STACK.md

TECHNOLOGY_STACK.md (Implementation)
├─ How is it built?
├─ References: README.md, FEATURES.md
└─ Links to: INSTALLATION_GUIDE.md

INSTALLATION_GUIDE.md (Getting Started)
├─ How to install?
├─ References: README.md
└─ Links to: USAGE_GUIDE.md, POST_CONFIGURATION

USAGE_GUIDE.md (Operations)
├─ How to use?
├─ References: INSTALLATION_GUIDE.md
└─ Links to: TROUBLESHOOTING
```

## Audience Guide

### Decision Makers / Managers
1. Start: [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)
2. Then: [FEATURES.md](FEATURES.md#comparison-feature-matrix)
3. Reference: [README.md](README.md#advantages-over-alternatives)

### Developers / System Administrators
1. Start: [README.md](README.md)
2. Then: [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)
3. Reference: [USAGE_GUIDE.md](USAGE_GUIDE.md), [TECHNOLOGY_STACK.md](TECHNOLOGY_STACK.md)

### Operations / DevOps Teams
1. Start: [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md#method-3-docker-container-deployment)
2. Then: [USAGE_GUIDE.md](USAGE_GUIDE.md#systemd-service-management)
3. Reference: [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md#deployment-options)

### Integrators / Developers Building on vext
1. Start: [TECHNOLOGY_STACK.md](TECHNOLOGY_STACK.md)
2. Then: [FEATURES.md](FEATURES.md#advanced-features)
3. Reference: [USAGE_GUIDE.md](USAGE_GUIDE.md#advanced-usage)

## Getting Help

### Common Questions

**"What is vext?"**
→ Read [README.md](README.md) (Project Overview section)

**"How do I install it?"**
→ Follow [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)

**"How do I use it?"**
→ See [USAGE_GUIDE.md](USAGE_GUIDE.md#quick-start)

**"Does it support my VCS?"**
→ Check [FEATURES.md](FEATURES.md#1-multi-version-control-system-support)

**"What are the requirements?"**
→ Review [README.md](README.md#installation-requirements)

**"How does it work?"**
→ Study [TECHNOLOGY_STACK.md](TECHNOLOGY_STACK.md#architecture-components)

**"Can I customize it?"**
→ See [FEATURES.md](FEATURES.md#advanced-features) and [USAGE_GUIDE.md](USAGE_GUIDE.md#advanced-usage)

**"What's the roadmap?"**
→ Check [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md#roadmap)

## Documentation Standards

All documentation follows these standards:

- **Markdown format** for GitHub/GitLab compatibility
- **Clear structure** with headers, sections, and subsections
- **Practical examples** for most features
- **Code blocks** with language specification
- **Tables** for comparisons and matrices
- **Links** between related documents
- **TOC-friendly** with descriptive headers
- **Accessible** to both technical and non-technical readers

## Contributing to Documentation

When adding new documentation:

1. Follow the structure and style of existing documents
2. Add new files and update this index
3. Link to related documents using markdown links
4. Include practical examples where applicable
5. Update the file statistics above
6. Ensure markdown validates correctly

## Version Information

- **Documentation Version**: 1.0
- **Last Updated**: 2025-11-22
- **vext Version**: Rhodium Standard Edition
- **Related Project**: irker (by Eric S. Raymond)

## License

All documentation is provided under the same license as vext: **Eclipse Public License 2.0**

---

**Start with [README.md](README.md) if you're new to vext!**

