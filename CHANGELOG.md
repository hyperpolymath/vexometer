<!--
SPDX-License-Identifier: MPL-2.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# Changelog

All notable changes to `vexometer` will be documented in this file.

This file is generated from conventional commits by the
[`changelog-reusable.yml`](https://github.com/hyperpolymath/standards/blob/main/.github/workflows/changelog-reusable.yml)
workflow (`hyperpolymath/standards#206`). Adopt the workflow in this repo's CI to keep this file in sync automatically — see
[`templates/cliff.toml`](https://github.com/hyperpolymath/standards/blob/main/templates/cliff.toml)
for the canonical config.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- feat(crg): add crg-grade and crg-badge justfile recipes
- feat: add stapeln.toml container definition
- feat: deploy UX Manifesto infrastructure
- feat(vext): replace template ABI with proper types, add V-lang API
- feat: add Groove discovery manifest for Vext
- feat: update Vext listener, pool, and protocol
- feat: add CLADE.a2ml — clade taxonomy declaration
- feat: add mirror.yml workflow for GitLab/Bitbucket mirroring
- feat: add CI gates and real vexometer core tests

### Fixed

- fix(ci): sync hypatia-scan.yml to canonical (413: env.HOME+Phase-2+SARIF) (#17)
- fix(ci): build Hypatia escript from repo root (estate dogfood drift)
- fix(ci): build Hypatia escript from repo root (estate dogfood drift)
- fix(ci): build Hypatia escript from repo root (estate dogfood drift)
- fix(deps): bump vulnerable crates to patched versions (#14)
- fix(ci): rsr-antipattern.yml duplicate heredoc (#15)
- fix: restructure prod expect("TODO") sites in vext-email-gateway + lazy-eliminator
- fix(manifest): correct 0-AI-MANIFEST — this is an ISA component, not the Vext protocol
- fix(deps): replace trust-dns-resolver with hickory-resolver and bump validator to resolve idna advisory
- fix(deps): update Cargo.lock to resolve security advisories

### Changed

- refactor: migrate 6SCM → 6A2 (.scm → .a2ml format)

### Documentation

- docs: substantive CRG C annotation (EXPLAINME.adoc)
- docs: add EXPLAINME.adoc — prove-it file backing README claims
- docs: add 0-AI-MANIFEST.a2ml (RSR compliance)

### CI

- ci: fix nonexistent actions/upload-artifact SHA pin (#16)
- ci(antipattern): fix top-level dir matching + benchmarks/lsp/bench filename allowlists (#12)
- ci(antipattern): TS check reads .claude/CLAUDE.md exemption table (#11)
- ci(antipattern): broaden TS allowlist (cli/, mod.ts, lsp-server, *vscode*, deno-*) (#10)
- ci(antipattern): allowlist legit TS bridge/adapter paths (#9)

## Pre-history

Prior commits to this file's introduction are recorded in git history but not formally classified into Keep-a-Changelog sections. To backfill, run `git cliff -o CHANGELOG.md` locally using the canonical [`cliff.toml`](https://github.com/hyperpolymath/standards/blob/main/templates/cliff.toml) — this is one-shot mechanical work.

---

<!-- This file was seeded by the 2026-05-26 estate tech-debt audit follow-up (Row-2 Phase 3); see [`hyperpolymath/standards/docs/audits/2026-05-26-estate-documentation-debt.md`](https://github.com/hyperpolymath/standards/blob/main/docs/audits/2026-05-26-estate-documentation-debt.md). -->
