// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

//! Completeness enforcement for LLM-generated code
//!
//! This library detects incompleteness patterns in code:
//! - TODO comments
//! - Placeholder text
//! - Unimplemented code blocks
//! - Truncation markers
//! - Null implementations

#![forbid(unsafe_code)]
pub mod analyzer;
pub mod config;
pub mod detection;
pub mod language;
pub mod patterns;
pub mod trace;

pub use analyzer::Analyzer;
pub use config::Config;
pub use detection::{Detection, IncompletenessKind};
pub use language::Language;
pub use trace::{TraceReport, VexometerTrace};

use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("Unsupported language: {0}")]
    UnsupportedLanguage(String),

    #[error("Parse error: {0}")]
    ParseError(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("JSON error: {0}")]
    JsonError(#[from] serde_json::Error),

    #[error("TOML error: {0}")]
    TomlError(#[from] toml::de::Error),
}

pub type Result<T> = std::result::Result<T, Error>;
