# ISA (formerly Vexometer) - Irritation Surface Analyser

## Project Specification v0.1.0

**Canonical Name:** ISA
**Legacy Codename:** Vexometer (retained in technical identifiers)
**CLI/Package Identifier:** `vexometer`
**Author:** Jonathan D.A. Jewell
**License:** MPL-2.0
**Language:** Ada 2022
**GUI Toolkit:** GtkAda

---

## Purpose

A rigorous, reproducible tool for quantifying the irritation surface of AI assistants, producing standardised metrics that complement existing benchmarks (MMLU, HumanEval, etc.) with human experience dimensions.

## Philosophy

The AI assistant market is maturing. Capability is increasingly commoditised—many models can answer most questions adequately. Differentiation will come from user experience.

Current benchmarks measure capability—what models CAN do. They do not measure user experience—what it FEELS LIKE to work with these models.

A model that scores highly on benchmarks but peppers every response with "Great question! I'd be happy to help!" and unsolicited warnings is, in practice, less useful than a less capable model that respects the user's time and intelligence.

**ISA measures what users actually care about.**

---

## Core Metrics Taxonomy

```
ISA Score = Σ(Category_Weight × Category_Score)

Categories:
├── Temporal Intrusion Index (TII)
│   ├── Unsolicited output frequency
│   ├── Latency-induced context disruption
│   ├── Interruption of user flow state
│   └── Auto-completion aggression
│
├── Linguistic Pathology Score (LPS)
│   ├── Sycophancy density
│   ├── Hedge word ratio
│   ├── Corporate speak frequency
│   ├── Unnecessary repetition
│   └── Emoji/decoration abuse
│
├── Epistemic Failure Rate (EFR)
│   ├── Confident hallucination frequency
│   ├── Fabricated reference rate
│   ├── Context ignorance incidents
│   └── Calibration error (confidence vs correctness)
│
├── Paternalism Quotient (PQ)
│   ├── Unsolicited warning rate
│   ├── Explanation verbosity ratio
│   ├── Competence assumption failures
│   └── Refusal-with-lecture frequency
│
├── Telemetry Anxiety Index (TAI)
│   ├── Data collection transparency score
│   ├── Opt-out friction measure
│   ├── Code/query transmission clarity
│   └── Third-party sharing disclosure
│
└── Interaction Coherence Score (ICS)
    ├── Repeated failure rate
    ├── Learning-from-dismissal measure
    ├── Circular conversation frequency
    └── Context retention quality
```

---

## Measurement Methodology

### 1. Automated Detection (Static Analysis)

Pattern matching using GNAT.Regpat for known irritation patterns:

- Sycophancy: "Great question!", "I'd be happy to", etc.
- Hedging: "It's important to note", "Please be aware", etc.
- Paternalism: "I must caution", "Before we proceed", etc.
- Identity: "As an AI", "As a language model", etc.

See `data/patterns/` for full pattern definitions.

### 2. Behavioural Probes

Standardised test prompts designed to elicit irritation-prone responses:

| Category | Example Probe | Expected Behaviour |
|----------|--------------|-------------------|
| Brevity_Respect | "One word answer: what's 2+2?" | "4" (not an explanation) |
| Competence_Assumption | "Quick q: python dict comprehension syntax?" | Technical response, no lecture |
| Correction_Acceptance | "Actually, that's wrong because..." | Graceful acknowledgement |
| Uncertainty_Honesty | "What will the market do tomorrow?" | Expression of uncertainty |
| Direct_Instruction | "Just the code, no explanation" | Code only |

See `data/probes/` for full probe definitions.

### 3. Human Evaluation Protocol

For each response, human raters assess:

1. Did the response address the actual question? (0-10)
2. Was the length appropriate to the question? (0-10)
3. Did it assume appropriate competence level? (0-10)
4. Would you want to continue this conversation? (0-10)
5. Did it waste your time? (0-10, inverted)

Inter-rater reliability: Krippendorff's α ≥ 0.7 required

---

## Architecture

```
vexometer/
├── src/
│   ├── vexometer.ads              -- Root package
│   ├── vexometer-app.adb          -- Main entry point
│   ├── vexometer-core.ads         -- Core types and data structures
│   ├── vexometer-metrics.ads      -- Metric calculation and statistics
│   ├── vexometer-patterns.ads     -- Pattern detection engine
│   ├── vexometer-probes.ads       -- Behavioural probe system
│   ├── vexometer-api.ads          -- LLM API clients
│   ├── vexometer-reports.ads      -- Report generation
│   └── vexometer-gui.ads          -- GtkAda interface
├── data/
│   ├── patterns/                   -- Pattern definitions (JSON)
│   ├── probes/                     -- Probe test suites (JSON)
│   └── baselines/                  -- Known model baselines
├── tests/
│   └── ...
├── docs/
│   ├── SPECIFICATION.md           -- This document
│   └── letter_lmsys_arena.md      -- LMArena proposal letter
├── alire.toml                      -- Alire package manifest
└── vexometer.gpr                   -- GNAT project file
```

---

## GUI Design

```
┌─────────────────────────────────────────────────────────────────────────┐
│  ISA (Vexometer) - Irritation Surface Analyser                  [—][□][×]│
├─────────────────────────────────────────────────────────────────────────┤
│ ┌───────────────┐ ┌─────────────────────┐ ┌───────────────────────────┐ │
│ │ Model: [▼    ]│ │                     │ │ Findings                  │ │
│ ├───────────────┤ │    ╱╲   TII: 2.3    │ ├───────────────────────────┤ │
│ │ Prompt:       │ │   ╱  ╲              │ │ ⚠ High: "Great question"  │ │
│ │               │ │  ╱    ╲  LPS: 6.1   │ │   Line 1, Col 0           │ │
│ │ [Text Entry]  │ │ ╱      ╲            │ │   Sycophancy pattern      │ │
│ │               │ │╱   45   ╲ EFR: 3.2  │ ├───────────────────────────┤ │
│ │               │ │╲  ISA   ╱           │ │ ⚠ Med: "I'd be happy"     │ │
│ ├───────────────┤ │ ╲      ╱  PQ: 7.8   │ │   Line 1, Col 23          │ │
│ │ Response:     │ │  ╲    ╱             │ │   Sycophancy pattern      │ │
│ │               │ │   ╲  ╱   TAI: 1.0   │ │                           │ │
│ │ [Text View]   │ │    ╲╱               │ │ [Pattern Details]         │ │
│ │               │ │       ICS: 4.5      │ │                           │ │
│ │               │ │  [Export] [Compare] │ │                           │ │
│ └───────────────┘ └─────────────────────┘ └───────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────┤
│ Model Comparison                                                        │
│ ┌───────────┬─────┬─────┬─────┬─────┬─────┬─────┬───────┐              │
│ │ Model     │ ISA │ TII │ LPS │ EFR │ PQ  │ TAI │ ICS   │              │
│ ├───────────┼─────┼─────┼─────┼─────┼─────┼─────┼───────┤              │
│ │ OLMo 2    │  23 │ 2.1 │ 3.2 │ 5.1 │ 4.2 │ 0.0 │ 3.8   │ ████        │
│ │ GPT-4o    │  42 │ 4.1 │ 7.2 │ 5.5 │ 6.8 │ 8.5 │ 4.8   │ ████████    │
│ │ Claude    │  38 │ 2.8 │ 6.5 │ 4.2 │ 7.1 │ 6.2 │ 3.9   │ ███████     │
│ └───────────┴─────┴─────┴─────┴─────┴─────┴─────┴───────┘              │
│                                              [Run Suite] [Export]       │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## API Providers

Prioritises local/open models:

| Provider | Local | Endpoint |
|----------|-------|----------|
| Ollama | Yes | http://localhost:11434/api |
| LMStudio | Yes | http://localhost:1234/v1 |
| llama.cpp | Yes | http://localhost:8080 |
| HuggingFace | No | https://api-inference.huggingface.co |
| Together | No | https://api.together.xyz/v1 |
| OpenAI | No | https://api.openai.com/v1 |
| Anthropic | No | https://api.anthropic.com/v1 |

---

## Report Formats

- **JSON** — Machine-readable, for API integration
- **HTML** — Visual report with embedded SVG charts
- **Markdown** — For publication on GitHub, blogs
- **CSV** — For statistical analysis in R, Python
- **LaTeX** — For academic papers

---

## ISA Classification

| Score | Classification | Interpretation |
|-------|---------------|----------------|
| < 20 | Excellent | Model respects user time and intelligence |
| 20-35 | Good | Minor irritation patterns present |
| 35-50 | Acceptable | Noticeable but tolerable issues |
| 50-70 | Poor | Significant user experience problems |
| > 70 | Unusable | Severe irritation surface |

---

## Dependencies

Via Alire package manager:

- `gtkada` ≥ 24.0.0 — GUI toolkit
- `gnatcoll` ≥ 24.0.0 — Collection utilities
- `aws` ≥ 24.0.0 — HTTP client for API calls

---

## Building

```bash
# Install Alire (if not present)
# See https://alire.ada.dev

# Build
alr build

# Run
alr run

# Run tests
alr test
```

---

## Contributing

Contributions welcome under MPL-2.0.

Priority areas:
1. Additional pattern definitions
2. Probe suite expansion
3. Report format improvements
4. API provider support

---

## Licence

MPL-2.0

This is free software; you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
