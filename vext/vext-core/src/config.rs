// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//! Configuration management for vextd

use std::path::Path;

use anyhow::Result;
use serde::{Deserialize, Serialize};

/// Main configuration structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    /// Default IRC server hostname
    pub default_server: String,

    /// Default IRC port
    pub default_port: u16,

    /// Use TLS for connections
    pub use_tls: bool,

    /// Maximum connections per server
    pub max_connections: usize,

    /// Bot nick prefix
    pub nick_prefix: String,

    /// Rate limiting: messages per second
    pub rate_limit: f64,

    /// Connection timeout in seconds
    pub connect_timeout: u64,

    /// Idle timeout before disconnecting (seconds)
    pub idle_timeout: u64,

    /// Channels to auto-join on connect
    pub auto_join: Vec<String>,

    /// Server-specific overrides
    pub servers: Vec<ServerConfig>,
}

/// Per-server configuration override
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConfig {
    /// Server hostname pattern (supports wildcards)
    pub pattern: String,

    /// Override port
    pub port: Option<u16>,

    /// Override TLS setting
    pub use_tls: Option<bool>,

    /// Server password
    pub password: Option<String>,

    /// NickServ password
    pub nickserv_password: Option<String>,

    /// SASL credentials
    pub sasl: Option<SaslConfig>,
}

/// SASL authentication configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaslConfig {
    /// SASL mechanism (PLAIN, EXTERNAL)
    pub mechanism: String,

    /// Username for SASL PLAIN
    pub username: Option<String>,

    /// Password for SASL PLAIN
    pub password: Option<String>,
}

impl Config {
    /// Create a new configuration with defaults
    pub fn new(
        default_server: String,
        default_port: u16,
        use_tls: bool,
        max_connections: usize,
        nick_prefix: String,
    ) -> Self {
        Self {
            default_server,
            default_port,
            use_tls,
            max_connections,
            nick_prefix,
            rate_limit: 1.0,
            connect_timeout: 30,
            idle_timeout: 300,
            auto_join: Vec::new(),
            servers: Vec::new(),
        }
    }

    /// Load configuration from a TOML file
    pub fn from_file(path: &Path) -> Result<Self> {
        let content = std::fs::read_to_string(path)?;
        let config: Self = toml::from_str(&content)?;
        Ok(config)
    }

    /// Save configuration to a TOML file
    pub fn to_file(&self, path: &Path) -> Result<()> {
        let content = toml::to_string_pretty(self)?;
        std::fs::write(path, content)?;
        Ok(())
    }

    /// Get server-specific configuration for a hostname.
    ///
    /// Supports anchored wildcard matching:
    /// - `*.example.com` matches any hostname whose suffix after the first dot
    ///   equals `example.com` (e.g. `irc.example.com`, `chat.example.com`).
    /// - `prefix.*` matches any hostname whose prefix before the last dot
    ///   equals `prefix` (e.g. `prefix.net`, `prefix.org`).
    /// - All other patterns require an exact match.
    pub fn server_config(&self, hostname: &str) -> Option<&ServerConfig> {
        self.servers.iter().find(|s| {
            if let Some(suffix) = s.pattern.strip_prefix("*.") {
                // *.example.com — match the domain suffix after the first dot
                hostname
                    .find('.')
                    .map(|dot| &hostname[dot + 1..] == suffix)
                    .unwrap_or(false)
            } else if let Some(prefix) = s.pattern.strip_suffix(".*") {
                // prefix.* — match the prefix before the last dot
                hostname
                    .rfind('.')
                    .map(|dot| &hostname[..dot] == prefix)
                    .unwrap_or(false)
            } else {
                // Exact match only
                s.pattern == hostname
            }
        })
    }

    /// Get the port for a specific server
    pub fn port_for(&self, hostname: &str) -> u16 {
        self.server_config(hostname)
            .and_then(|s| s.port)
            .unwrap_or(self.default_port)
    }

    /// Check if TLS should be used for a server
    pub fn use_tls_for(&self, hostname: &str) -> bool {
        self.server_config(hostname)
            .and_then(|s| s.use_tls)
            .unwrap_or(self.use_tls)
    }
}

impl Default for Config {
    fn default() -> Self {
        Self::new(
            "irc.libera.chat".to_string(),
            6697,
            true,
            4,
            "vext".to_string(),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = Config::default();
        assert_eq!(config.default_server, "irc.libera.chat");
        assert_eq!(config.default_port, 6697);
        assert!(config.use_tls);
    }

    #[test]
    fn test_server_config_matching() {
        let mut config = Config::default();
        config.servers.push(ServerConfig {
            pattern: "*.libera.chat".to_string(),
            port: Some(6667),
            use_tls: Some(false),
            password: None,
            nickserv_password: None,
            sasl: None,
        });

        assert_eq!(config.port_for("irc.libera.chat"), 6667);
        assert!(!config.use_tls_for("irc.libera.chat"));
        assert_eq!(config.port_for("other.server"), 6697);
    }
}
