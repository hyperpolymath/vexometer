// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

use crate::detection::IncompletenessKind;
use crate::language::Language;
use regex::Regex;

/// Pattern definition for detecting incompleteness
pub struct Pattern {
    pub kind: IncompletenessKind,
    pub regex: Regex,
    pub description: &'static str,
}

/// Get regex patterns for a specific language
pub fn get_patterns(language: Language) -> Vec<Pattern> {
    let mut patterns = vec![];

    // TODO patterns (common across languages)
    patterns.extend(todo_patterns());

    // Language-specific patterns
    match language {
        Language::Python => patterns.extend(python_patterns()),
        Language::Rust => patterns.extend(rust_patterns()),
        Language::JavaScript | Language::TypeScript => patterns.extend(javascript_patterns()),
        Language::Java => patterns.extend(java_patterns()),
        Language::Go => patterns.extend(go_patterns()),
    }

    patterns
}

fn todo_patterns() -> Vec<Pattern> {
    vec![
        Pattern {
            kind: IncompletenessKind::TodoComment,
            regex: Regex::new(r"(?i)//\s*TODO[:\s]").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "C-style TODO comment",
        },
        Pattern {
            kind: IncompletenessKind::TodoComment,
            regex: Regex::new(r"(?i)#\s*TODO[:\s]").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Hash-style TODO comment",
        },
        Pattern {
            kind: IncompletenessKind::TodoComment,
            regex: Regex::new(r"(?i)/\*\s*TODO[:\s]").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Block comment TODO",
        },
        Pattern {
            kind: IncompletenessKind::PlaceholderText,
            regex: Regex::new(r"\.\.\.").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Ellipsis placeholder",
        },
        Pattern {
            kind: IncompletenessKind::PlaceholderText,
            regex: Regex::new(r"<placeholder>").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Explicit placeholder tag",
        },
        Pattern {
            kind: IncompletenessKind::TruncationMarker,
            regex: Regex::new(r"//\s*\.\.\.\s*\(truncated\)").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Truncation marker",
        },
        Pattern {
            kind: IncompletenessKind::TruncationMarker,
            regex: Regex::new(r"//\s*rest similar").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Rest similar marker",
        },
    ]
}

fn python_patterns() -> Vec<Pattern> {
    vec![
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r"\braise\s+NotImplementedError\b").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Python NotImplementedError",
        },
        Pattern {
            kind: IncompletenessKind::NullImplementation,
            regex: Regex::new(r"^\s*pass\s*$").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Python pass statement",
        },
    ]
}

fn rust_patterns() -> Vec<Pattern> {
    vec![
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r"\bunimplemented!\(").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Rust unimplemented! macro",
        },
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r"\btodo!\(").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Rust todo! macro",
        },
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r"\bunreachable!\(").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Rust unreachable! macro",
        },
    ]
}

fn javascript_patterns() -> Vec<Pattern> {
    vec![
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r#"throw\s+new\s+Error\(\s*["'](?:unimplemented|not implemented)["']\s*\)"#).expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "JavaScript unimplemented error",
        },
        Pattern {
            kind: IncompletenessKind::NullImplementation,
            regex: Regex::new(r"return\s+null\s*;").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Return null",
        },
        Pattern {
            kind: IncompletenessKind::NullImplementation,
            regex: Regex::new(r"^\s*\{\s*\}\s*$").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Empty block",
        },
    ]
}

fn java_patterns() -> Vec<Pattern> {
    vec![
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r#"throw\s+new\s+UnsupportedOperationException\(\s*["'].*not.*implemented.*["']\s*\)"#).expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Java UnsupportedOperationException",
        },
        Pattern {
            kind: IncompletenessKind::NullImplementation,
            regex: Regex::new(r"return\s+null\s*;").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Return null",
        },
    ]
}

fn go_patterns() -> Vec<Pattern> {
    vec![
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r#"panic\(\s*["']not implemented["']\s*\)"#).expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Go panic(\"not implemented\")",
        },
        Pattern {
            kind: IncompletenessKind::NullImplementation,
            regex: Regex::new(r"return\s+nil").expect("static regex literal in patterns.rs is well-formed (verified by tests)"),
            description: "Return nil",
        },
    ]
}
