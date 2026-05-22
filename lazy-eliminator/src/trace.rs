// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// vexometer-trace-v1 format for before/after validation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VexometerTrace {
    pub version: String,
    pub satellite: String,
    pub timestamp: String,
    pub scenario: Scenario,
    pub before: TraceMetrics,
    pub after: TraceMetrics,
    pub reduction: HashMap<String, f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Scenario {
    pub description: String,
    pub prompt: String,
    #[serde(default)]
    pub context: HashMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraceMetrics {
    pub response: String,
    pub metrics: HashMap<String, f64>,
}

impl VexometerTrace {
    /// Create a new trace from before/after code samples
    pub fn new(
        description: String,
        prompt: String,
        before_code: String,
        before_cii: f64,
        after_code: String,
        after_cii: f64,
    ) -> Self {
        let mut before_metrics = HashMap::new();
        before_metrics.insert("CII".to_string(), before_cii);

        let mut after_metrics = HashMap::new();
        after_metrics.insert("CII".to_string(), after_cii);

        let mut reduction = HashMap::new();
        reduction.insert("CII".to_string(), before_cii - after_cii);

        Self {
            version: "vexometer-trace-v1".to_string(),
            satellite: "vex-lazy-eliminator".to_string(),
            timestamp: chrono::Utc::now().to_rfc3339(),
            scenario: Scenario {
                description,
                prompt,
                context: HashMap::new(),
            },
            before: TraceMetrics {
                response: before_code,
                metrics: before_metrics,
            },
            after: TraceMetrics {
                response: after_code,
                metrics: after_metrics,
            },
            reduction,
        }
    }

    /// Save trace to JSON file
    pub fn save(&self, path: impl AsRef<std::path::Path>) -> crate::Result<()> {
        let json = serde_json::to_string_pretty(self)?;
        std::fs::write(path, json)?;
        Ok(())
    }
}

/// Report for displaying trace results
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraceReport {
    pub trace: VexometerTrace,
    pub summary: String,
}

impl TraceReport {
    /// Generate a human-readable summary
    pub fn generate_summary(trace: &VexometerTrace) -> String {
        let cii_before = trace.before.metrics.get("CII").copied().unwrap_or(0.0);
        let cii_after = trace.after.metrics.get("CII").copied().unwrap_or(0.0);
        let reduction = cii_before - cii_after;
        let reduction_pct = if cii_before > 0.0 {
            (reduction / cii_before) * 100.0
        } else {
            0.0
        };

        format!(
            "CII reduced from {:.3} to {:.3} ({:.1}% reduction)",
            cii_before, cii_after, reduction_pct
        )
    }

    pub fn new(trace: VexometerTrace) -> Self {
        let summary = Self::generate_summary(&trace);
        Self { trace, summary }
    }
}
