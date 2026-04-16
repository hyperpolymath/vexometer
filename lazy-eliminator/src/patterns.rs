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
            regex: Regex::new(r"(?i)//\s*TODO[:\s]").expect("TODO: handle error"),
            description: "C-style TODO comment",
        },
        Pattern {
            kind: IncompletenessKind::TodoComment,
            regex: Regex::new(r"(?i)#\s*TODO[:\s]").expect("TODO: handle error"),
            description: "Hash-style TODO comment",
        },
        Pattern {
            kind: IncompletenessKind::TodoComment,
            regex: Regex::new(r"(?i)/\*\s*TODO[:\s]").expect("TODO: handle error"),
            description: "Block comment TODO",
        },
        Pattern {
            kind: IncompletenessKind::PlaceholderText,
            regex: Regex::new(r"\.\.\.").expect("TODO: handle error"),
            description: "Ellipsis placeholder",
        },
        Pattern {
            kind: IncompletenessKind::PlaceholderText,
            regex: Regex::new(r"<placeholder>").expect("TODO: handle error"),
            description: "Explicit placeholder tag",
        },
        Pattern {
            kind: IncompletenessKind::TruncationMarker,
            regex: Regex::new(r"//\s*\.\.\.\s*\(truncated\)").expect("TODO: handle error"),
            description: "Truncation marker",
        },
        Pattern {
            kind: IncompletenessKind::TruncationMarker,
            regex: Regex::new(r"//\s*rest similar").expect("TODO: handle error"),
            description: "Rest similar marker",
        },
    ]
}

fn python_patterns() -> Vec<Pattern> {
    vec![
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r"\braise\s+NotImplementedError\b").expect("TODO: handle error"),
            description: "Python NotImplementedError",
        },
        Pattern {
            kind: IncompletenessKind::NullImplementation,
            regex: Regex::new(r"^\s*pass\s*$").expect("TODO: handle error"),
            description: "Python pass statement",
        },
    ]
}

fn rust_patterns() -> Vec<Pattern> {
    vec![
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r"\bunimplemented!\(").expect("TODO: handle error"),
            description: "Rust unimplemented! macro",
        },
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r"\btodo!\(").expect("TODO: handle error"),
            description: "Rust todo! macro",
        },
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r"\bunreachable!\(").expect("TODO: handle error"),
            description: "Rust unreachable! macro",
        },
    ]
}

fn javascript_patterns() -> Vec<Pattern> {
    vec![
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r#"throw\s+new\s+Error\(\s*["'](?:unimplemented|not implemented)["']\s*\)"#).expect("TODO: handle error"),
            description: "JavaScript unimplemented error",
        },
        Pattern {
            kind: IncompletenessKind::NullImplementation,
            regex: Regex::new(r"return\s+null\s*;").expect("TODO: handle error"),
            description: "Return null",
        },
        Pattern {
            kind: IncompletenessKind::NullImplementation,
            regex: Regex::new(r"^\s*\{\s*\}\s*$").expect("TODO: handle error"),
            description: "Empty block",
        },
    ]
}

fn java_patterns() -> Vec<Pattern> {
    vec![
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r#"throw\s+new\s+UnsupportedOperationException\(\s*["'].*not.*implemented.*["']\s*\)"#).expect("TODO: handle error"),
            description: "Java UnsupportedOperationException",
        },
        Pattern {
            kind: IncompletenessKind::NullImplementation,
            regex: Regex::new(r"return\s+null\s*;").expect("TODO: handle error"),
            description: "Return null",
        },
    ]
}

fn go_patterns() -> Vec<Pattern> {
    vec![
        Pattern {
            kind: IncompletenessKind::UnimplementedCode,
            regex: Regex::new(r#"panic\(\s*["']not implemented["']\s*\)"#).expect("TODO: handle error"),
            description: "Go panic(\"not implemented\")",
        },
        Pattern {
            kind: IncompletenessKind::NullImplementation,
            regex: Regex::new(r"return\s+nil").expect("TODO: handle error"),
            description: "Return nil",
        },
    ]
}
