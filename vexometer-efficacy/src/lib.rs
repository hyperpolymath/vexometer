// SPDX-License-Identifier: MPL-2.0
//! Efficacy evaluator for the vexometer ISA efficacy protocol.
//!
//! Implements the computation and validation halves of
//! `vexometer/docs/EFFICACY-PROTOCOL.adoc` (v2.1): `G_m`, collateral
//! deltas, `D_ISA`, the capability proxy, the six-verdict acceptance rule
//! with its precedence order, `vexometer-frontier-v1` record maintenance,
//! and mechanical v1 -> v2 report lifting.
//!
//! The six normative questions this crate once refused to guess at
//! (issue #69, D1a-D1f) were ruled a1, b1, c1, d1, e2, f1; the ruled
//! semantics are implemented here and the protocol text is amended to
//! v2.1 in the same change.

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fmt;

/// The owner-ruling issue that batched the six normative questions
/// (D1a-D1f), ruled a1, b1, c1, d1, e2, f1 on 2026-09-01.
pub const ISSUE_D1: &str = "https://github.com/hyperpolymath/vexometer/issues/69";

/// The ten ISA metrics with their default category weights, in canonical
/// order. Source of truth: `vexometer/docs/METRICS.adoc`, "Default
/// category weights". `D_ISA` in the protocol's worked example (-2.71) is
/// reproducible only with these values.
pub const METRIC_WEIGHTS: [(&str, f64); 10] = [
    ("TII", 1.0),
    ("LPS", 1.2),
    ("EFR", 1.5),
    ("PQ", 1.1),
    ("TAI", 0.8),
    ("ICS", 1.3),
    ("CII", 1.4),
    ("SRS", 1.2),
    ("SFR", 1.3),
    ("RCI", 1.1),
];

/// Collateral delta at or below this is compatible with `accept`.
pub const COLLATERAL_ACCEPT: f64 = 0.02;
/// Collateral delta in `(COLLATERAL_ACCEPT, COLLATERAL_WARN]` yields
/// `accept_with_warning`; above it, `reject_collateral`.
pub const COLLATERAL_WARN: f64 = 0.05;

const EPS: f64 = 1e-9;

pub fn weight_of(metric: &str) -> Option<f64> {
    METRIC_WEIGHTS
        .iter()
        .find(|(m, _)| *m == metric)
        .map(|(_, w)| *w)
}

pub fn round2(x: f64) -> f64 {
    (x * 100.0).round() / 100.0
}

pub fn round3(x: f64) -> f64 {
    (x * 1000.0).round() / 1000.0
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

#[derive(Debug)]
pub enum EfficacyError {
    /// The input data is malformed or incomplete.
    Data(String),
}

impl fmt::Display for EfficacyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            EfficacyError::Data(msg) => write!(f, "invalid input: {msg}"),
        }
    }
}

impl std::error::Error for EfficacyError {}

// ---------------------------------------------------------------------------
// Measurement inputs (tool input format; documented in the crate README)
// ---------------------------------------------------------------------------

/// One measurement pass: all ten metric scores plus the probe result,
/// against one content-addressed scenario set.
#[derive(Debug, Clone, Deserialize)]
pub struct Measurement {
    #[serde(default)]
    pub scenario_set: Option<String>,
    pub metrics: BTreeMap<String, MetricReading>,
    pub probes: ProbeMeasurement,
}

/// A metric score, optionally with distribution statistics.
#[derive(Debug, Clone, Deserialize)]
#[serde(untagged)]
pub enum MetricReading {
    Score(f64),
    Detailed {
        score: f64,
        #[serde(default)]
        std_dev: Option<f64>,
        #[serde(default)]
        confidence: Option<f64>,
        #[serde(default)]
        p_value: Option<f64>,
    },
}

impl MetricReading {
    pub fn score(&self) -> f64 {
        match self {
            MetricReading::Score(s) => *s,
            MetricReading::Detailed { score, .. } => *score,
        }
    }
    pub fn stats(&self) -> (Option<f64>, Option<f64>, Option<f64>) {
        match self {
            MetricReading::Score(_) => (None, None, None),
            MetricReading::Detailed {
                std_dev,
                confidence,
                p_value,
                ..
            } => (*std_dev, *confidence, *p_value),
        }
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct ProbeMeasurement {
    pub total: u32,
    pub passed: u32,
    /// Optional per-probe outcomes, keyed by probe id. When present in
    /// both measurements, the per-probe identity gate is normative
    /// (ruling b1); without it the aggregate pass-rate gate is the
    /// degraded fallback.
    #[serde(default)]
    pub results: Option<BTreeMap<String, bool>>,
}

impl ProbeMeasurement {
    pub fn pass_rate(&self) -> f64 {
        f64::from(self.passed) / f64::from(self.total)
    }

    fn check(&self) -> Result<(), EfficacyError> {
        if self.total == 0 {
            return Err(EfficacyError::Data("probes.total must be > 0".into()));
        }
        if self.passed > self.total {
            return Err(EfficacyError::Data(
                "probes.passed exceeds probes.total".into(),
            ));
        }
        if let Some(results) = &self.results {
            let n = results.len() as u32;
            let p = results.values().filter(|v| **v).count() as u32;
            if n != self.total || p != self.passed {
                return Err(EfficacyError::Data(format!(
                    "probes.results ({p}/{n}) disagrees with probes.passed/total ({}/{})",
                    self.passed, self.total
                )));
            }
        }
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Verdicts
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Verdict {
    Accept,
    AcceptWithWarning,
    RejectCollateral,
    RejectCapability,
    RejectNet,
    RejectNull,
    /// Verification-status sentinel for lifted v1 reports, outside the
    /// six-verdict acceptance table. Emitted only by [`lift_v1`]
    /// (ruling e2); a report without the `lifted_from` marker must never
    /// carry it.
    Unverified,
}

impl Verdict {
    pub fn is_reject(self) -> bool {
        matches!(
            self,
            Verdict::RejectCollateral
                | Verdict::RejectCapability
                | Verdict::RejectNet
                | Verdict::RejectNull
        )
    }
    pub fn advances_frontier(self) -> bool {
        matches!(self, Verdict::Accept | Verdict::AcceptWithWarning)
    }
    pub fn as_str(self) -> &'static str {
        match self {
            Verdict::Accept => "accept",
            Verdict::AcceptWithWarning => "accept_with_warning",
            Verdict::RejectCollateral => "reject_collateral",
            Verdict::RejectCapability => "reject_capability",
            Verdict::RejectNet => "reject_net",
            Verdict::RejectNull => "reject_null",
            Verdict::Unverified => "unverified",
        }
    }
}

// ---------------------------------------------------------------------------
// Evaluation
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct TargetOutcome {
    pub baseline: f64,
    pub after: f64,
    pub gap_closed: f64,
    pub mean_reduction: f64,
    pub std_dev: Option<f64>,
    pub confidence: Option<f64>,
    pub p_value: Option<f64>,
}

#[derive(Debug, Clone)]
pub struct CollateralOutcome {
    pub baseline: f64,
    pub after: f64,
    pub delta: f64,
}

#[derive(Debug, Clone)]
pub struct CapabilityOutcome {
    pub probes_total: u32,
    pub pass_rate_before: f64,
    pub pass_rate_after: f64,
    pub capability_ok: bool,
    pub probes_regressed: Option<Vec<String>>,
}

#[derive(Debug, Clone)]
pub struct Evaluation {
    pub targets: BTreeMap<String, TargetOutcome>,
    pub collateral: BTreeMap<String, CollateralOutcome>,
    pub capability: CapabilityOutcome,
    /// Unrounded `D_ISA`.
    pub isa_delta_raw: f64,
    pub verdict: Verdict,
    /// Collateral metrics whose delta falls in the warning band
    /// `(COLLATERAL_ACCEPT, COLLATERAL_WARN]`.
    pub warned_metrics: Vec<String>,
    /// Targets declared with a zero baseline. Ineligible under ruling
    /// a1: `G_m` is defined as 0 there, improvement is impossible at the
    /// floor, and the all-targets rule forces `reject_null`.
    pub zero_baseline_targets: Vec<String>,
}

impl Evaluation {
    /// Worst collateral regression, if any collateral metric exists.
    pub fn collateral_max(&self) -> Option<(String, f64)> {
        self.collateral
            .iter()
            .max_by(|a, b| a.1.delta.total_cmp(&b.1.delta))
            .map(|(m, c)| (m.clone(), c.delta))
    }
}

/// Compute `G_m`, all collateral deltas, `D_ISA`, the capability proxy,
/// and the verdict, per the protocol's acceptance rule and precedence
/// order (`reject_null > reject_capability > reject_collateral > reject_net`).
pub fn evaluate(
    baseline: &Measurement,
    after: &Measurement,
    targets: &[String],
) -> Result<Evaluation, EfficacyError> {
    if targets.is_empty() {
        return Err(EfficacyError::Data(
            "at least one target metric required".into(),
        ));
    }
    baseline.probes.check()?;
    after.probes.check()?;
    if baseline.probes.total != after.probes.total {
        return Err(EfficacyError::Data(format!(
            "probe suite size changed between measurements ({} vs {})",
            baseline.probes.total, after.probes.total
        )));
    }
    if let (Some(b), Some(a)) = (&baseline.scenario_set, &after.scenario_set) {
        if b != a {
            return Err(EfficacyError::Data(format!(
                "scenario_set mismatch: baseline {b} vs after {a}"
            )));
        }
    }

    // Every one of the ten metrics must be present in both measurements:
    // the protocol's workflow says "All ten metrics plus probe pass-rate
    // -- not only the target metric."
    for (metric, _) in METRIC_WEIGHTS {
        if !baseline.metrics.contains_key(metric) {
            return Err(EfficacyError::Data(format!(
                "baseline is missing metric {metric}; all ten ISA metrics are required"
            )));
        }
        if !after.metrics.contains_key(metric) {
            return Err(EfficacyError::Data(format!(
                "after is missing metric {metric}; all ten ISA metrics are required"
            )));
        }
    }
    for t in targets {
        if weight_of(t).is_none() {
            return Err(EfficacyError::Data(format!("unknown target metric {t}")));
        }
    }

    // Targets: G_m. A zero baseline leaves no gap to close: G_m is
    // defined as 0 there and improvement is impossible at the floor, so
    // a zero-baseline metric is ineligible as a target (ruling a1) and
    // the all-targets rule below yields reject_null.
    let mut target_out = BTreeMap::new();
    let mut improvements = Vec::new();
    let mut zero_baseline_targets = Vec::new();
    for t in targets {
        let b = baseline.metrics[t].score();
        let a_reading = &after.metrics[t];
        let a = a_reading.score();
        let gap_closed = if b == 0.0 {
            zero_baseline_targets.push(t.clone());
            0.0
        } else {
            (b - a) / b
        };
        let (std_dev, confidence, p_value) = a_reading.stats();
        target_out.insert(
            t.clone(),
            TargetOutcome {
                baseline: b,
                after: a,
                gap_closed,
                mean_reduction: b - a,
                std_dev,
                confidence,
                p_value,
            },
        );
        improvements.push(b != 0.0 && a < b - EPS);
    }

    // Collateral: every metric outside the target set.
    let mut collateral = BTreeMap::new();
    for (metric, _) in METRIC_WEIGHTS {
        if targets.iter().any(|t| t == metric) {
            continue;
        }
        let b = baseline.metrics[metric].score();
        let a = after.metrics[metric].score();
        collateral.insert(
            metric.to_string(),
            CollateralOutcome {
                baseline: b,
                after: a,
                delta: a - b,
            },
        );
    }

    // D_ISA over all ten metrics, targets included.
    let mut num = 0.0;
    let mut den = 0.0;
    for (metric, w) in METRIC_WEIGHTS {
        let b = baseline.metrics[metric].score();
        let a = after.metrics[metric].score();
        num += w * (a - b);
        den += w;
    }
    let isa_delta_raw = num / den * 100.0;

    // Capability proxy. When per-probe results exist for both
    // measurements, the identity gate is normative (ruling b1): at most
    // one baseline-passing probe may fail after the intervention, and a
    // newly-passing probe cannot buy back a regression. The aggregate
    // pass-rate gate (P_after >= P_before - 1/N) is the degraded
    // fallback when per-probe results are absent.
    let tolerance = 1.0 / f64::from(baseline.probes.total);
    let rate_before = baseline.probes.pass_rate();
    let rate_after = after.probes.pass_rate();
    let aggregate_ok = rate_after >= rate_before - tolerance - EPS;

    let (capability_ok, probes_regressed) = match (&baseline.probes.results, &after.probes.results)
    {
        (Some(before), Some(after_r)) => {
            if before.keys().ne(after_r.keys()) {
                return Err(EfficacyError::Data(
                    "probe ids differ between baseline and after measurements".into(),
                ));
            }
            let regressed: Vec<String> = before
                .iter()
                .filter(|(id, passed)| **passed && !after_r[*id])
                .map(|(id, _)| id.clone())
                .collect();
            (regressed.len() <= 1, Some(regressed))
        }
        _ => (aggregate_ok, None),
    };

    let capability = CapabilityOutcome {
        probes_total: baseline.probes.total,
        pass_rate_before: rate_before,
        pass_rate_after: rate_after,
        capability_ok,
        probes_regressed,
    };

    // Target improvement, under the all-targets rule (ruling c1): every
    // declared target must improve, or the attempt is a null result. A
    // partial win is a moved irritation surface, not a shrunk one.
    let all_improved = improvements.iter().all(|i| *i);

    let max_collateral = collateral
        .values()
        .map(|c| c.delta)
        .fold(f64::NEG_INFINITY, f64::max);
    let warned_metrics: Vec<String> = collateral
        .iter()
        .filter(|(_, c)| c.delta > COLLATERAL_ACCEPT + EPS && c.delta <= COLLATERAL_WARN + EPS)
        .map(|(m, _)| m.clone())
        .collect();

    // Acceptance rule with the protocol's precedence order.
    let verdict = if !all_improved {
        Verdict::RejectNull
    } else if !capability.capability_ok {
        Verdict::RejectCapability
    } else if !collateral.is_empty() && max_collateral > COLLATERAL_WARN + EPS {
        Verdict::RejectCollateral
    } else if round2(isa_delta_raw) >= 0.0 {
        // Gate on the rounded value: it is what the report stores, and the
        // validator's recomputation must reach the same verdict.
        Verdict::RejectNet
    } else if !warned_metrics.is_empty() {
        Verdict::AcceptWithWarning
    } else {
        Verdict::Accept
    };

    Ok(Evaluation {
        targets: target_out,
        collateral,
        capability,
        isa_delta_raw,
        verdict,
        warned_metrics,
        zero_baseline_targets,
    })
}

// ---------------------------------------------------------------------------
// vexometer-efficacy-v2 report
// ---------------------------------------------------------------------------

pub const EFFICACY_VERSION: &str = "vexometer-efficacy-v2";
pub const FRONTIER_VERSION: &str = "vexometer-frontier-v1";
pub const PROBE_PROXY_PATH: &str = "data/probes/behavioural_probes.json";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TargetMetricReport {
    pub baseline: f64,
    pub after: f64,
    pub gap_closed: f64,
    pub mean_reduction: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub std_dev: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub confidence: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub p_value: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CollateralMetricReport {
    pub baseline: f64,
    pub after: f64,
    pub delta: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CapabilityReport {
    pub proxy: String,
    pub probes_total: u32,
    pub pass_rate_before: f64,
    pub pass_rate_after: f64,
    pub capability_ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub probes_regressed: Option<Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EfficacyReport {
    pub version: String,
    pub satellite: String,
    pub evaluation_date: String,
    pub sample_size: u64,
    pub scenario_set: String,
    pub target_metrics: BTreeMap<String, TargetMetricReport>,
    pub collateral_metrics: BTreeMap<String, CollateralMetricReport>,
    pub capability: CapabilityReport,
    pub isa_delta: f64,
    pub verdict: Verdict,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub verdict_notes: Option<String>,
    pub methodology: String,
    pub traces_available: bool,
    /// One frontier-record reference per target metric (ruling d1).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub frontier_records: Option<Vec<String>>,
}

/// Report-level metadata supplied by the caller rather than computed.
#[derive(Debug, Clone)]
pub struct ReportMeta {
    pub satellite: String,
    pub evaluation_date: String,
    pub sample_size: u64,
    pub scenario_set: String,
    pub methodology: String,
    pub traces_available: bool,
    pub verdict_notes: Option<String>,
    pub frontier_records: Option<Vec<String>>,
}

/// Assemble a `vexometer-efficacy-v2` report from an evaluation.
///
/// Returns the report plus any non-fatal warnings (currently: notes
/// naming zero-baseline targets, which are ineligible under ruling a1).
pub fn build_report(
    eval: &Evaluation,
    meta: &ReportMeta,
) -> Result<(EfficacyReport, Vec<String>), EfficacyError> {
    let mut warnings = Vec::new();

    if eval.verdict == Verdict::AcceptWithWarning {
        let notes = meta.verdict_notes.as_deref().unwrap_or("");
        if notes.trim().is_empty() {
            return Err(EfficacyError::Data(format!(
                "verdict is accept_with_warning: the regressed metric(s) ({}) must be named \
                 in verdict_notes (pass --notes)",
                eval.warned_metrics.join(", ")
            )));
        }
        for m in &eval.warned_metrics {
            if !notes.contains(m.as_str()) {
                return Err(EfficacyError::Data(format!(
                    "verdict_notes must name regressed metric {m}"
                )));
            }
        }
    }

    for m in &eval.zero_baseline_targets {
        warnings.push(format!(
            "target {m} has baseline 0 and is ineligible as an efficacy target \
             (ruling a1): G_m is defined as 0 and the verdict is reject_null"
        ));
    }

    if let Some(records) = &meta.frontier_records {
        if records.len() != eval.targets.len() {
            return Err(EfficacyError::Data(format!(
                "frontier_records must carry one per-metric record per target \
                 (ruling d1): {} target(s) but {} record(s)",
                eval.targets.len(),
                records.len()
            )));
        }
    }

    let target_metrics = eval
        .targets
        .iter()
        .map(|(m, t)| {
            (
                m.clone(),
                TargetMetricReport {
                    baseline: t.baseline,
                    after: t.after,
                    gap_closed: round3(t.gap_closed),
                    mean_reduction: round2(t.mean_reduction),
                    std_dev: t.std_dev,
                    confidence: t.confidence,
                    p_value: t.p_value,
                },
            )
        })
        .collect();

    let collateral_metrics = eval
        .collateral
        .iter()
        .map(|(m, c)| {
            (
                m.clone(),
                CollateralMetricReport {
                    baseline: c.baseline,
                    after: c.after,
                    delta: round2(c.delta),
                },
            )
        })
        .collect();

    let report = EfficacyReport {
        version: EFFICACY_VERSION.to_string(),
        satellite: meta.satellite.clone(),
        evaluation_date: meta.evaluation_date.clone(),
        sample_size: meta.sample_size,
        scenario_set: meta.scenario_set.clone(),
        target_metrics,
        collateral_metrics,
        capability: CapabilityReport {
            proxy: PROBE_PROXY_PATH.to_string(),
            probes_total: eval.capability.probes_total,
            pass_rate_before: round3(eval.capability.pass_rate_before),
            pass_rate_after: round3(eval.capability.pass_rate_after),
            capability_ok: eval.capability.capability_ok,
            probes_regressed: eval.capability.probes_regressed.clone(),
        },
        isa_delta: round2(eval.isa_delta_raw),
        verdict: eval.verdict,
        verdict_notes: meta.verdict_notes.clone(),
        methodology: meta.methodology.clone(),
        traces_available: meta.traces_available,
        frontier_records: meta.frontier_records.clone(),
    };
    Ok((report, warnings))
}

// ---------------------------------------------------------------------------
// v1 -> v2 lifting (ruling e2)
// ---------------------------------------------------------------------------

pub const EFFICACY_V1_VERSION: &str = "vexometer-efficacy-v1";

/// Mechanically lift a `vexometer-efficacy-v1` report to v2.1 shape
/// (ruling e2). Every v1 field is carried verbatim; every required v2
/// field whose evidence does not exist in v1 becomes an explicit `null`
/// -- nothing is synthesised. The result carries
/// `"lifted_from": "vexometer-efficacy-v1"` and
/// `"verdict": "unverified"`, and satisfies the lifted branch of
/// [`validate_efficacy`].
pub fn lift_v1(doc: &serde_json::Value) -> Result<serde_json::Value, EfficacyError> {
    let obj = doc
        .as_object()
        .ok_or_else(|| EfficacyError::Data("a v1 report must be a JSON object".into()))?;
    match obj.get("version").and_then(|v| v.as_str()) {
        Some(EFFICACY_V1_VERSION) => {}
        Some(other) => {
            return Err(EfficacyError::Data(format!(
                "lift takes a {EFFICACY_V1_VERSION} report, got version {other:?}"
            )))
        }
        None => {
            return Err(EfficacyError::Data(
                "lift takes a v1 report with a \"version\" field".into(),
            ))
        }
    }

    // The lift domain is exactly the protocol's v1 mapping table. A key
    // outside it either collides with a v2 slot the lift must control
    // (verdict, capability, ...) or would be dropped silently -- both
    // break the carried-verbatim promise, so refuse instead.
    const V1_FIELDS: [&str; 7] = [
        "version",
        "metrics",
        "satellite",
        "evaluation_date",
        "sample_size",
        "methodology",
        "traces_available",
    ];
    for key in obj.keys() {
        if !V1_FIELDS.contains(&key.as_str()) {
            return Err(EfficacyError::Data(format!(
                "v1 field {key:?} has no v2 mapping: the lift carries v1 fields verbatim and refuses what it cannot carry (ruling e2)"
            )));
        }
    }

    let metrics = match obj.get("metrics") {
        Some(serde_json::Value::Object(m)) => m,
        _ => {
            return Err(EfficacyError::Data(
                "v1 report has no \"metrics\" object to lift".into(),
            ))
        }
    };
    let mut target_metrics = serde_json::Map::new();
    for (name, reading) in metrics {
        let serde_json::Value::Object(fields) = reading else {
            return Err(EfficacyError::Data(format!(
                "v1 metric {name} is not an object"
            )));
        };
        // v2 evidence keys cannot pre-exist in a v1 report; letting one
        // through would either clobber the explicit null or ship a value
        // the lift did not verify, and the failure would only surface at
        // a later validate run.
        for reserved in ["baseline", "after", "gap_closed"] {
            if fields.contains_key(reserved) {
                return Err(EfficacyError::Data(format!(
                    "v1 metric {name} already carries {reserved:?}: v2 evidence cannot pre-exist in a v1 report (ruling e2)"
                )));
            }
        }
        let mut lifted = serde_json::Map::new();
        // The v2 fields with no v1 evidence: explicit null, never
        // synthesised. The v1 sub-fields (mean_reduction, std_dev,
        // confidence, p_value) then carry over verbatim.
        lifted.insert("baseline".into(), serde_json::Value::Null);
        lifted.insert("after".into(), serde_json::Value::Null);
        lifted.insert("gap_closed".into(), serde_json::Value::Null);
        for (k, v) in fields {
            lifted.insert(k.clone(), v.clone());
        }
        target_metrics.insert(name.clone(), serde_json::Value::Object(lifted));
    }

    let carried = |key: &str| obj.get(key).cloned().unwrap_or(serde_json::Value::Null);
    let mut out = serde_json::Map::new();
    out.insert("version".into(), serde_json::json!(EFFICACY_VERSION));
    out.insert("lifted_from".into(), serde_json::json!(EFFICACY_V1_VERSION));
    out.insert("satellite".into(), carried("satellite"));
    out.insert("evaluation_date".into(), carried("evaluation_date"));
    out.insert("sample_size".into(), carried("sample_size"));
    out.insert("scenario_set".into(), serde_json::Value::Null);
    out.insert(
        "target_metrics".into(),
        serde_json::Value::Object(target_metrics),
    );
    out.insert("collateral_metrics".into(), serde_json::Value::Null);
    out.insert("capability".into(), serde_json::Value::Null);
    out.insert("isa_delta".into(), serde_json::Value::Null);
    out.insert("verdict".into(), serde_json::json!("unverified"));
    out.insert("methodology".into(), carried("methodology"));
    out.insert("traces_available".into(), carried("traces_available"));
    Ok(serde_json::Value::Object(out))
}

// ---------------------------------------------------------------------------
// Held-out scenario partition registry (ruling f1)
// ---------------------------------------------------------------------------

pub const SCENARIO_REGISTRY_VERSION: &str = "vexometer-scenario-registry-v1";

#[derive(Debug, Clone, Deserialize)]
struct ScenarioPartition {
    name: String,
    tuning_set: String,
    held_out_set: String,
}

#[derive(Debug, Clone, Deserialize)]
struct ScenarioRegistry {
    version: String,
    partitions: Vec<ScenarioPartition>,
}

/// Check a scored `scenario_set` against the held-out partition registry
/// (`vexometer/data/scenario_sets/registry.json`, ruling f1). Scoring
/// must use a registered held-out hash: a tuning hash is always a
/// violation, and once any partition is registered an unrecognised hash
/// is too. An empty registry (no corpus yet) enforces nothing.
pub fn check_scenario_registry(registry: &serde_json::Value, scenario_set: &str) -> Vec<String> {
    let reg: ScenarioRegistry = match serde_json::from_value(registry.clone()) {
        Ok(r) => r,
        Err(e) => {
            return vec![format!(
                "does not parse as {SCENARIO_REGISTRY_VERSION}: {e}"
            )]
        }
    };
    let mut problems = Vec::new();
    if reg.version != SCENARIO_REGISTRY_VERSION {
        problems.push(format!(
            "registry version is {:?}, expected {SCENARIO_REGISTRY_VERSION:?}",
            reg.version
        ));
    }
    if let Some(p) = reg.partitions.iter().find(|p| p.tuning_set == scenario_set) {
        problems.push(format!(
            "scenario_set {scenario_set} is the TUNING partition of {:?}; scoring must \
             use its held-out partition {} (ruling f1)",
            p.name, p.held_out_set
        ));
    } else if !reg.partitions.is_empty()
        && !reg
            .partitions
            .iter()
            .any(|p| p.held_out_set == scenario_set)
    {
        problems.push(format!(
            "scenario_set {scenario_set} matches no registered held-out partition (ruling f1)"
        ));
    }
    problems
}

// ---------------------------------------------------------------------------
// vexometer-frontier-v1 records
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CollateralMax {
    pub metric: String,
    pub delta: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrontierAttempt {
    pub index: u64,
    pub satellite: String,
    pub config: String,
    pub target_after: f64,
    pub gap_closed: f64,
    pub collateral_max: CollateralMax,
    pub isa_delta: f64,
    pub capability_ok: bool,
    pub verdict: Verdict,
    pub frontier: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrontierRecord {
    pub version: String,
    pub metric: String,
    pub model_profile: String,
    pub timestamp: String,
    pub scenario_set: String,
    pub baseline: BTreeMap<String, f64>,
    pub attempts: Vec<FrontierAttempt>,
    pub frontier_final: f64,
    pub methods_tried: u64,
    pub methods_rejected: u64,
}

impl FrontierRecord {
    pub fn new(
        metric: &str,
        model_profile: &str,
        timestamp: &str,
        scenario_set: &str,
        baseline_metric_score: f64,
        baseline_isa_score: f64,
        baseline_probe_pass_rate: f64,
    ) -> Self {
        let mut baseline = BTreeMap::new();
        baseline.insert(metric.to_string(), baseline_metric_score);
        baseline.insert("isa_score".to_string(), baseline_isa_score);
        baseline.insert(
            "probe_pass_rate".to_string(),
            round3(baseline_probe_pass_rate),
        );
        FrontierRecord {
            version: FRONTIER_VERSION.to_string(),
            metric: metric.to_string(),
            model_profile: model_profile.to_string(),
            timestamp: timestamp.to_string(),
            scenario_set: scenario_set.to_string(),
            baseline,
            attempts: Vec::new(),
            frontier_final: 0.0,
            methods_tried: 0,
            methods_rejected: 0,
        }
    }

    /// Append one attempt, enforcing the invariant: the frontier is
    /// monotonically non-decreasing and advances only on an `accept` or
    /// `accept_with_warning` whose `gap_closed` exceeds the current
    /// frontier.
    pub fn append(
        &mut self,
        satellite: &str,
        config: &str,
        eval: &Evaluation,
        scenario_set: &str,
    ) -> Result<&FrontierAttempt, EfficacyError> {
        if scenario_set != self.scenario_set {
            return Err(EfficacyError::Data(format!(
                "every attempt in a frontier record must run against the identical \
                 scenario set (record: {}, attempt: {})",
                self.scenario_set, scenario_set
            )));
        }
        let target = eval.targets.get(&self.metric).ok_or_else(|| {
            EfficacyError::Data(format!(
                "evaluation has no target outcome for this record's metric {}",
                self.metric
            ))
        })?;
        let (cmax_metric, cmax_delta) = eval
            .collateral_max()
            .ok_or_else(|| EfficacyError::Data("evaluation has no collateral metrics".into()))?;

        let prev = self.attempts.last().map(|a| a.frontier).unwrap_or(0.0);
        let gap = round3(target.gap_closed);
        let frontier = if eval.verdict.advances_frontier() && gap > prev {
            gap
        } else {
            prev
        };

        self.attempts.push(FrontierAttempt {
            index: self.attempts.len() as u64 + 1,
            satellite: satellite.to_string(),
            config: config.to_string(),
            target_after: target.after,
            gap_closed: gap,
            collateral_max: CollateralMax {
                metric: cmax_metric,
                delta: round2(cmax_delta),
            },
            isa_delta: round2(eval.isa_delta_raw),
            capability_ok: eval.capability.capability_ok,
            verdict: eval.verdict,
            frontier,
        });
        self.frontier_final = frontier;
        self.methods_tried = self.attempts.len() as u64;
        self.methods_rejected = self
            .attempts
            .iter()
            .filter(|a| a.verdict.is_reject())
            .count() as u64;
        self.attempts
            .last()
            .ok_or_else(|| EfficacyError::Data("internal: attempts empty after push".into()))
    }
}

// ---------------------------------------------------------------------------
// Validation: recompute everything a stored report claims
// ---------------------------------------------------------------------------

fn known_metric(m: &str) -> bool {
    weight_of(m).is_some()
}

/// Validate a `vexometer-efficacy-v2` document. Returns a list of
/// problems; an empty list means the document is valid.
///
/// A document carrying the `lifted_from` marker is routed to the lifted
/// branch (ruling e2), which checks the lift contract instead of
/// recomputing evidence that does not exist.
pub fn validate_efficacy(doc: &serde_json::Value) -> Vec<String> {
    if doc.get("lifted_from").is_some() {
        return validate_lifted(doc);
    }

    let mut problems = Vec::new();
    let report: EfficacyReport = match serde_json::from_value(doc.clone()) {
        Ok(r) => r,
        Err(e) => return vec![format!("does not parse as {EFFICACY_VERSION}: {e}")],
    };

    if report.version != EFFICACY_VERSION {
        problems.push(format!(
            "version is {:?}, expected {EFFICACY_VERSION:?}",
            report.version
        ));
    }
    if !report.scenario_set.starts_with("sha256:") {
        problems.push("scenario_set is not content-addressed (sha256:...)".into());
    }
    if report.target_metrics.is_empty() {
        problems.push("target_metrics is empty".into());
    }
    if doc.get("frontier_record").is_some() {
        problems.push(
            "frontier_record is the pre-ruling singular field; v2.1 uses \
             frontier_records, one per target metric (ruling d1)"
                .into(),
        );
    }
    if let Some(records) = &report.frontier_records {
        if records.len() != report.target_metrics.len() {
            problems.push(format!(
                "frontier_records has {} entr{} for {} target metric(s); ruling d1 \
                 requires one per-metric record per target",
                records.len(),
                if records.len() == 1 { "y" } else { "ies" },
                report.target_metrics.len()
            ));
        }
    }
    if report.verdict == Verdict::Unverified {
        problems.push(
            "verdict \"unverified\" is reserved for lifted v1 reports carrying the \
             lifted_from marker (ruling e2)"
                .into(),
        );
    }

    // Coverage: targets and collateral must partition the ten metrics.
    for m in report.target_metrics.keys() {
        if !known_metric(m) {
            problems.push(format!("unknown target metric {m}"));
        }
        if report.collateral_metrics.contains_key(m) {
            problems.push(format!("{m} appears in both target and collateral sets"));
        }
    }
    for m in report.collateral_metrics.keys() {
        if !known_metric(m) {
            problems.push(format!("unknown collateral metric {m}"));
        }
    }
    for (m, _) in METRIC_WEIGHTS {
        if !report.target_metrics.contains_key(m) && !report.collateral_metrics.contains_key(m) {
            problems.push(format!(
                "metric {m} is in neither target_metrics nor collateral_metrics; \
                 collateral must cover every non-target metric"
            ));
        }
    }

    // Arithmetic: recompute each stored figure from its own raw values.
    for (m, t) in &report.target_metrics {
        if t.baseline == 0.0 {
            // Ruling a1: G_m is defined as 0 when the baseline is 0.
            if t.gap_closed != 0.0 {
                problems.push(format!(
                    "target {m}: baseline is 0, so gap_closed is 0 by definition \
                     (ruling a1), not {}",
                    t.gap_closed
                ));
            }
        } else {
            let gap = (t.baseline - t.after) / t.baseline;
            if (round3(gap) - t.gap_closed).abs() > 0.0005 + EPS {
                problems.push(format!(
                    "target {m}: gap_closed {} does not match (baseline - after) / baseline = {}",
                    t.gap_closed,
                    round3(gap)
                ));
            }
        }
        if (round2(t.baseline - t.after) - t.mean_reduction).abs() > 0.005 + EPS {
            problems.push(format!(
                "target {m}: mean_reduction {} does not match baseline - after = {}",
                t.mean_reduction,
                round2(t.baseline - t.after)
            ));
        }
    }
    for (m, c) in &report.collateral_metrics {
        if (round2(c.after - c.baseline) - c.delta).abs() > 0.005 + EPS {
            problems.push(format!(
                "collateral {m}: delta {} does not match after - baseline = {}",
                c.delta,
                round2(c.after - c.baseline)
            ));
        }
    }

    // D_ISA over all ten metrics with the METRICS.adoc weights.
    let mut num = 0.0;
    let mut den = 0.0;
    let mut complete = true;
    for (m, w) in METRIC_WEIGHTS {
        let (b, a) = if let Some(t) = report.target_metrics.get(m) {
            (t.baseline, t.after)
        } else if let Some(c) = report.collateral_metrics.get(m) {
            (c.baseline, c.after)
        } else {
            complete = false;
            continue;
        };
        num += w * (a - b);
        den += w;
    }
    if complete {
        let isa = round2(num / den * 100.0);
        if (isa - report.isa_delta).abs() > 0.005 + EPS {
            problems.push(format!(
                "isa_delta {} does not match weighted recomputation {}",
                report.isa_delta, isa
            ));
        }
    }

    // Capability gate consistency. The per-probe identity gate is
    // normative when probes_regressed is recorded (ruling b1); the
    // aggregate pass-rate gate is the degraded fallback.
    if report.capability.probes_total == 0 {
        problems.push("capability.probes_total must be > 0".into());
    } else {
        let (gate, ok) = match &report.capability.probes_regressed {
            Some(regressed) => ("per-probe identity", regressed.len() <= 1),
            None => {
                let tol = 1.0 / f64::from(report.capability.probes_total);
                let ok = report.capability.pass_rate_after
                    >= report.capability.pass_rate_before - tol - EPS;
                ("aggregate pass-rate", ok)
            }
        };
        if ok != report.capability.capability_ok {
            problems.push(format!(
                "capability_ok is {} but the {gate} gate implies {ok}",
                report.capability.capability_ok
            ));
        }
    }

    // Verdict recomputation (only once the figures themselves check out).
    if problems.is_empty() {
        // All-targets rule (ruling c1): every declared target must
        // improve, or the verdict is reject_null. A zero-baseline target
        // (ruling a1) cannot improve and forces it.
        let all_improved = report
            .target_metrics
            .values()
            .all(|t| t.baseline != 0.0 && t.after < t.baseline - EPS);
        let max_c = report
            .collateral_metrics
            .values()
            .map(|c| c.delta)
            .fold(f64::NEG_INFINITY, f64::max);
        let warned: Vec<&String> = report
            .collateral_metrics
            .iter()
            .filter(|(_, c)| c.delta > COLLATERAL_ACCEPT + EPS && c.delta <= COLLATERAL_WARN + EPS)
            .map(|(m, _)| m)
            .collect();
        let expected = if !all_improved {
            Verdict::RejectNull
        } else if !report.capability.capability_ok {
            Verdict::RejectCapability
        } else if !report.collateral_metrics.is_empty() && max_c > COLLATERAL_WARN + EPS {
            Verdict::RejectCollateral
        } else if report.isa_delta >= 0.0 {
            Verdict::RejectNet
        } else if !warned.is_empty() {
            Verdict::AcceptWithWarning
        } else {
            Verdict::Accept
        };
        if expected != report.verdict {
            problems.push(format!(
                "verdict is {} but the acceptance rule implies {}",
                report.verdict.as_str(),
                expected.as_str()
            ));
        }
        if report.verdict == Verdict::AcceptWithWarning {
            match &report.verdict_notes {
                None => problems.push(
                    "accept_with_warning requires verdict_notes naming the regressed metric".into(),
                ),
                Some(notes) => {
                    for m in warned {
                        if !notes.contains(m.as_str()) {
                            problems.push(format!("verdict_notes must name regressed metric {m}"));
                        }
                    }
                }
            }
        }
    }

    problems
}

/// Validate a lifted (v1-origin) efficacy document against the lift
/// contract of ruling e2: the `lifted_from` marker, the `unverified`
/// verdict, and an explicit `null` for every v2 field whose evidence
/// does not exist in v1.
fn validate_lifted(doc: &serde_json::Value) -> Vec<String> {
    let Some(obj) = doc.as_object() else {
        return vec!["lifted report must be a JSON object".into()];
    };
    let mut problems = Vec::new();
    if obj.get("lifted_from").and_then(|v| v.as_str()) != Some(EFFICACY_V1_VERSION) {
        problems.push(format!("lifted_from must be {EFFICACY_V1_VERSION:?}"));
    }
    if obj.get("version").and_then(|v| v.as_str()) != Some(EFFICACY_VERSION) {
        problems.push(format!("version must be {EFFICACY_VERSION:?}"));
    }
    if obj.get("verdict").and_then(|v| v.as_str()) != Some("unverified") {
        problems.push(
            "a lifted report's verdict must be \"unverified\": the collateral and \
             capability evidence needed for a real verdict does not exist in v1"
                .into(),
        );
    }
    for key in [
        "scenario_set",
        "collateral_metrics",
        "capability",
        "isa_delta",
    ] {
        match obj.get(key) {
            Some(serde_json::Value::Null) => {}
            Some(_) => problems.push(format!(
                "{key} must be an explicit null in a lifted report: v1 carries no such \
                 evidence and nothing may be synthesised (ruling e2)"
            )),
            None => problems.push(format!(
                "{key} must be present as an explicit null in a lifted report (ruling e2)"
            )),
        }
    }
    match obj.get("target_metrics") {
        Some(serde_json::Value::Object(metrics)) if !metrics.is_empty() => {
            for (m, reading) in metrics {
                if !known_metric(m) {
                    problems.push(format!("unknown target metric {m}"));
                }
                let Some(fields) = reading.as_object() else {
                    problems.push(format!("target {m} is not an object"));
                    continue;
                };
                for key in ["baseline", "after", "gap_closed"] {
                    if !matches!(fields.get(key), Some(serde_json::Value::Null)) {
                        problems.push(format!(
                            "target {m}: {key} must be an explicit null in a lifted \
                             report (ruling e2)"
                        ));
                    }
                }
            }
        }
        _ => problems.push("target_metrics must be a non-empty object".into()),
    }
    if obj.get("frontier_record").is_some() || obj.get("frontier_records").is_some() {
        problems
            .push("a lifted report cannot reference a frontier record: none existed in v1".into());
    }
    problems
}

/// Validate a `vexometer-frontier-v1` document. Returns a list of
/// problems; an empty list means the document is valid.
pub fn validate_frontier(doc: &serde_json::Value) -> Vec<String> {
    let mut problems = Vec::new();
    let record: FrontierRecord = match serde_json::from_value(doc.clone()) {
        Ok(r) => r,
        Err(e) => return vec![format!("does not parse as {FRONTIER_VERSION}: {e}")],
    };

    if record.version != FRONTIER_VERSION {
        problems.push(format!(
            "version is {:?}, expected {FRONTIER_VERSION:?}",
            record.version
        ));
    }
    if !known_metric(&record.metric) {
        problems.push(format!("unknown metric {}", record.metric));
    }
    if !record.scenario_set.starts_with("sha256:") {
        problems.push("scenario_set is not content-addressed (sha256:...)".into());
    }
    for key in [record.metric.as_str(), "isa_score", "probe_pass_rate"] {
        if !record.baseline.contains_key(key) {
            problems.push(format!("baseline block is missing {key}"));
        }
    }

    let mut prev_frontier = 0.0;
    for (i, a) in record.attempts.iter().enumerate() {
        let expect_index = i as u64 + 1;
        if a.index != expect_index {
            problems.push(format!(
                "attempt {} has index {}, expected {expect_index}",
                i + 1,
                a.index
            ));
        }
        if !(0.0..=1.0).contains(&a.gap_closed) {
            problems.push(format!(
                "attempt {}: gap_closed {} outside [0, 1]",
                a.index, a.gap_closed
            ));
        }
        if a.verdict == Verdict::Unverified {
            problems.push(format!(
                "attempt {}: unverified is a verification-status sentinel, not a frontier verdict",
                a.index
            ));
        }
        let expected_frontier =
            if a.verdict.advances_frontier() && a.gap_closed > prev_frontier + EPS {
                a.gap_closed
            } else {
                prev_frontier
            };
        if (a.frontier - expected_frontier).abs() > EPS {
            problems.push(format!(
                "attempt {}: frontier {} violates the invariant (expected {}; the frontier \
                 advances only on accept/accept_with_warning exceeding the current frontier)",
                a.index, a.frontier, expected_frontier
            ));
        }
        if a.frontier < prev_frontier - EPS {
            problems.push(format!(
                "attempt {}: frontier decreased ({} -> {})",
                a.index, prev_frontier, a.frontier
            ));
        }
        prev_frontier = a.frontier;
    }

    if (record.frontier_final - prev_frontier).abs() > EPS {
        problems.push(format!(
            "frontier_final {} does not match last attempt frontier {}",
            record.frontier_final, prev_frontier
        ));
    }
    if record.methods_tried != record.attempts.len() as u64 {
        problems.push(format!(
            "methods_tried {} does not match attempt count {}",
            record.methods_tried,
            record.attempts.len()
        ));
    }
    let rejected = record
        .attempts
        .iter()
        .filter(|a| a.verdict.is_reject())
        .count() as u64;
    if record.methods_rejected != rejected {
        problems.push(format!(
            "methods_rejected {} does not match reject verdict count {rejected}",
            record.methods_rejected
        ));
    }

    problems
}
