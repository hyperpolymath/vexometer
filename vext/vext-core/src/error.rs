// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//! Error types for vextd

use thiserror::Error;

/// Main error type for vext operations
#[derive(Error, Debug)]
pub enum VextError {
    /// IRC connection error
    #[error("IRC connection error: {0}")]
    Connection(String),

    /// IRC protocol error
    #[error("IRC protocol error: {0}")]
    Protocol(String),

    /// Channel join error
    #[error("Failed to join channel {channel}: {reason}")]
    ChannelJoin { channel: String, reason: String },

    /// Authentication error
    #[error("Authentication failed: {0}")]
    Auth(String),

    /// Rate limit exceeded
    #[error("Rate limit exceeded for {target}")]
    RateLimit { target: String },

    /// Invalid notification format
    #[error("Invalid notification: {0}")]
    InvalidNotification(String),

    /// Configuration error
    #[error("Configuration error: {0}")]
    Config(String),

    /// Network error
    #[error("Network error: {0}")]
    Network(#[from] std::io::Error),

    /// TLS error
    #[error("TLS error: {0}")]
    Tls(String),

    /// JSON parsing error
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    /// Connection pool exhausted
    #[error("Connection pool exhausted for server {server}")]
    PoolExhausted { server: String },

    /// Timeout error
    #[error("Operation timed out: {0}")]
    Timeout(String),

    /// Server disconnected
    #[error("Server disconnected: {0}")]
    Disconnected(String),
}

/// Result type alias for vext operations
pub type VextResult<T> = Result<T, VextError>;
