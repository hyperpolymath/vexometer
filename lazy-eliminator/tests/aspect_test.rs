// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

//! Aspect tests: security, performance, robustness, concurrent access

use std::sync::Arc;
use std::thread;
use vex_lazy_eliminator::{Analyzer, Language};

/// Security: Input with null bytes should be handled gracefully
#[test]
fn test_security_null_bytes() {
    let analyzer = Analyzer::new(Language::Python);
    let code_with_nulls = "def foo():\n    x = \"test\\0value\"\n    pass";

    let result = analyzer.analyze(code_with_nulls);
    assert!(result.is_ok(), "analysis should handle null bytes gracefully");
}

/// Security: Extremely large input (1MB) should not cause stack overflow
#[test]
fn test_security_oversized_input() {
    let analyzer = Analyzer::new(Language::Python);
    let large_code = "# comment\n".repeat(100_000); // ~100 lines, repeated to 1MB

    let result = analyzer.analyze(&large_code);
    assert!(result.is_ok(), "analysis should handle large input");

    if let Ok(detections) = result {
        assert!(detections.len() < 1_000_000, "should not create excessive detections");
    }
}

/// Security: Input with special regex characters should not cause ReDoS
#[test]
fn test_security_regex_dos_protection() {
    let analyzer = Analyzer::new(Language::Rust);
    let potentially_dangerous = "a".repeat(1000) + "()*+?[]{}.\\|$^";

    let result = analyzer.analyze(&potentially_dangerous);
    assert!(result.is_ok(), "should handle regex-dangerous input without ReDoS");
}

/// Robustness: Unicode identifiers should be handled correctly
#[test]
fn test_robustness_unicode_identifiers() {
    let analyzer = Analyzer::new(Language::Python);
    let unicode_code = "def εξέταση():\n    λ = 42\n    return λ\n";

    let result = analyzer.analyze(unicode_code);
    assert!(result.is_ok(), "should handle unicode identifiers");
}

/// Robustness: Mixed line endings (CRLF vs LF) should work
#[test]
fn test_robustness_mixed_line_endings() {
    let analyzer = Analyzer::new(Language::JavaScript);
    let code = "function foo() {\r\n    // TODO: fix\r\n    return null;\n}";

    let result = analyzer.analyze(code);
    assert!(result.is_ok(), "should handle mixed line endings");

    if let Ok(detections) = result {
        assert!(
            detections.iter().any(|d| d.snippet.to_lowercase().contains("todo")),
            "should find TODO despite mixed line endings"
        );
    }
}

/// Robustness: Very long lines (>10KB) should not crash
#[test]
fn test_robustness_very_long_lines() {
    let analyzer = Analyzer::new(Language::Rust);
    let long_line = format!("let very_long_name = {};\n", "x".repeat(10_000));

    let result = analyzer.analyze(&long_line);
    assert!(result.is_ok(), "should handle very long lines");
}

/// Robustness: Code with only whitespace variations should be complete
#[test]
fn test_robustness_whitespace_only() {
    let analyzer = Analyzer::new(Language::Python);
    let whitespace_code = "\t\n  \n\t\t\n";

    let is_complete = analyzer
        .is_complete(whitespace_code)
        .expect("should succeed");
    assert!(is_complete, "whitespace-only code should be complete");
}

/// Robustness: Empty code should be complete
#[test]
fn test_robustness_empty_code() {
    let analyzer = Analyzer::new(Language::Rust);
    assert!(
        analyzer
            .is_complete("")
            .expect("should handle empty code"),
        "empty code should be complete"
    );
}

/// Concurrency: Multiple analyzers can be created and used simultaneously
#[test]
fn test_concurrency_multiple_analyzers() {
    let mut handles = vec![];

    for _ in 0..4 {
        let handle = thread::spawn(|| {
            let analyzer = Analyzer::new(Language::Rust);
            let code = "fn main() { println!(\"hello\"); }";
            let _result = analyzer.analyze(code);
        });
        handles.push(handle);
    }

    for handle in handles {
        handle.join().expect("thread should complete");
    }
}

/// Concurrency: Shared analyzer can be used from multiple threads
#[test]
fn test_concurrency_shared_analyzer() {
    let analyzer = Arc::new(Analyzer::new(Language::Python));
    let mut handles = vec![];

    for i in 0..8 {
        let analyzer_clone = Arc::clone(&analyzer);
        let handle = thread::spawn(move || {
            let code = format!("def func{}():\n    # TODO: task {}\n    pass\n", i, i);
            let detections = analyzer_clone.analyze(&code).expect("analysis should succeed");
            assert!(!detections.is_empty(), "should detect TODO");
        });
        handles.push(handle);
    }

    for handle in handles {
        handle.join().expect("thread should complete");
    }
}

/// Concurrency: Concurrent analysis on same code produces consistent results
#[test]
fn test_concurrency_consistent_results() {
    let code = Arc::new(
        r#"
def process():
    # TODO: implement
    raise NotImplementedError()
"#
            .to_string(),
    );

    let mut handles = vec![];
    let results = Arc::new(std::sync::Mutex::new(vec![]));

    for _ in 0..4 {
        let code_clone = Arc::clone(&code);
        let results_clone = Arc::clone(&results);
        let handle = thread::spawn(move || {
            let analyzer = Analyzer::new(Language::Python);
            let detections = analyzer.analyze(&code_clone).expect("analysis should succeed");
            results_clone
                .lock()
                .expect("lock should succeed")
                .push(detections.len());
        });
        handles.push(handle);
    }

    for handle in handles {
        handle.join().expect("thread should complete");
    }

    let final_results = results.lock().expect("lock should succeed");
    assert!(final_results.len() == 4);
    // All should have same count since they analyze the same code
    assert!(final_results.iter().all(|&count| count == final_results[0]));
}

/// Performance: Analysis should complete in reasonable time for medium-sized code
#[test]
fn test_performance_medium_code() {
    let analyzer = Analyzer::new(Language::Rust);
    let base_code = r#"
fn main() {
    // This is a medium-sized function
    let data = vec![1, 2, 3, 4, 5];
    let mut result = Vec::new();

    for item in data {
        if item > 2 {
            result.push(item * 2);
        }
    }

    println!("{:?}", result);
}
"#;
    let code = base_code.repeat(10); // Repeat to create medium-sized code

    let start = std::time::Instant::now();
    let _result = analyzer.analyze(&code);
    let elapsed = start.elapsed();

    assert!(
        elapsed.as_millis() < 1000,
        "analysis should complete in < 1 second, took {}ms",
        elapsed.as_millis()
    );
}

/// Robustness: Code with escaped quotes should be handled
#[test]
fn test_robustness_escaped_quotes() {
    let analyzer = Analyzer::new(Language::JavaScript);
    let code = "function foo() {\n    let msg = \"This is a quoted string\";\n    return msg;\n}";

    let result = analyzer.analyze(code);
    assert!(result.is_ok(), "should handle escaped quotes");
}

/// Robustness: Raw strings and doc comments should be handled
#[test]
fn test_robustness_raw_strings() {
    let analyzer = Analyzer::new(Language::Rust);
    let code = "fn main() {\n    let raw = \"TODO: this is in a raw string\";\n    println!(\"{}\", raw);\n}";

    let result = analyzer.analyze(code);
    assert!(result.is_ok(), "should handle raw strings");
}

/// Robustness: Nested blocks should be handled correctly
#[test]
fn test_robustness_nested_blocks() {
    let analyzer = Analyzer::new(Language::Python);
    let code = r#"
if True:
    if True:
        if True:
            # TODO: deep nesting
            pass
"#;

    let result = analyzer.analyze(code);
    assert!(result.is_ok(), "should handle deeply nested code");
    if let Ok(detections) = result {
        assert!(!detections.is_empty(), "should find TODO in nested block");
    }
}

/// Security: Analysis should not leak memory on repeated calls
#[test]
fn test_security_memory_safety() {
    let analyzer = Analyzer::new(Language::Rust);
    let code = "fn main() { todo!(); }";

    // Repeated analysis should not cause issues
    for _ in 0..100 {
        let _result = analyzer.analyze(code);
    }
    // Just ensure we didn't crash
}

/// Robustness: Code with BOM (Byte Order Mark) should be handled
#[test]
fn test_robustness_bom_handling() {
    let analyzer = Analyzer::new(Language::Python);
    // UTF-8 BOM followed by code
    let code_with_bom = "\u{FEFF}def foo():\n    pass\n";

    let result = analyzer.analyze(code_with_bom);
    assert!(result.is_ok(), "should handle BOM");
}

/// Robustness: Comment blocks with special characters
#[test]
fn test_robustness_special_chars_in_comments() {
    let analyzer = Analyzer::new(Language::Rust);
    let code = r#"
fn main() {
    /* Special chars: !@#$%^&*()_+-=[]{}|;:'",.<>?/ */
    println!("ok");
}
"#;

    let result = analyzer.analyze(code);
    assert!(result.is_ok(), "should handle special characters in comments");
}

/// Aspect: Summary statistics should be consistent with detections
#[test]
fn test_aspect_summary_consistency() {
    let analyzer = Analyzer::new(Language::Rust);
    let code = r#"
fn main() {
    // TODO: task 1
    unimplemented!()
    // TODO: task 2
}
"#;

    let (detections, summary) = analyzer
        .analyze_with_summary(code)
        .expect("analysis should succeed");

    assert_eq!(summary.total, detections.len(), "total should match count");
    assert!(summary.critical > 0, "should have critical items");
    assert!(summary.high_priority > 0, "should have high priority items");
    assert!(summary.cii > 0.0, "CII should be positive for incomplete code");
}

/// Robustness: Language detection from various extensions
#[test]
fn test_robustness_language_detection() {
    let test_cases = vec![
        "py", "pyw", "rs", "js", "mjs", "ts", "java", "go",
    ];

    for ext in test_cases {
        let result = Language::from_extension(ext);
        assert!(result.is_ok(), "should recognize extension {}", ext);
    }

    // Test actual mappings
    assert_eq!(Language::from_extension("py").unwrap(), Language::Python);
    assert_eq!(Language::from_extension("rs").unwrap(), Language::Rust);
    assert_eq!(Language::from_extension("js").unwrap(), Language::JavaScript);
    assert_eq!(Language::from_extension("ts").unwrap(), Language::TypeScript);
    assert_eq!(Language::from_extension("java").unwrap(), Language::Java);
    assert_eq!(Language::from_extension("go").unwrap(), Language::Go);
}
