// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

use crate::Result;
use serde::{Deserialize, Serialize};
use std::path::Path;

/// Configuration for vex-lazy-eliminator
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    #[serde(default)]
    pub thresholds: Thresholds,

    #[serde(default)]
    pub languages: LanguageConfig,

    #[serde(default)]
    pub ignore: IgnoreConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Thresholds {
    #[serde(default)]
    pub max_todo: Option<usize>,

    #[serde(default)]
    pub max_placeholder: Option<usize>,

    #[serde(default)]
    pub max_unimplemented: Option<usize>,

    #[serde(default = "default_max_cii")]
    pub max_cii: f64,
}

fn default_max_cii() -> f64 {
    0.5
}

impl Default for Thresholds {
    fn default() -> Self {
        Self {
            max_todo: None,
            max_placeholder: None,
            max_unimplemented: None,
            max_cii: default_max_cii(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageConfig {
    #[serde(default = "default_enabled_languages")]
    pub enabled: Vec<String>,
}

fn default_enabled_languages() -> Vec<String> {
    vec!["python", "rust", "javascript", "typescript", "java", "go"]
        .into_iter()
        .map(String::from)
        .collect()
}

impl Default for LanguageConfig {
    fn default() -> Self {
        Self {
            enabled: default_enabled_languages(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct IgnoreConfig {
    #[serde(default)]
    pub patterns: Vec<String>,
}

impl Config {
    /// Load configuration from a TOML file
    pub fn from_file(path: impl AsRef<Path>) -> Result<Self> {
        let content = std::fs::read_to_string(path)?;
        Ok(toml::from_str(&content)?)
    }

    /// Load configuration or use default if file doesn't exist
    pub fn load_or_default(path: impl AsRef<Path>) -> Self {
        Self::from_file(path).unwrap_or_default()
    }
}

impl Default for Config {
    fn default() -> Self {
        Self {
            thresholds: Thresholds::default(),
            languages: LanguageConfig::default(),
            ignore: IgnoreConfig::default(),
        }
    }
}
