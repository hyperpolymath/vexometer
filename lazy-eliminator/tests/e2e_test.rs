// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

//! End-to-end tests for the full analysis pipeline

use vex_lazy_eliminator::{Analyzer, IncompletenessKind, Language};

#[test]
fn test_e2e_python_analysis_pipeline() {
    let analyzer = Analyzer::new(Language::Python);
    let code = r#"
def process_data(items):
    # TODO: add validation
    results = []
    for item in items:
        results.append(item * 2)
    return results
"#;

    let detections = analyzer.analyze(code).expect("analysis should succeed");
    assert!(!detections.is_empty(), "should detect TODO comment");
    assert!(
        detections.iter().any(|d| d.kind == IncompletenessKind::TodoComment),
        "should find TODO comment"
    );
}

#[test]
fn test_e2e_multi_language_analysis() {
    // Python
    let py_analyzer = Analyzer::new(Language::Python);
    let py_code = r#"
def foo():
    raise NotImplementedError("WIP")
"#;
    let py_detections = py_analyzer.analyze(py_code).expect("python analysis should succeed");
    assert!(py_detections.iter().any(|d| d.kind == IncompletenessKind::UnimplementedCode));

    // Rust
    let rs_analyzer = Analyzer::new(Language::Rust);
    let rs_code = r#"
fn complex_function() {
    todo!("implement this")
}
"#;
    let rs_detections = rs_analyzer.analyze(rs_code).expect("rust analysis should succeed");
    assert!(rs_detections.iter().any(|d| d.kind == IncompletenessKind::UnimplementedCode));

    // JavaScript
    let js_analyzer = Analyzer::new(Language::JavaScript);
    let js_code = r#"
function process() {
    throw new Error("unimplemented");
}
"#;
    let js_detections = js_analyzer.analyze(js_code).expect("js analysis should succeed");
    assert!(js_detections.iter().any(|d| d.kind == IncompletenessKind::UnimplementedCode));
}

#[test]
fn test_e2e_analysis_with_summary() {
    let analyzer = Analyzer::new(Language::Rust);
    let code = r#"
fn main() {
    // TODO: implement main
    unimplemented!("main not done")
}
"#;

    let (_detections, summary) = analyzer
        .analyze_with_summary(code)
        .expect("analysis with summary should succeed");

    assert!(summary.total > 0, "should have detections");
    assert!(summary.critical > 0, "should have critical items");
    assert!(summary.cii > 0.0, "CII should be positive for incomplete code");
    assert!(summary.max_severity > 0.0, "max severity should be positive");
}

#[test]
fn test_e2e_complete_code_analysis() {
    let analyzer = Analyzer::new(Language::Rust);
    let code = r#"
fn add(a: i32, b: i32) -> i32 {
    a + b
}

fn main() {
    println!("{}", add(2, 3));
}
"#;

    assert!(analyzer.is_complete(code).expect("is_complete should succeed"));
    let (detections, summary) = analyzer
        .analyze_with_summary(code)
        .expect("analysis should succeed");
    assert!(detections.is_empty(), "should have no detections");
    assert_eq!(summary.total, 0, "total should be 0");
    assert_eq!(summary.cii, 0.0, "CII should be 0 for complete code");
}

#[test]
fn test_e2e_empty_input() {
    let analyzer = Analyzer::new(Language::Python);
    let empty_code = "";

    let detections = analyzer.analyze(empty_code).expect("analysis should succeed");
    assert!(detections.is_empty(), "empty code should have no detections");
    assert!(analyzer.is_complete(empty_code).expect("is_complete should succeed"));
}

#[test]
fn test_e2e_placeholder_detection() {
    let analyzer = Analyzer::new(Language::JavaScript);
    let code = r#"
function process(data) {
    const result = ...
    return result;
}
"#;

    let detections = analyzer.analyze(code).expect("analysis should succeed");
    assert!(
        detections.iter().any(|d| d.kind == IncompletenessKind::PlaceholderText),
        "should detect ellipsis placeholder"
    );
}

#[test]
fn test_e2e_truncation_marker_detection() {
    let analyzer = Analyzer::new(Language::Rust);
    let code = r#"
fn process_items() {
    // ... (truncated)
    println!("done");
}
"#;

    let detections = analyzer.analyze(code).expect("analysis should succeed");
    assert!(
        detections.iter().any(|d| d.kind == IncompletenessKind::TruncationMarker),
        "should detect truncation marker"
    );
}

#[test]
fn test_e2e_multiple_detections() {
    let analyzer = Analyzer::new(Language::Python);
    let code = r#"
def process():
    # TODO: add validation
    pass
    # TODO: improve performance
    result = ...
    return result
"#;

    let detections = analyzer.analyze(code).expect("analysis should succeed");
    assert!(
        detections.len() >= 3,
        "should detect multiple issues: 2 TODOs + 1 placeholder"
    );
}

#[test]
fn test_e2e_detection_context() {
    let analyzer = Analyzer::new(Language::Rust);
    let code = r#"
fn main() {
    let x = 5;
    unimplemented!("needs work");
    let y = 10;
}
"#;

    let detections = analyzer.analyze(code).expect("analysis should succeed");
    assert!(!detections.is_empty());

    let detection = &detections[0];
    assert!(
        detection.context.contains("let x = 5;"),
        "context should include surrounding code"
    );
    assert!(
        detection.context.contains("let y = 10;"),
        "context should include code after detection"
    );
}

#[test]
fn test_e2e_detection_snippet() {
    let analyzer = Analyzer::new(Language::Python);
    let code = r#"
def foo():
    # TODO: implement
    pass
"#;

    let detections = analyzer.analyze(code).expect("analysis should succeed");
    let todo_detection = detections
        .iter()
        .find(|d| d.kind == IncompletenessKind::TodoComment)
        .expect("should find TODO");

    assert!(todo_detection.snippet.to_lowercase().contains("todo"));
}

#[test]
fn test_e2e_language_detection_from_extension() {
    assert!(Language::from_extension("py").is_ok());
    assert!(Language::from_extension("rs").is_ok());
    assert!(Language::from_extension("js").is_ok());
    assert!(Language::from_extension("ts").is_ok());
    assert!(Language::from_extension("java").is_ok());
    assert!(Language::from_extension("go").is_ok());
    assert!(Language::from_extension("unknown").is_err());
}

#[test]
fn test_e2e_cii_calculation() {
    let analyzer = Analyzer::new(Language::Rust);

    let complete_code = "fn add(a: i32, b: i32) -> i32 { a + b }";
    let cii_complete = analyzer
        .calculate_cii(complete_code)
        .expect("cii calculation should succeed");
    assert_eq!(cii_complete, 0.0, "complete code should have CII of 0");

    let incomplete_code = "fn foo() { unimplemented!() }";
    let cii_incomplete = analyzer
        .calculate_cii(incomplete_code)
        .expect("cii calculation should succeed");
    assert!(cii_incomplete > 0.0, "incomplete code should have positive CII");
}

#[test]
fn test_e2e_java_analysis() {
    let analyzer = Analyzer::new(Language::Java);
    let code = r#"
public class Processor {
    public void process() {
        throw new UnsupportedOperationException("not implemented yet");
    }
}
"#;

    let detections = analyzer.analyze(code).expect("java analysis should succeed");
    assert!(
        detections.iter().any(|d| d.kind == IncompletenessKind::UnimplementedCode),
        "should detect UnsupportedOperationException"
    );
}

#[test]
fn test_e2e_go_analysis() {
    let analyzer = Analyzer::new(Language::Go);
    let code = r#"
func process() {
    panic("not implemented")
}
"#;

    let detections = analyzer.analyze(code).expect("go analysis should succeed");
    assert!(
        detections.iter().any(|d| d.kind == IncompletenessKind::UnimplementedCode),
        "should detect panic with not implemented"
    );
}

#[test]
fn test_e2e_null_implementation_detection() {
    let py_analyzer = Analyzer::new(Language::Python);
    let py_code = "def foo():\n    pass\n";
    let py_detections = py_analyzer.analyze(py_code).expect("analysis should succeed");
    assert!(py_detections.iter().any(|d| d.kind == IncompletenessKind::NullImplementation));

    let js_analyzer = Analyzer::new(Language::JavaScript);
    let js_code = "function foo() { return null; }";
    let js_detections = js_analyzer.analyze(js_code).expect("analysis should succeed");
    assert!(js_detections.iter().any(|d| d.kind == IncompletenessKind::NullImplementation));
}

#[test]
fn test_e2e_detection_line_numbers() {
    let analyzer = Analyzer::new(Language::Rust);
    let code = "fn main() {\n    // line 2\n    todo!(\"line 3\");\n}";

    let detections = analyzer.analyze(code).expect("analysis should succeed");
    let todo_detection = detections
        .iter()
        .find(|d| d.kind == IncompletenessKind::UnimplementedCode)
        .expect("should find todo!");

    assert_eq!(todo_detection.line, 3, "detection should be on line 3");
}
