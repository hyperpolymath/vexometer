// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

use criterion::{black_box, criterion_group, criterion_main, Criterion, BenchmarkId};
use vex_lazy_eliminator::{Analyzer, Language};

fn benchmark_single_file_analysis(c: &mut Criterion) {
    let mut group = c.benchmark_group("single_file_analysis");

    // Small code (100 lines)
    let small_base = r#"
fn main() {
    let x = 5;
    let y = 10;
    println!("result: {}", x + y);
}
"#;
    let small_code = small_base.repeat(10);

    group.bench_function("small_100lines", |b| {
        let analyzer = black_box(Analyzer::new(Language::Rust));
        b.iter(|| {
            let _result = analyzer.analyze(black_box(&small_code));
        });
    });

    // Medium code (1000 lines equivalent)
    let medium_base = r#"
fn process(data: Vec<i32>) -> Vec<i32> {
    let mut result = Vec::new();
    for item in data {
        if item > 0 {
            result.push(item * 2);
        }
    }
    result
}

fn main() {
    let data = vec![1, 2, 3, 4, 5];
    let _result = process(data);
}
"#;
    let medium_code = medium_base.repeat(100);

    group.bench_function("medium_1000lines", |b| {
        let analyzer = black_box(Analyzer::new(Language::Rust));
        b.iter(|| {
            let _result = analyzer.analyze(black_box(&medium_code));
        });
    });

    // Large code (10000 lines equivalent)
    let large_base = r#"
fn utility_function(a: i32, b: i32) -> i32 {
    a + b
}

fn another_utility(x: f64) -> f64 {
    x * 2.0
}

fn main() {
    let mut total = 0;
    for i in 0..1000 {
        total += utility_function(i, i);
    }
    println!("{}", total);
}
"#;
    let large_code = large_base.repeat(1000);

    group.bench_function("large_10000lines", |b| {
        let analyzer = black_box(Analyzer::new(Language::Rust));
        b.iter(|| {
            let _result = analyzer.analyze(black_box(&large_code));
        });
    });

    group.finish();
}

fn benchmark_language_detection(c: &mut Criterion) {
    let mut group = c.benchmark_group("language_detection");

    let test_cases = vec![
        ("py", Language::Python),
        ("rs", Language::Rust),
        ("js", Language::JavaScript),
        ("ts", Language::TypeScript),
        ("java", Language::Java),
        ("go", Language::Go),
    ];

    for (ext, _lang) in test_cases {
        group.bench_with_input(
            BenchmarkId::from_parameter(ext),
            &ext,
            |b, &ext| {
                b.iter(|| {
                    let _result = Language::from_extension(black_box(ext));
                });
            },
        );
    }

    group.finish();
}

fn benchmark_config_loading(c: &mut Criterion) {
    c.bench_function("config_creation", |b| {
        b.iter(|| {
            use vex_lazy_eliminator::Config;
            let _config = black_box(Config::default());
        });
    });
}

fn benchmark_pattern_matching(c: &mut Criterion) {
    let mut group = c.benchmark_group("pattern_matching");

    let code_with_todo = "// TODO: implement this\nfn main() { }";
    let code_with_unimplemented = "fn main() { unimplemented!(); }";
    let code_without_issues = "fn main() { println!(\"hello\"); }";

    group.bench_function("detect_todo", |b| {
        let analyzer = black_box(Analyzer::new(Language::Rust));
        b.iter(|| {
            let _result = analyzer.analyze(black_box(code_with_todo));
        });
    });

    group.bench_function("detect_unimplemented", |b| {
        let analyzer = black_box(Analyzer::new(Language::Rust));
        b.iter(|| {
            let _result = analyzer.analyze(black_box(code_with_unimplemented));
        });
    });

    group.bench_function("no_issues_found", |b| {
        let analyzer = black_box(Analyzer::new(Language::Rust));
        b.iter(|| {
            let _result = analyzer.analyze(black_box(code_without_issues));
        });
    });

    group.finish();
}

fn benchmark_cii_calculation(c: &mut Criterion) {
    let mut group = c.benchmark_group("cii_calculation");

    let complete_code = "fn add(a: i32, b: i32) -> i32 { a + b }";
    let incomplete_code = r#"
fn main() {
    // TODO: finish
    unimplemented!()
}
"#;

    group.bench_function("cii_complete", |b| {
        let analyzer = black_box(Analyzer::new(Language::Rust));
        b.iter(|| {
            let _result = analyzer.calculate_cii(black_box(complete_code));
        });
    });

    group.bench_function("cii_incomplete", |b| {
        let analyzer = black_box(Analyzer::new(Language::Rust));
        b.iter(|| {
            let _result = analyzer.calculate_cii(black_box(incomplete_code));
        });
    });

    group.finish();
}

fn benchmark_multi_language(c: &mut Criterion) {
    let mut group = c.benchmark_group("multi_language");

    let py_code = "def foo():\n    # TODO: implement\n    pass";
    let rs_code = "fn foo() { todo!(); }";
    let js_code = "function foo() { // TODO: implement\n    return null; }";
    let java_code = "public void foo() throws Exception {\n    // TODO: implement\n}";
    let go_code = "func foo() {\n    panic(\"not implemented\")\n}";

    group.bench_function("python_analysis", |b| {
        let analyzer = black_box(Analyzer::new(Language::Python));
        b.iter(|| {
            let _result = analyzer.analyze(black_box(py_code));
        });
    });

    group.bench_function("rust_analysis", |b| {
        let analyzer = black_box(Analyzer::new(Language::Rust));
        b.iter(|| {
            let _result = analyzer.analyze(black_box(rs_code));
        });
    });

    group.bench_function("javascript_analysis", |b| {
        let analyzer = black_box(Analyzer::new(Language::JavaScript));
        b.iter(|| {
            let _result = analyzer.analyze(black_box(js_code));
        });
    });

    group.bench_function("java_analysis", |b| {
        let analyzer = black_box(Analyzer::new(Language::Java));
        b.iter(|| {
            let _result = analyzer.analyze(black_box(java_code));
        });
    });

    group.bench_function("go_analysis", |b| {
        let analyzer = black_box(Analyzer::new(Language::Go));
        b.iter(|| {
            let _result = analyzer.analyze(black_box(go_code));
        });
    });

    group.finish();
}

fn benchmark_analysis_with_summary(c: &mut Criterion) {
    let code = r#"
fn main() {
    // TODO: task 1
    let x = 5;
    unimplemented!()
    // TODO: task 2
}
"#;

    c.bench_function("analyze_with_summary", |b| {
        let analyzer = black_box(Analyzer::new(Language::Rust));
        b.iter(|| {
            let _result = analyzer.analyze_with_summary(black_box(code));
        });
    });
}

criterion_group!(
    benches,
    benchmark_single_file_analysis,
    benchmark_language_detection,
    benchmark_config_loading,
    benchmark_pattern_matching,
    benchmark_cii_calculation,
    benchmark_multi_language,
    benchmark_analysis_with_summary,
);

criterion_main!(benches);
