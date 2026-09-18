// SPDX-License-Identifier: MPL-2.0
//! Integration tests for vex-verbosity-compressor. The first fixture pair is
//! taken verbatim from the LPS section of `vexometer/docs/METRICS.adoc`, so
//! the crate's behaviour is pinned to the protocol's own example.

use vex_verbosity_compressor::{analyse, compress, detect, PathologyClass};

const METRICS_HIGH_LPS: &str = "That's a great question! I'd be happy to help you with that. \
Essentially, what you're asking about is basically the borrow checker.";

const METRICS_LOW_LPS: &str = "The function returns null when the input is empty.";

#[test]
fn metrics_adoc_example_pair_orders_correctly() {
    let high = analyse(METRICS_HIGH_LPS);
    let low = analyse(METRICS_LOW_LPS);
    assert!(
        high.lps_proxy > low.lps_proxy,
        "HIGH-LPS example ({}) must outscore LOW-LPS example ({})",
        high.lps_proxy,
        low.lps_proxy
    );
    assert_eq!(low.lps_proxy, 0.0, "the LOW-LPS example is pathology-free");
    assert!(low.findings.is_empty());
}

#[test]
fn detects_sycophancy_openers() {
    let findings = detect("That's a great question! Here is the fix.");
    assert_eq!(findings.len(), 1);
    assert_eq!(findings[0].class, PathologyClass::Sycophancy);
    assert_eq!(findings[0].excerpt, "That's a great question");
    assert!(findings[0].strippable);
}

#[test]
fn longest_match_wins_over_embedded_phrase() {
    // "great question" is embedded in "that's a great question"; only the
    // longer match may be reported.
    let findings = detect("That's a great question.");
    assert_eq!(findings.len(), 1);
    assert_eq!(findings[0].excerpt, "That's a great question");
}

#[test]
fn word_boundaries_prevent_substring_hits() {
    // "questionnaire" must not fire the "question"-suffixed patterns, and
    // "maybes" must not fire the hedge "maybe".
    assert!(detect("The questionnaire covers maybes and essentials.").is_empty());
}

#[test]
fn hedges_are_detected_but_never_stripped() {
    let text = "Perhaps the cache is stale.";
    let findings = detect(text);
    assert_eq!(findings.len(), 1);
    assert_eq!(findings[0].class, PathologyClass::Hedge);
    assert!(!findings[0].strippable);

    let result = compress(text);
    assert_eq!(result.output, text, "hedges are meaning-bearing");
    assert_eq!(result.retained.len(), 1);
    assert!(result.removed.is_empty());
}

#[test]
fn corporate_speak_strips_only_discourse_adverbials() {
    // "at the end of the day" is removable; "leverage" is sentence grammar.
    let result = compress("At the end of the day, we leverage the cache.");
    assert_eq!(result.output, "we leverage the cache.");
    assert_eq!(result.removed.len(), 1);
    assert_eq!(result.removed[0].class, PathologyClass::CorporateSpeak);
    assert_eq!(result.retained.len(), 1);
    assert_eq!(result.retained[0].excerpt, "leverage");
}

#[test]
fn padding_fillers_are_stripped_in_place() {
    let result = compress("It's basically a cache.");
    assert_eq!(result.output, "It's a cache.");
    assert_eq!(result.removed.len(), 1);
    assert_eq!(result.removed[0].class, PathologyClass::Padding);
}

#[test]
fn compress_strips_the_metrics_high_lps_example_down_to_content() {
    let result = compress(METRICS_HIGH_LPS);
    assert_eq!(
        result.output, "what you're asking about is the borrow checker.",
        "sycophancy and padding go; content stays (v0.1 does not recapitalise)"
    );
    assert_eq!(result.removed.len(), 4);
}

#[test]
fn compress_preserves_clean_text() {
    let result = compress(METRICS_LOW_LPS);
    assert_eq!(result.output, METRICS_LOW_LPS);
    assert!(result.removed.is_empty());
    assert!(result.retained.is_empty());
}

#[test]
fn repetition_flags_second_occurrence_only_and_is_not_stripped() {
    let text = "The cache is stale. Refresh it. The cache is stale.";
    let findings = detect(text);
    let reps: Vec<_> = findings
        .iter()
        .filter(|f| f.class == PathologyClass::Repetition)
        .collect();
    assert_eq!(reps.len(), 1);
    assert!(reps[0].start > 20, "only the later duplicate is flagged");
    assert_eq!(compress(text).output, text);
}

#[test]
fn emoji_run_is_one_finding_and_not_stripped() {
    let text = "Tests pass ✅ 🚀 on main.";
    let findings = detect(text);
    let emoji: Vec<_> = findings
        .iter()
        .filter(|f| f.class == PathologyClass::EmojiDecoration)
        .collect();
    assert_eq!(emoji.len(), 1);
    assert_eq!(emoji[0].excerpt, "✅ 🚀");
    assert_eq!(compress(text).output, text);
}

#[test]
fn compress_preserves_untouched_formatting_byte_for_byte() {
    // No findings anywhere: indentation, double spaces, and blank-line runs
    // must survive unchanged — compress may not act as a global reformatter.
    let text = "fn main() {\n    let a = 1;\n\n\n    let b = 2;  // spaced\n}\n";
    let result = compress(text);
    assert!(result.removed.is_empty());
    assert_eq!(result.output, text);
}

#[test]
fn removing_a_whole_line_filler_drops_the_line() {
    let result = compress("The fix works.\nBasically.\nDone.");
    assert_eq!(result.output, "The fix works.\nDone.");
}

#[test]
fn removal_at_end_of_text_leaves_no_dangling_space() {
    let result = compress("Foo bar. Great question!");
    assert_eq!(result.output, "Foo bar.");
}

#[test]
fn indentation_survives_a_removal_elsewhere_in_the_text() {
    let result = compress("Basically, run:\n    cargo test\n");
    assert_eq!(result.output, "run:\n    cargo test\n");
}

#[test]
fn empty_input_scores_zero_and_compresses_to_empty() {
    let analysis = analyse("");
    assert_eq!(analysis.word_count, 0);
    assert_eq!(analysis.lps_proxy, 0.0);
    assert_eq!(compress("").output, "");
}

#[test]
fn weighted_sum_matches_class_weights() {
    // One sycophancy (3.0) + one padding (2.0) = 5.0 over the word count.
    let text = "Great question. It's basically a cache.";
    let analysis = analyse(text);
    assert_eq!(analysis.weighted_sum, 5.0);
    assert_eq!(analysis.word_count, 6);
    assert!((analysis.lps_proxy - 5.0 / 6.0).abs() < 1e-12);
}

#[test]
fn compress_is_stable_on_typical_output() {
    let once = compress(METRICS_HIGH_LPS).output;
    let twice = compress(&once).output;
    assert_eq!(once, twice, "second pass finds nothing more to remove");
}

#[test]
fn analysis_serializes_to_json_with_expected_keys() {
    let value = serde_json::to_value(analyse(METRICS_HIGH_LPS)).expect("serializes");
    for key in ["findings", "word_count", "weighted_sum", "lps_proxy"] {
        assert!(value.get(key).is_some(), "missing key {key}");
    }
    let first = &value["findings"][0];
    for key in ["class", "excerpt", "start", "end", "strippable"] {
        assert!(first.get(key).is_some(), "finding missing key {key}");
    }
}
