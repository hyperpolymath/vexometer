// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

use crate::{Error, Result};
use serde::{Deserialize, Serialize};

/// Supported programming languages
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Language {
    Python,
    Rust,
    JavaScript,
    TypeScript,
    Java,
    Go,
}

impl Language {
    /// Detect language from file extension
    pub fn from_extension(ext: &str) -> Result<Self> {
        match ext {
            "py" | "pyw" => Ok(Self::Python),
            "rs" => Ok(Self::Rust),
            "js" | "mjs" | "cjs" => Ok(Self::JavaScript),
            "ts" | "tsx" | "mts" | "cts" => Ok(Self::TypeScript),
            "java" => Ok(Self::Java),
            "go" => Ok(Self::Go),
            _ => Err(Error::UnsupportedLanguage(ext.to_string())),
        }
    }

    /// Get tree-sitter parser for this language
    pub fn tree_sitter_language(&self) -> tree_sitter::Language {
        match self {
            Self::Python => tree_sitter_python::LANGUAGE.into(),
            Self::Rust => tree_sitter_rust::LANGUAGE.into(),
            Self::JavaScript => tree_sitter_javascript::LANGUAGE.into(),
            Self::TypeScript => tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into(),
            Self::Java => tree_sitter_java::LANGUAGE.into(),
            Self::Go => tree_sitter_go::LANGUAGE.into(),
        }
    }

    /// Returns the comment syntax for this language
    pub fn comment_syntax(&self) -> (&'static str, Option<(&'static str, &'static str)>) {
        match self {
            Self::Python => ("#", None),
            Self::Rust => ("//", Some(("/*", "*/"))),
            Self::JavaScript | Self::TypeScript => ("//", Some(("/*", "*/"))),
            Self::Java => ("//", Some(("/*", "*/"))),
            Self::Go => ("//", Some(("/*", "*/"))),
        }
    }
}

impl std::fmt::Display for Language {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Python => write!(f, "Python"),
            Self::Rust => write!(f, "Rust"),
            Self::JavaScript => write!(f, "JavaScript"),
            Self::TypeScript => write!(f, "TypeScript"),
            Self::Java => write!(f, "Java"),
            Self::Go => write!(f, "Go"),
        }
    }
}

impl std::str::FromStr for Language {
    type Err = Error;

    fn from_str(s: &str) -> Result<Self> {
        match s.to_lowercase().as_str() {
            "python" | "py" => Ok(Self::Python),
            "rust" | "rs" => Ok(Self::Rust),
            "javascript" | "js" => Ok(Self::JavaScript),
            "typescript" | "ts" => Ok(Self::TypeScript),
            "java" => Ok(Self::Java),
            "go" | "golang" => Ok(Self::Go),
            _ => Err(Error::UnsupportedLanguage(s.to_string())),
        }
    }
}
