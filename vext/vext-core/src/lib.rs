// SPDX-License-Identifier: PMPL-1.0-or-later
//! Vext - High-performance IRC notification daemon for version control systems
//!
//! This crate provides the core functionality for vext, including IRC client
//! management, notification protocol handling, and optional document processing,
//! spell checking, and internationalization features.

#![forbid(unsafe_code)]
pub mod config;
pub mod error;
pub mod irc_client;
pub mod listener;
pub mod pool;
pub mod protocol;

// Optional features
pub mod pandoc;
pub mod spellcheck;
pub mod i18n;

pub use error::VextError as Error;
pub type Result<T> = std::result::Result<T, Error>;
