<!-- SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell -->
<!-- SPDX-License-Identifier: MPL-2.0 -->

# CLAUDE.md - AI Assistant Guidance

## Project Overview

Vexometer is an Irritation Surface Analyser for AI assistants, written in Ada 2022.

## Key Commands

```bash
nix develop      # Enter dev environment
just build       # Build project
just run         # Run GUI
just test        # Run tests
just validate    # Check RSR compliance
```

## Architecture

- `src/vexometer-core.ads` - Core types
- `src/vexometer-patterns.ads` - Pattern detection
- `src/vexometer-probes.ads` - Behavioural probes
- `src/vexometer-api.ads` - LLM API clients
- `src/vexometer-gui.ads` - GtkAda interface
- `data/patterns/` - Pattern definitions (JSON)
- `data/probes/` - Probe test suites (JSON)

## Code Style

- Ada 2022 with SPARK annotations where applicable
- SPDX headers on all files
- 3-space indentation
- 100 character line limit

## RSR Compliance

This project follows Rhodium Standard Repositories. Run `just validate` to check.
