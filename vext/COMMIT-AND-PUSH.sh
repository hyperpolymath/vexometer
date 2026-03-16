#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Script to commit and push vext repository to GitHub

set -e  # Exit on error

echo "🚀 Vext Repository Setup and Push Script"
echo "========================================"

# Navigate to repo
cd /var/mnt/eclipse/repos/vext

# Copy documentation from home directory
echo "📄 Copying documentation files..."
mkdir -p docs
cp /var/home/hyper/VEXT-MANIFESTO.md docs/ 2>/dev/null || echo "  ⚠️  VEXT-MANIFESTO.md not found"
cp /var/home/hyper/VEXT-TECHNICAL-SPEC.md docs/ 2>/dev/null || echo "  ⚠️  VEXT-TECHNICAL-SPEC.md not found"
cp /var/home/hyper/VEXT-MOBILE-SMS-EMAIL.md docs/ 2>/dev/null || echo "  ⚠️  VEXT-MOBILE-SMS-EMAIL.md not found"
cp /var/home/hyper/VEXT-ADDITIONAL-PROTOCOLS.md docs/ 2>/dev/null || echo "  ⚠️  VEXT-ADDITIONAL-PROTOCOLS.md not found"
cp /var/home/hyper/VEXT-MULTICAST-ARCHITECTURE.md docs/ 2>/dev/null || echo "  ⚠️  VEXT-MULTICAST-ARCHITECTURE.md not found"
cp /var/home/hyper/VEXT-ANTI-ALGORITHM-ARCHITECTURE.md docs/ 2>/dev/null || echo "  ⚠️  VEXT-ANTI-ALGORITHM-ARCHITECTURE.md not found"
cp /var/home/hyper/VEXT-ARXIV-PAPER-PLAN.md docs/ 2>/dev/null || echo "  ⚠️  VEXT-ARXIV-PAPER-PLAN.md not found"
cp /var/home/hyper/NUJ-VEXT-PROPOSAL.md docs/ 2>/dev/null || echo "  ⚠️  NUJ-VEXT-PROPOSAL.md not found"

echo "✅ Documentation copied"

# Create basic LICENSE file
echo "📜 Creating LICENSE file..."
cat > LICENSE << 'EOL'
Palimpsest License (PMPL-1.0-or-later)

Copyright (c) 2025 Jonathan D.A. Jewell

This software is licensed under the Palimpsest License, version 1.0 or later.

For the full license text, see:
https://github.com/hyperpolymath/palimpsest-license/blob/main/LICENSE-1.0.txt

SPDX-License-Identifier: PMPL-1.0-or-later
EOL

# Create CONTRIBUTING.md
echo "📝 Creating CONTRIBUTING.md..."
cat > CONTRIBUTING.md << 'EOL'
# Contributing to Vext

Thank you for your interest in contributing to Vext!

## Prerequisites

- **Idris2** (required for a2ml specification)
- **Rust** (for implementation)
- **Git**

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR-USERNAME/vext`
3. Create a branch: `git checkout -b feature/your-feature`
4. Make changes
5. Test thoroughly
6. Commit: `git commit -m "Description" -m "Co-Authored-By: Your Name <your@email>"`
7. Push: `git push origin feature/your-feature`
8. Open Pull Request

## Areas We Need Help

- **Idris2 expertise** - a2ml specification
- **Cryptography review** - Security analysis
- **NNTP integration** - Protocol implementation
- **Documentation** - Improve clarity
- **Testing** - Property-based tests, fuzzing

## Code Standards

- Follow language conventions (rustfmt, idris2 style)
- Add SPDX headers to all files
- Write tests for new code
- Update documentation

## Questions?

Open a GitHub Discussion or contact: j.d.a.jewell@open.ac.uk
EOL

# Create SECURITY.md
echo "🔒 Creating SECURITY.md..."
cat > SECURITY.md << 'EOL'
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.x.x   | :white_check_mark: (development) |

## Reporting a Vulnerability

**DO NOT** open a public issue for security vulnerabilities.

Instead, email: security@vext.org (or j.d.a.jewell@open.ac.uk until domain is set up)

Include:
- Description of vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will respond within 48 hours and provide updates on the fix timeline.

## Security Guarantees

Vext provides cryptographic proofs of:
- Feed chronological ordering (Merkle tree commitments)
- No ad injection (content-type verification)
- Message authenticity (Ed25519 signatures)

These are **mathematically provable**, not just policy-based.

## Cryptographic Assumptions

Vext security relies on:
- Ed25519 signature security (NIST standard)
- SHA-256 collision resistance (NIST standard)
- Idris2 type-level proofs (formal verification)

If any of these are broken, vext security may be compromised.

## Verification

Users can verify feed integrity using:
```bash
vext verify <feed-url>
```

This checks:
1. Server signature validity
2. Merkle root correctness
3. Policy compliance (chronological, no ads)

**Don't trust us. Verify the cryptography.**
EOL

# Initialize git if needed
if [ ! -d .git ]; then
    echo "🔧 Initializing git repository..."
    git init
fi

# Add all files
echo "📦 Adding files to git..."
git add .

# Check if anything to commit
if git diff --cached --quiet; then
    echo "⚠️  No changes to commit"
    exit 0
fi

# Commit
echo "💾 Committing changes..."
git commit -m "$(cat <<'EOF'
feat: initial vext repository with comprehensive documentation

Complete vext protocol specification and roadmap including:
- README.adoc with project overview and architecture
- ROADMAP.md with 5-phase implementation plan
- STATE.scm with current project state and milestones
- ECOSYSTEM.scm describing vext's position in broader ecosystem
- META.scm with ADRs and design philosophy
- Documentation suite (manifesto, technical spec, architecture)
- arXiv paper plan (cs.CR publication)
- NUJ Ethics Council proposal

Key innovations:
- a2ml (Anti-Algorithm Markup Language) requires Idris2 dependent types
- Cryptographic proofs of chronological ordering (Merkle trees)
- Mathematical guarantees of no algorithms, no ads
- Built on proven protocols (NNTP) with modern cryptography

Status: Research phase, a2ml specification in design

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"

echo "✅ Committed successfully!"

# Create GitHub repo and push
echo "🌐 Creating GitHub repository..."
if ! gh repo view hyperpolymath/vext &>/dev/null; then
    gh repo create hyperpolymath/vext \
        --public \
        --description "Cryptographically verifiable communications protocol with proof of algorithmic neutrality" \
        --homepage "https://vext.org" \
        || echo "⚠️  Failed to create GitHub repo (may already exist)"
fi

# Add remote if not exists
if ! git remote get-url origin &>/dev/null; then
    echo "🔗 Adding remote origin..."
    git remote add origin https://github.com/hyperpolymath/vext.git
fi

# Push to GitHub
echo "⬆️  Pushing to GitHub..."
git branch -M main
git push -u origin main

echo ""
echo "✅ SUCCESS! Repository pushed to GitHub"
echo "📍 URL: https://github.com/hyperpolymath/vext"
echo ""
echo "Next steps:"
echo "1. Visit https://github.com/hyperpolymath/vext to verify"
echo "2. Enable GitHub Pages (Settings → Pages → Source: main branch, /docs)"
echo "3. Start implementing a2ml specification in Idris2"
echo "4. Begin arXiv paper draft"
echo ""
echo "🚀 Vext is live!"
