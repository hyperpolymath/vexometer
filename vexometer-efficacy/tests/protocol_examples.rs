// SPDX-License-Identifier: MPL-2.0
//! The efficacy protocol's own example documents are the fixtures.
//!
//! These tests read `vexometer/docs/EFFICACY-PROTOCOL.adoc`, extract its
//! example JSON blocks (efficacy-v2, lifted-v2, efficacy-v1, frontier-v1),
//! and require that (a) the validator accepts them, (b) the evaluator
//! reproduces the efficacy example byte-for-value from its raw inputs, and
//! (c) the v1 lift reproduces the lifted example from the v1 example.
//! If the protocol's examples and this implementation ever drift apart,
//! these tests fail loudly.

use std::collections::BTreeMap;
use std::path::PathBuf;

use vexometer_efficacy::*;

fn protocol_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../vexometer/docs/EFFICACY-PROTOCOL.adoc")
}

/// Extract every `----`-delimited block that parses as JSON and carries a
/// `version` field. Returned in document order; several blocks can share a
/// version (the main v2 example and the lifted one), so selection happens
/// in the helpers below, not by version key.
fn protocol_examples() -> Vec<serde_json::Value> {
    let text = std::fs::read_to_string(protocol_path())
        .expect("EFFICACY-PROTOCOL.adoc must be readable from the monorepo layout");
    let mut examples = Vec::new();
    let mut block: Option<String> = None;
    for line in text.lines() {
        if line.trim_end() == "----" {
            match block.take() {
                None => block = Some(String::new()),
                Some(content) => {
                    if let Ok(v) = serde_json::from_str::<serde_json::Value>(&content) {
                        if v.get("version").and_then(|s| s.as_str()).is_some() {
                            examples.push(v);
                        }
                    }
                }
            }
        } else if let Some(content) = block.as_mut() {
            content.push_str(line);
            content.push('\n');
        }
    }
    examples
}

fn only(matching: Vec<serde_json::Value>, what: &str) -> serde_json::Value {
    assert_eq!(
        matching.len(),
        1,
        "protocol must contain exactly one {what} example, found {}",
        matching.len()
    );
    matching.into_iter().next().unwrap()
}

/// The main v2 example: version v2, no `lifted_from` marker.
fn efficacy_example() -> serde_json::Value {
    let matching = protocol_examples()
        .into_iter()
        .filter(|v| {
            v.get("version").and_then(|s| s.as_str()) == Some(EFFICACY_VERSION)
                && v.get("lifted_from").is_none()
        })
        .collect();
    only(matching, "native vexometer-efficacy-v2")
}

/// The lifted example: version v2 with the `lifted_from` marker (ruling e2).
fn lifted_example() -> serde_json::Value {
    let matching = protocol_examples()
        .into_iter()
        .filter(|v| {
            v.get("version").and_then(|s| s.as_str()) == Some(EFFICACY_VERSION)
                && v.get("lifted_from").is_some()
        })
        .collect();
    only(matching, "lifted vexometer-efficacy-v2")
}

fn v1_example() -> serde_json::Value {
    let matching = protocol_examples()
        .into_iter()
        .filter(|v| v.get("version").and_then(|s| s.as_str()) == Some(EFFICACY_V1_VERSION))
        .collect();
    only(matching, "vexometer-efficacy-v1")
}

fn frontier_example() -> serde_json::Value {
    let matching = protocol_examples()
        .into_iter()
        .filter(|v| v.get("version").and_then(|s| s.as_str()) == Some(FRONTIER_VERSION))
        .collect();
    only(matching, "vexometer-frontier-v1")
}

// ---------------------------------------------------------------------------
// The protocol's examples must validate
// ---------------------------------------------------------------------------

#[test]
fn protocol_efficacy_example_is_valid() {
    let problems = validate_efficacy(&efficacy_example());
    assert!(
        problems.is_empty(),
        "the protocol's own efficacy-v2 example failed validation:\n{}",
        problems.join("\n")
    );
}

#[test]
fn protocol_lifted_example_is_valid() {
    let problems = validate_efficacy(&lifted_example());
    assert!(
        problems.is_empty(),
        "the protocol's own lifted example failed validation:\n{}",
        problems.join("\n")
    );
}

#[test]
fn protocol_frontier_example_is_valid() {
    let problems = validate_frontier(&frontier_example());
    assert!(
        problems.is_empty(),
        "the protocol's own frontier-v1 example failed validation:\n{}",
        problems.join("\n")
    );
}

// ---------------------------------------------------------------------------
// The evaluator must reproduce the efficacy example from raw inputs
// ---------------------------------------------------------------------------

fn measurement(metrics: &[(&str, serde_json::Value)], passed: u32, total: u32) -> Measurement {
    let doc = serde_json::json!({
        "scenario_set": "sha256:6b2f...",
        "metrics": metrics.iter().cloned().collect::<BTreeMap<_, _>>(),
        "probes": { "total": total, "passed": passed },
    });
    serde_json::from_value(doc).expect("measurement fixture must parse")
}

fn example_baseline() -> Measurement {
    measurement(
        &[
            ("LPS", serde_json::json!(0.41)),
            ("TII", serde_json::json!(0.33)),
            ("EFR", serde_json::json!(0.19)),
            ("PQ", serde_json::json!(0.28)),
            ("TAI", serde_json::json!(0.15)),
            ("ICS", serde_json::json!(0.22)),
            ("CII", serde_json::json!(0.31)),
            ("SRS", serde_json::json!(0.26)),
            ("SFR", serde_json::json!(0.24)),
            ("RCI", serde_json::json!(0.30)),
        ],
        12,
        13,
    )
}

fn example_after() -> Measurement {
    measurement(
        &[
            (
                "LPS",
                serde_json::json!({"score": 0.17, "std_dev": 0.09, "confidence": 0.95, "p_value": 0.001}),
            ),
            (
                "TII",
                serde_json::json!({"score": 0.22, "std_dev": 0.07, "confidence": 0.95, "p_value": 0.004}),
            ),
            ("EFR", serde_json::json!(0.20)),
            ("PQ", serde_json::json!(0.26)),
            ("TAI", serde_json::json!(0.15)),
            ("ICS", serde_json::json!(0.23)),
            ("CII", serde_json::json!(0.35)),
            ("SRS", serde_json::json!(0.26)),
            ("SFR", serde_json::json!(0.25)),
            ("RCI", serde_json::json!(0.30)),
        ],
        12,
        13,
    )
}

fn example_meta() -> ReportMeta {
    ReportMeta {
        satellite: "vex-verbosity-compressor".into(),
        evaluation_date: "2026-09-01".into(),
        sample_size: 500,
        scenario_set: "sha256:6b2f...".into(),
        methodology: "A/B testing with vexometer validation".into(),
        traces_available: true,
        verdict_notes: Some(
            "CII regressed by 0.04 -- compression removes content in long-form code \
             scenarios. Must be declared in satellite README."
                .into(),
        ),
        frontier_records: Some(vec![
            "frontier/LPS-2026-09-01.json".into(),
            "frontier/TII-2026-09-01.json".into(),
        ]),
    }
}

#[test]
fn evaluator_reproduces_protocol_efficacy_example() {
    let targets = vec!["LPS".to_string(), "TII".to_string()];
    let eval = evaluate(&example_baseline(), &example_after(), &targets)
        .expect("the protocol example inputs must evaluate cleanly");

    assert_eq!(eval.verdict, Verdict::AcceptWithWarning);
    assert_eq!(eval.warned_metrics, vec!["CII".to_string()]);

    let (report, warnings) = build_report(&eval, &example_meta()).expect("report must build");
    assert!(
        warnings.is_empty(),
        "a well-formed two-target report must emit no warnings, got: {warnings:?}"
    );

    let produced = serde_json::to_value(&report).expect("report must serialise");
    assert_eq!(
        produced,
        efficacy_example(),
        "the emitted report must equal the protocol's example value-for-value"
    );

    // And what the tool emits must itself validate.
    let problems = validate_efficacy(&produced);
    assert!(problems.is_empty(), "emitted report invalid: {problems:?}");
}

// ---------------------------------------------------------------------------
// Ruling a1: zero-baseline targets are ineligible, not errors
// ---------------------------------------------------------------------------

#[test]
fn zero_baseline_target_is_reject_null() {
    let mut baseline = example_baseline();
    baseline.metrics.insert(
        "LPS".into(),
        serde_json::from_value(serde_json::json!(0.0)).unwrap(),
    );
    let eval = evaluate(&baseline, &example_after(), &["LPS".to_string()])
        .expect("a zero-baseline target must evaluate, not error (ruling a1)");
    assert_eq!(eval.verdict, Verdict::RejectNull);
    assert_eq!(eval.zero_baseline_targets, vec!["LPS".to_string()]);
    assert_eq!(eval.targets["LPS"].gap_closed, 0.0);

    // The report surfaces the design error as a diagnosable warning.
    let mut meta = example_meta();
    meta.verdict_notes = None;
    meta.frontier_records = None;
    let (report, warnings) = build_report(&eval, &meta).expect("report must build");
    assert_eq!(report.verdict, Verdict::RejectNull);
    assert!(
        warnings.iter().any(|w| w.contains("ruling a1")),
        "expected a ruling-a1 ineligibility warning, got: {warnings:?}"
    );
}

// ---------------------------------------------------------------------------
// Ruling b1: the per-probe identity gate is normative
// ---------------------------------------------------------------------------

#[test]
fn probe_identity_gate_outvotes_aggregate_rate() {
    let mut ids: Vec<String> = (1..=13).map(|i| format!("P{i:02}")).collect();
    ids.sort();
    let before: BTreeMap<String, bool> = ids.iter().map(|id| (id.clone(), id != "P13")).collect();
    // Two baseline-passing probes regress, one baseline-failing probe now
    // passes: aggregate rate drops by exactly one probe (the fallback gate
    // would pass) while the identity gate counts two regressions and fails.
    let after_r: BTreeMap<String, bool> = ids
        .iter()
        .map(|id| {
            let v = match id.as_str() {
                "P01" | "P02" => false,
                "P13" => true,
                _ => before[id],
            };
            (id.clone(), v)
        })
        .collect();

    let mut baseline = example_baseline();
    baseline.probes.results = Some(before);
    let mut after = example_after();
    after.probes.passed = 11;
    after.probes.results = Some(after_r);

    let eval = evaluate(&baseline, &after, &["LPS".to_string(), "TII".to_string()])
        .expect("per-probe disagreement must evaluate, not error (ruling b1)");
    assert!(!eval.capability.capability_ok);
    assert_eq!(
        eval.capability.probes_regressed,
        Some(vec!["P01".to_string(), "P02".to_string()])
    );
    // Both targets improved, so the capability gate decides the verdict.
    assert_eq!(eval.verdict, Verdict::RejectCapability);
}

// ---------------------------------------------------------------------------
// Ruling c1: every declared target must improve
// ---------------------------------------------------------------------------

#[test]
fn mixed_target_improvement_is_reject_null() {
    let mut after = example_after();
    // TII regresses while LPS improves.
    after.metrics.insert(
        "TII".into(),
        serde_json::from_value(serde_json::json!(0.34)).unwrap(),
    );
    let eval = evaluate(
        &example_baseline(),
        &after,
        &["LPS".to_string(), "TII".to_string()],
    )
    .expect("mixed improvement must evaluate, not error (ruling c1)");
    assert_eq!(eval.verdict, Verdict::RejectNull);
}

// ---------------------------------------------------------------------------
// Ruling d1: one frontier record per target metric
// ---------------------------------------------------------------------------

#[test]
fn frontier_records_length_mismatch_is_a_hard_error() {
    let targets = vec!["LPS".to_string(), "TII".to_string()];
    let eval = evaluate(&example_baseline(), &example_after(), &targets).unwrap();
    let mut meta = example_meta();
    meta.frontier_records = Some(vec!["frontier/LPS-2026-09-01.json".into()]);
    let err = build_report(&eval, &meta).unwrap_err();
    assert!(
        err.to_string().contains("ruling d1"),
        "expected a ruling-d1 error, got: {err}"
    );
}

#[test]
fn validator_rejects_singular_frontier_record_key() {
    let mut doc = efficacy_example();
    doc.as_object_mut().unwrap().remove("frontier_records");
    doc["frontier_record"] = serde_json::json!("frontier/LPS-2026-09-01.json");
    let problems = validate_efficacy(&doc);
    assert!(
        problems.iter().any(|p| p.contains("frontier_records")),
        "expected the pre-ruling singular key to be rejected, got: {problems:?}"
    );
}

#[test]
fn validator_rejects_frontier_records_length_mismatch() {
    let mut doc = efficacy_example();
    doc["frontier_records"] = serde_json::json!(["frontier/LPS-2026-09-01.json"]);
    let problems = validate_efficacy(&doc);
    assert!(
        problems.iter().any(|p| p.contains("ruling d1")),
        "expected a ruling-d1 length problem, got: {problems:?}"
    );
}

// ---------------------------------------------------------------------------
// Ruling e2: the mechanical v1 lift
// ---------------------------------------------------------------------------

#[test]
fn lift_reproduces_protocol_lifted_example() {
    let lifted = lift_v1(&v1_example()).expect("the protocol's v1 example must lift");
    assert_eq!(
        lifted,
        lifted_example(),
        "the lift output must equal the protocol's lifted example value-for-value"
    );
}

#[test]
fn lift_rejects_non_v1_input() {
    let err = lift_v1(&efficacy_example()).unwrap_err();
    assert!(
        err.to_string().contains(EFFICACY_V1_VERSION),
        "expected a version complaint, got: {err}"
    );
}

#[test]
fn lift_rejects_v1_metric_smuggling_v2_evidence() {
    let mut doc = v1_example();
    doc["metrics"]["CII"]["baseline"] = serde_json::json!(0.31);
    let err = lift_v1(&doc).unwrap_err();
    assert!(
        err.to_string().contains("ruling e2") && err.to_string().contains("baseline"),
        "expected a pre-existing v2 evidence key to be refused at lift time, got: {err}"
    );
}

#[test]
fn lift_rejects_v1_report_with_unmapped_top_level_key() {
    let mut doc = v1_example();
    doc["verdict"] = serde_json::json!("accept");
    let err = lift_v1(&doc).unwrap_err();
    assert!(
        err.to_string().contains("ruling e2") && err.to_string().contains("verdict"),
        "expected a key outside the v1 mapping table to be refused, got: {err}"
    );
}

#[test]
fn native_report_cannot_claim_unverified() {
    let mut doc = efficacy_example();
    doc["verdict"] = serde_json::json!("unverified");
    let problems = validate_efficacy(&doc);
    assert!(
        problems.iter().any(|p| p.contains("lifted")),
        "expected unverified to be reserved for lifted reports, got: {problems:?}"
    );
}

#[test]
fn lifted_report_cannot_carry_synthesised_evidence() {
    let mut doc = lifted_example();
    doc["capability"] = serde_json::json!({"capability_ok": true});
    let problems = validate_efficacy(&doc);
    assert!(
        problems.iter().any(|p| p.contains("ruling e2")),
        "expected synthesised capability evidence to be rejected, got: {problems:?}"
    );
}

#[test]
fn lifted_report_cannot_reference_a_frontier_record() {
    let mut doc = lifted_example();
    doc["frontier_records"] = serde_json::json!(["frontier/CII-2025-01-15.json"]);
    let problems = validate_efficacy(&doc);
    assert!(
        problems.iter().any(|p| p.contains("frontier")),
        "expected the frontier reference to be rejected, got: {problems:?}"
    );
}

// ---------------------------------------------------------------------------
// Ruling f1: held-out scenario sets
// ---------------------------------------------------------------------------

fn test_registry() -> serde_json::Value {
    serde_json::json!({
        "version": SCENARIO_REGISTRY_VERSION,
        "partitions": [{
            "name": "compressor-corpus",
            "tuning_set": "sha256:aaaa",
            "held_out_set": "sha256:bbbb"
        }]
    })
}

#[test]
fn shipped_registry_is_valid_and_empty() {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../vexometer/data/scenario_sets/registry.json");
    let text = std::fs::read_to_string(&path).expect("shipped registry must exist (ruling f1)");
    let registry: serde_json::Value = serde_json::from_str(&text).expect("registry must parse");
    assert_eq!(
        registry.get("version").and_then(|v| v.as_str()),
        Some(SCENARIO_REGISTRY_VERSION)
    );
    // Empty registry enforces nothing: no corpus exists yet, and inventing
    // partition hashes would be exactly the fabrication f1 forbids.
    let problems = check_scenario_registry(&registry, "sha256:6b2f...");
    assert!(
        problems.is_empty(),
        "empty registry must enforce nothing: {problems:?}"
    );
}

#[test]
fn tuning_set_hash_is_always_a_violation() {
    let problems = check_scenario_registry(&test_registry(), "sha256:aaaa");
    assert!(
        problems.iter().any(|p| p.contains("held-out")),
        "expected a tuning-partition violation, got: {problems:?}"
    );
}

#[test]
fn unknown_hash_against_populated_registry_is_a_violation() {
    let problems = check_scenario_registry(&test_registry(), "sha256:cccc");
    assert!(
        problems.iter().any(|p| p.contains("ruling f1")),
        "expected an unregistered-set violation, got: {problems:?}"
    );
}

#[test]
fn held_out_hash_is_clean() {
    let problems = check_scenario_registry(&test_registry(), "sha256:bbbb");
    assert!(
        problems.is_empty(),
        "held-out set must be clean: {problems:?}"
    );
}

// ---------------------------------------------------------------------------
// Verdict precedence
// ---------------------------------------------------------------------------

#[test]
fn reject_null_outranks_all_other_rejects() {
    let baseline = example_baseline();
    let mut after = example_after();
    // Target worse, capability destroyed, collateral blown, D_ISA positive.
    after.metrics.insert(
        "LPS".into(),
        serde_json::from_value(serde_json::json!(0.60)).unwrap(),
    );
    after.metrics.insert(
        "CII".into(),
        serde_json::from_value(serde_json::json!(0.90)).unwrap(),
    );
    after.probes.passed = 5;
    let eval = evaluate(&baseline, &after, &["LPS".to_string()]).unwrap();
    assert_eq!(eval.verdict, Verdict::RejectNull);
}

#[test]
fn reject_capability_outranks_collateral_and_net() {
    let baseline = example_baseline();
    let mut after = example_after();
    after.metrics.insert(
        "CII".into(),
        serde_json::from_value(serde_json::json!(0.90)).unwrap(),
    );
    after.probes.passed = 5;
    let eval = evaluate(&baseline, &after, &["LPS".to_string(), "TII".to_string()]).unwrap();
    assert_eq!(eval.verdict, Verdict::RejectCapability);
}

#[test]
fn clean_improvement_accepts() {
    let baseline = example_baseline();
    let mut after = example_after();
    // Remove the CII warning-band regression.
    after.metrics.insert(
        "CII".into(),
        serde_json::from_value(serde_json::json!(0.31)).unwrap(),
    );
    let eval = evaluate(&baseline, &after, &["LPS".to_string(), "TII".to_string()]).unwrap();
    assert_eq!(eval.verdict, Verdict::Accept);
    assert!(eval.warned_metrics.is_empty());
}

// ---------------------------------------------------------------------------
// Frontier invariants
// ---------------------------------------------------------------------------

fn frontier_eval(after_lps: f64, capability_pass: u32) -> Evaluation {
    let baseline = example_baseline();
    let mut after = example_after();
    after.metrics.insert(
        "LPS".into(),
        serde_json::from_value(serde_json::json!(after_lps)).unwrap(),
    );
    // Keep CII clean so verdicts differ only via capability.
    after.metrics.insert(
        "CII".into(),
        serde_json::from_value(serde_json::json!(0.31)).unwrap(),
    );
    after.probes.passed = capability_pass;
    evaluate(&baseline, &after, &["LPS".to_string(), "TII".to_string()]).unwrap()
}

#[test]
fn rejected_attempt_with_higher_gap_does_not_advance_frontier() {
    let mut record = FrontierRecord::new(
        "LPS",
        "claude-opus-5",
        "2026-09-01T10:30:00Z",
        "sha256:6b2f...",
        0.41,
        46.2,
        12.0 / 13.0,
    );

    // Attempt 1: modest accepted improvement.
    let a1 = frontier_eval(0.34, 12);
    assert!(a1.verdict.advances_frontier());
    record
        .append(
            "vex-verbosity-compressor",
            "strip_filler=true",
            &a1,
            "sha256:6b2f...",
        )
        .unwrap();
    let f1 = record.attempts[0].frontier;
    assert!(f1 > 0.0);

    // Attempt 2: much larger gap, but capability-rejected.
    let a2 = frontier_eval(0.05, 10);
    assert_eq!(a2.verdict, Verdict::RejectCapability);
    record
        .append(
            "vex-verbosity-compressor",
            "aggressive=true",
            &a2,
            "sha256:6b2f...",
        )
        .unwrap();
    assert_eq!(
        record.attempts[1].frontier, f1,
        "a rejected attempt must not advance the frontier"
    );

    // Attempt 3: accepted and better than attempt 1.
    let a3 = frontier_eval(0.17, 12);
    assert!(a3.verdict.advances_frontier());
    record
        .append(
            "vex-verbosity-compressor",
            "preserve_code=true",
            &a3,
            "sha256:6b2f...",
        )
        .unwrap();
    assert!(record.attempts[2].frontier > f1);

    assert_eq!(record.methods_tried, 3);
    assert_eq!(record.methods_rejected, 1);
    assert_eq!(record.frontier_final, record.attempts[2].frontier);

    // The record the writer produces must satisfy the validator.
    let doc = serde_json::to_value(&record).unwrap();
    let problems = validate_frontier(&doc);
    assert!(problems.is_empty(), "written record invalid: {problems:?}");
}

#[test]
fn scenario_set_mismatch_is_rejected() {
    let mut record = FrontierRecord::new(
        "LPS",
        "claude-opus-5",
        "2026-09-01T10:30:00Z",
        "sha256:aaaa",
        0.41,
        46.2,
        12.0 / 13.0,
    );
    let a1 = frontier_eval(0.34, 12);
    let err = record
        .append("vex-verbosity-compressor", "cfg", &a1, "sha256:bbbb")
        .unwrap_err();
    assert!(err.to_string().contains("identical"));
}

// ---------------------------------------------------------------------------
// The validator must reject corrupted documents
// ---------------------------------------------------------------------------

#[test]
fn validator_catches_frontier_advanced_by_reject() {
    let mut doc = frontier_example();
    // Corrupt attempt 2 (reject_capability) to advance the frontier.
    doc["attempts"][1]["frontier"] = serde_json::json!(0.780);
    let problems = validate_frontier(&doc);
    assert!(
        problems.iter().any(|p| p.contains("invariant")),
        "expected an invariant violation, got: {problems:?}"
    );
}

#[test]
fn validator_catches_wrong_verdict() {
    let mut doc = efficacy_example();
    doc["verdict"] = serde_json::json!("accept");
    let problems = validate_efficacy(&doc);
    assert!(
        problems.iter().any(|p| p.contains("acceptance rule")),
        "expected a verdict mismatch, got: {problems:?}"
    );
}

#[test]
fn validator_catches_capability_gate_mismatch() {
    let mut doc = efficacy_example();
    doc["capability"]["capability_ok"] = serde_json::json!(false);
    let problems = validate_efficacy(&doc);
    assert!(
        problems.iter().any(|p| p.contains("aggregate pass-rate")),
        "expected the fallback gate to contradict capability_ok, got: {problems:?}"
    );
}

#[test]
fn validator_catches_bad_gap_arithmetic() {
    let mut doc = efficacy_example();
    doc["target_metrics"]["LPS"]["gap_closed"] = serde_json::json!(0.9);
    let problems = validate_efficacy(&doc);
    assert!(
        problems.iter().any(|p| p.contains("gap_closed")),
        "expected a gap_closed mismatch, got: {problems:?}"
    );
}

#[test]
fn validator_catches_missing_collateral_coverage() {
    let mut doc = efficacy_example();
    doc["collateral_metrics"]
        .as_object_mut()
        .unwrap()
        .remove("RCI");
    let problems = validate_efficacy(&doc);
    assert!(
        problems.iter().any(|p| p.contains("RCI")),
        "expected missing-coverage problem, got: {problems:?}"
    );
}
