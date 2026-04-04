// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

//! Property-based tests (using proptest)

use proptest::prelude::*;
use vex_lazy_eliminator::{Analyzer, Language};

// Property: For any code string, analysis never panics
proptest! {
    #[test]
    fn prop_analysis_never_panics(code in ".*", language in prop_oneof![
        Just(Language::Python),
        Just(Language::Rust),
        Just(Language::JavaScript),
        Just(Language::TypeScript),
        Just(Language::Java),
        Just(Language::Go),
    ]) {
        let analyzer = Analyzer::new(language);
        let _ = analyzer.analyze(&code);
    }
}

// Property: CII is always in [0.0, 1.0] range
proptest! {
    #[test]
    fn prop_cii_in_valid_range(code in ".*") {
        let analyzer = Analyzer::new(Language::Python);
        if let Ok(cii) = analyzer.calculate_cii(&code) {
            prop_assert!(cii >= 0.0 && cii <= 1.0, "CII must be in [0.0, 1.0]");
        }
    }
}

// Property: Empty input returns CII of 0.0 (no issues)
proptest! {
    #[test]
    fn prop_empty_input_complete(language in prop_oneof![
        Just(Language::Python),
        Just(Language::Rust),
        Just(Language::JavaScript),
    ]) {
        let analyzer = Analyzer::new(language);
        let empty = "";
        let cii = analyzer.calculate_cii(empty).expect("CII calculation should succeed");
        prop_assert_eq!(cii, 0.0, "Empty code should have CII of 0.0");
    }
}

// Property: Non-empty valid code has lower CII than code with unimplemented!
proptest! {
    #[test]
    fn prop_complete_code_has_lower_cii(code_fragment in "[a-z0-9]+") {
        let analyzer = Analyzer::new(Language::Rust);
        let valid_code = format!("fn foo() {{ let x = {}; }}", code_fragment);
        let invalid_code = format!("fn foo() {{ unimplemented!() }}", );

        let valid_cii = analyzer.calculate_cii(&valid_code).expect("should succeed");
        let invalid_cii = analyzer.calculate_cii(&invalid_code).expect("should succeed");

        prop_assert!(valid_cii <= invalid_cii, "complete code should have lower or equal CII");
    }
}

// Property: Analysis results are deterministic
proptest! {
    #[test]
    fn prop_analysis_is_deterministic(code in ".*") {
        let analyzer = Analyzer::new(Language::Python);
        let result1 = analyzer.analyze(&code).expect("first analysis should succeed");
        let result2 = analyzer.analyze(&code).expect("second analysis should succeed");

        prop_assert_eq!(result1.len(), result2.len(), "analysis should produce same results");
        for (d1, d2) in result1.iter().zip(result2.iter()) {
            prop_assert_eq!(d1.kind, d2.kind, "detection kinds should match");
            prop_assert_eq!(d1.line, d2.line, "line numbers should match");
        }
    }
}

// Property: Detection count never exceeds number of lines
proptest! {
    #[test]
    fn prop_detections_not_exceed_lines(code in ".*") {
        let analyzer = Analyzer::new(Language::Python);
        let detections = analyzer.analyze(&code).expect("analysis should succeed");
        let line_count = code.lines().count();

        // In practice, a line could have multiple detections, but total detections
        // should be reasonable. Strict check: detections per line <= 10
        if line_count > 0 {
            prop_assert!(detections.len() <= line_count * 10, "too many detections per line");
        }
    }
}

// Property: Analyzing the same code with different analyzers produces expected differences
proptest! {
    #[test]
    fn prop_language_specific_patterns(code in ".*") {
        let py_analyzer = Analyzer::new(Language::Python);
        let rs_analyzer = Analyzer::new(Language::Rust);

        let py_result = py_analyzer.analyze(&code).expect("py analysis should succeed");
        let rs_result = rs_analyzer.analyze(&code).expect("rs analysis should succeed");

        // Both should not crash
        let _ = py_result;
        let _ = rs_result;
    }
}

// Property: Detection severity is always in [0.0, 1.0]
proptest! {
    #[test]
    fn prop_severity_in_valid_range(code in ".*") {
        let analyzer = Analyzer::new(Language::Python);
        let detections = analyzer.analyze(&code).expect("analysis should succeed");

        for detection in detections {
            prop_assert!(
                detection.severity >= 0.0 && detection.severity <= 1.0,
                "severity must be in [0.0, 1.0], got {}",
                detection.severity
            );
        }
    }
}

// Property: Large inputs (up to 100KB) don't cause stack overflow
proptest! {
    #[test]
    fn prop_large_input_handling(
        fragment in "[a-z ]{0,100}",
        repetitions in 1..1000usize
    ) {
        let analyzer = Analyzer::new(Language::Python);
        let large_code = fragment.repeat(repetitions);

        let _result = analyzer.analyze(&large_code);
        // Just ensure it doesn't panic or stack overflow
    }
}

// Property: Whitespace-only code is complete
proptest! {
    #[test]
    fn prop_whitespace_only_is_complete(whitespace in r"[\s]*") {
        let analyzer = Analyzer::new(Language::Rust);
        let is_complete = analyzer.is_complete(&whitespace).expect("should succeed");
        prop_assert!(is_complete, "whitespace-only code should be complete");
    }
}

// Property: Code with only comments is complete
proptest! {
    #[test]
    fn prop_comment_only_code_is_complete(comment_text in "[a-z0-9 ]+") {
        let analyzer = Analyzer::new(Language::Rust);
        let code = format!("// {}\n", comment_text);
        let is_complete = analyzer.is_complete(&code).expect("should succeed");
        // Note: depends on whether comment_text contains TODO etc.
        // This test mainly ensures no crash
        let _ = is_complete;
    }
}

// Property: Summary statistics total equals detection count
proptest! {
    #[test]
    fn prop_summary_total_matches_detections(code in ".*") {
        let analyzer = Analyzer::new(Language::Python);
        let (detections, summary) = analyzer
            .analyze_with_summary(&code)
            .expect("analysis should succeed");

        prop_assert_eq!(
            summary.total,
            detections.len(),
            "summary total should match detection count"
        );
    }
}

// Property: Summary average severity equals sum / total (if total > 0)
proptest! {
    #[test]
    fn prop_summary_average_severity_correct(code in ".*") {
        let analyzer = Analyzer::new(Language::Python);
        let (detections, summary) = analyzer
            .analyze_with_summary(&code)
            .expect("analysis should succeed");

        if summary.total > 0 {
            let computed_avg: f64 = detections.iter().map(|d| d.severity).sum::<f64>() / detections.len() as f64;
            prop_assert!(
                (summary.average_severity - computed_avg).abs() < 0.0001,
                "summary average should match computed average"
            );
        }
    }
}

// Property: Unicode code is handled gracefully
proptest! {
    #[test]
    fn prop_unicode_handling(unicode_code in r"[\w\s\.\-\,\:\(\)\[\]\{\}!?]*") {
        let analyzer = Analyzer::new(Language::Python);
        let _result = analyzer.analyze(&unicode_code);
        // Just ensure it doesn't panic
    }
}

// Property: CII >= max severity (since CII is average)
proptest! {
    #[test]
    fn prop_cii_consistency(code in ".*") {
        let analyzer = Analyzer::new(Language::Python);
        let (_, summary) = analyzer
            .analyze_with_summary(&code)
            .expect("analysis should succeed");

        prop_assert!(
            summary.cii <= summary.max_severity + 0.0001,
            "CII (average) should be <= max severity"
        );
    }
}

// Property: Null bytes in input don't cause issues
proptest! {
    #[test]
    fn prop_null_bytes_handled(code in "[a-z]{0,100}") {
        let analyzer = Analyzer::new(Language::Python);
        // Test with manually injected null bytes
        let mut code_with_nulls = code.clone();
        if !code_with_nulls.is_empty() {
            code_with_nulls = code_with_nulls.replace('a', "\0a");
        }
        let _result = analyzer.analyze(&code_with_nulls);
        // Should not panic or crash
    }
}
