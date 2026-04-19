// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

use crate::detection::{Detection, DetectionSummary};
use crate::language::Language;
use crate::patterns;
use crate::Result;

/// Analyzer for detecting incompleteness in code
pub struct Analyzer {
    language: Language,
}

impl Analyzer {
    /// Create a new analyzer for the given language
    pub fn new(language: Language) -> Self {
        Self { language }
    }

    /// Analyze code and return detected incompleteness patterns
    pub fn analyze(&self, code: &str) -> Result<Vec<Detection>> {
        let patterns = patterns::get_patterns(self.language);
        let mut detections = Vec::new();

        let lines: Vec<&str> = code.lines().collect();

        for (line_idx, line) in lines.iter().enumerate() {
            let line_num = line_idx + 1;

            for pattern in &patterns {
                if let Some(mat) = pattern.regex.find(line) {
                    let context = self.get_context(&lines, line_idx, 2);

                    detections.push(Detection::new(
                        pattern.kind,
                        line_num,
                        mat.start(),
                        0, // offset calculation would require cumulative byte counting
                        mat.len(),
                        mat.as_str().to_string(),
                        context,
                    ));
                }
            }
        }

        Ok(detections)
    }

    /// Get surrounding context for a line
    fn get_context(&self, lines: &[&str], line_idx: usize, context_lines: usize) -> String {
        let start = line_idx.saturating_sub(context_lines);
        let end = (line_idx + context_lines + 1).min(lines.len());

        lines[start..end].join("\n")
    }

    /// Analyze and return summary statistics
    pub fn analyze_with_summary(&self, code: &str) -> Result<(Vec<Detection>, DetectionSummary)> {
        let detections = self.analyze(code)?;
        let summary = DetectionSummary::from_detections(&detections);
        Ok((detections, summary))
    }

    /// Returns true if the code is complete (no detections)
    pub fn is_complete(&self, code: &str) -> Result<bool> {
        Ok(self.analyze(code)?.is_empty())
    }

    /// Calculate Completion Integrity Index (CII) for the code (0.0 = complete, 1.0 = very incomplete)
    pub fn calculate_cii(&self, code: &str) -> Result<f64> {
        let (_detections, summary) = self.analyze_with_summary(code)?;
        Ok(summary.cii)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_python_todo() {
        let analyzer = Analyzer::new(Language::Python);
        let code = r#"
def process_data():
    # TODO: implement this
    pass
"#;
        let detections = analyzer.analyze(code).unwrap();
        assert!(!detections.is_empty());
        assert!(detections.iter().any(|d| matches!(d.kind, crate::detection::IncompletenessKind::TodoComment)));
    }

    #[test]
    fn test_rust_unimplemented() {
        let analyzer = Analyzer::new(Language::Rust);
        let code = r#"
fn complex_function() {
    unimplemented!()
}
"#;
        let detections = analyzer.analyze(code).unwrap();
        assert!(!detections.is_empty());
        assert!(detections.iter().any(|d| matches!(d.kind, crate::detection::IncompletenessKind::UnimplementedCode)));
    }

    #[test]
    fn test_complete_code() {
        let analyzer = Analyzer::new(Language::Python);
        let code = r#"
def add(a, b):
    return a + b
"#;
        assert!(analyzer.is_complete(code).unwrap());
    }
}
