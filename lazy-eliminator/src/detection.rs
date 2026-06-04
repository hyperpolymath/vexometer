// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

use serde::{Deserialize, Serialize};

/// Types of incompleteness detected in code
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum IncompletenessKind {
    /// TODO comment (e.g., `// TODO: implement`)
    TodoComment,

    /// Placeholder text (e.g., `...`, `<placeholder>`)
    PlaceholderText,

    /// Unimplemented code block (e.g., `unimplemented!()`, `raise NotImplementedError`)
    UnimplementedCode,

    /// Truncation marker (e.g., `// ... (truncated)`)
    TruncationMarker,

    /// Null implementation (e.g., `pass`, `{}`, `return null`)
    NullImplementation,
}

impl IncompletenessKind {
    /// Returns the severity score for this incompleteness type (0.0 = none, 1.0 = critical)
    pub fn severity(&self) -> f64 {
        match self {
            Self::TodoComment => 0.6,
            Self::PlaceholderText => 0.8,
            Self::UnimplementedCode => 1.0,
            Self::TruncationMarker => 1.0,
            Self::NullImplementation => 0.5,
        }
    }

    /// Returns a human-readable description
    pub fn description(&self) -> &'static str {
        match self {
            Self::TodoComment => "TODO comment indicating incomplete implementation",
            Self::PlaceholderText => "Placeholder text requiring user completion",
            Self::UnimplementedCode => "Explicitly unimplemented code block",
            Self::TruncationMarker => "Truncation marker indicating omitted code",
            Self::NullImplementation => "Null or empty implementation",
        }
    }
}

impl std::fmt::Display for IncompletenessKind {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::TodoComment => write!(f, "TODO Comment"),
            Self::PlaceholderText => write!(f, "Placeholder"),
            Self::UnimplementedCode => write!(f, "Unimplemented"),
            Self::TruncationMarker => write!(f, "Truncated"),
            Self::NullImplementation => write!(f, "Null Implementation"),
        }
    }
}

/// A detected instance of incompleteness in code
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Detection {
    /// Type of incompleteness
    pub kind: IncompletenessKind,

    /// Line number (1-indexed)
    pub line: usize,

    /// Column number (0-indexed)
    pub column: usize,

    /// Byte offset in source
    pub offset: usize,

    /// Length in bytes
    pub length: usize,

    /// Matching text snippet
    pub snippet: String,

    /// Surrounding context (lines before and after)
    pub context: String,

    /// Severity score (0.0-1.0)
    pub severity: f64,
}

impl Detection {
    /// Create a new detection
    pub fn new(
        kind: IncompletenessKind,
        line: usize,
        column: usize,
        offset: usize,
        length: usize,
        snippet: String,
        context: String,
    ) -> Self {
        let severity = kind.severity();
        Self {
            kind,
            line,
            column,
            offset,
            length,
            snippet,
            context,
            severity,
        }
    }

    /// Returns true if this detection is critical (severity >= 0.8)
    pub fn is_critical(&self) -> bool {
        self.severity >= 0.8
    }

    /// Returns true if this detection is high priority (severity >= 0.6)
    pub fn is_high_priority(&self) -> bool {
        self.severity >= 0.6
    }
}

/// Summary statistics for a set of detections
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectionSummary {
    /// Total number of detections
    pub total: usize,

    /// Count by kind
    pub by_kind: std::collections::HashMap<String, usize>,

    /// Critical detections (severity >= 0.8)
    pub critical: usize,

    /// High priority detections (severity >= 0.6)
    pub high_priority: usize,

    /// Average severity
    pub average_severity: f64,

    /// Maximum severity
    pub max_severity: f64,

    /// Completion Integrity Index (0.0 = complete, 1.0 = very incomplete)
    pub cii: f64,
}

impl DetectionSummary {
    /// Create a summary from a list of detections
    pub fn from_detections(detections: &[Detection]) -> Self {
        let total = detections.len();
        let mut by_kind = std::collections::HashMap::new();
        let mut critical = 0;
        let mut high_priority = 0;
        let mut total_severity = 0.0;
        let mut max_severity: f64 = 0.0;

        for detection in detections {
            *by_kind.entry(format!("{}", detection.kind)).or_insert(0) += 1;
            if detection.is_critical() {
                critical += 1;
            }
            if detection.is_high_priority() {
                high_priority += 1;
            }
            total_severity += detection.severity;
            max_severity = max_severity.max(detection.severity);
        }

        let average_severity = if total > 0 {
            total_severity / total as f64
        } else {
            0.0
        };

        // CII is the average severity (0.0 = no incompleteness, 1.0 = all critical)
        let cii = average_severity;

        Self {
            total,
            by_kind,
            critical,
            high_priority,
            average_severity,
            max_severity,
            cii,
        }
    }
}
