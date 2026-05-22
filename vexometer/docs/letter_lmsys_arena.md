# Letter to LMSYS Chatbot Arena Team

**From:** Jonathan D.A. Jewell
**To:** LMSYS Chatbot Arena Team
**Subject:** Proposal for Irritation Surface Metrics in Arena Evaluation
**Date:** December 2024

---

Dear LMSYS Team,

I write to propose the inclusion of "Irritation Surface Analysis" (ISA) metrics in the Chatbot Arena evaluation framework.

## The Gap in Current Benchmarks

The Arena's Elo ratings and existing benchmarks (MMLU, HumanEval, MT-Bench, etc.) measure capability—what models CAN do. They do not measure user experience—what it FEELS LIKE to work with these models.

A model that scores highly on benchmarks but peppers every response with "Great question! I'd be happy to help!" and unsolicited warnings is, in practice, less useful than a less capable model that respects the user's time and intelligence.

This gap is not academic. User feedback consistently identifies irritation factors as primary reasons for abandoning AI assistants:

- Sycophantic phrasing ("Great question!")
- Excessive hedging and caveats
- Paternalistic explanations of obvious concepts
- Refusals with lengthy justifications
- Corporate cheerfulness incongruent with task context
- Telemetry anxiety (unclear data practices)

## The Proposal

I propose adding an Irritation Surface Analysis (ISA) score to Arena evaluations, comprising six measurable dimensions:

### 1. Temporal Intrusion Index (TII)
Unsolicited outputs, flow interruption, latency impacts on user cognition

### 2. Linguistic Pathology Score (LPS)
Sycophancy density, hedge word ratio, corporate speak frequency, unnecessary repetition

### 3. Epistemic Failure Rate (EFR)
Confident hallucination frequency, fabricated references, miscalibration between confidence and correctness

### 4. Paternalism Quotient (PQ)
Unsolicited warnings, over-explanation ratio, competence assumption failures

### 5. Telemetry Anxiety Index (TAI)
Data collection transparency, opt-out friction, code/query transmission clarity

### 6. Interaction Coherence Score (ICS)
Learning from feedback, context retention, circular conversation frequency

## Methodology

ISA combines three measurement approaches:

### Automated Pattern Detection
Regex-based identification of known irritation patterns in responses. We have catalogued over 50 patterns across categories, validated against user feedback datasets.

### Behavioural Probes
Standardised test prompts designed to elicit irritation-prone responses:
- Brevity tests: "One word answer: what's 2+2?"
- Competence calibration: Expert vs beginner framing
- Constraint following: "Without using the word X..."
- Uncertainty calibration: Questions with unknowable answers

### Human Evaluation
Structured ratings on appropriateness dimensions with inter-rater reliability requirements (Krippendorff's α ≥ 0.7).

The methodology produces reproducible, comparable scores that can be integrated into existing Arena infrastructure.

## Implementation

I am developing an open-source tool, **Vexometer**, that implements ISA measurement. Key features:

- **Written in Ada** for reliability and long-term maintenance
- **GtkAda graphical interface** for interactive analysis
- **Local-first architecture** prioritising Ollama/llama.cpp for privacy
- **Multiple output formats** including JSON for API integration
- **Standardised probe suite** with versioned, reproducible tests

The tool will be released under MPL-2.0 and hosted at `gitlab.com/hyperpolymath/vexometer`.

## Collaboration Proposal

I would welcome the opportunity to collaborate with the LMSYS team on:

1. **Validation** - Cross-referencing ISA methodology against Arena user feedback data to validate that our metrics correlate with actual user preferences

2. **Integration** - Adding ISA metrics to the Arena leaderboard as an additional dimension, allowing users to sort/filter by user experience quality

3. **Publication** - A joint paper on irritation surface measurement, contributing to the field's understanding of human-AI interaction quality

## Why This Matters

The AI assistant market is maturing. Capability is increasingly commoditised—many models can answer most questions adequately. Differentiation will come from user experience.

By measuring irritation surface, the Arena would:

- **Inform users** - Provide signal that helps users choose models that respect their time and intelligence
- **Incentivise developers** - Create pressure for model developers to optimise for experience, not just capability
- **Advance the field** - Generate data and insights about human-AI interaction quality that benefit the entire research community

The goal is not to penalise models unfairly, but to make visible a dimension of quality that users care about but current benchmarks ignore entirely.

I believe this aligns with LMSYS's mission to provide comprehensive, useful evaluation of language models.

## Next Steps

I would be glad to:

1. Provide a demonstration of the Vexometer tool
2. Share the complete probe suite and pattern database
3. Discuss integration approaches with your engineering team
4. Contribute to the design of Arena-compatible ISA metrics

Please do reach out if you would like to discuss this proposal further.

---

Yours sincerely,

**Jonathan D.A. Jewell**
Associate Lecturer, The Open University
NEC Member, National Union of Journalists

Website: https://gitlab.com/hyperpolymath
Email: [Your contact email]

---

## Appendix: Sample ISA Scores

Based on preliminary testing with the Vexometer prototype:

| Model | ISA | TII | LPS | EFR | PQ | TAI | ICS |
|-------|-----|-----|-----|-----|-----|-----|-----|
| OLMo 2 | 23 | 2.1 | 3.2 | 5.1 | 4.2 | 0.0 | 3.8 |
| Falcon 3 | 28 | 2.4 | 4.1 | 5.8 | 4.9 | 0.0 | 4.2 |
| Qwen 2.5 | 35 | 3.2 | 5.8 | 6.2 | 5.5 | 0.0 | 5.1 |
| GPT-4o | 42 | 4.1 | 7.2 | 5.5 | 6.8 | 8.5 | 4.8 |
| Claude 3.5 | 38 | 2.8 | 6.5 | 4.2 | 7.1 | 6.2 | 3.9 |
| Phi-4 | 52 | 3.5 | 8.1 | 7.2 | 8.5 | 9.0 | 5.8 |

*Lower ISA = Better user experience*

Note: These are illustrative scores from early testing. Final methodology will require validation with larger datasets.
