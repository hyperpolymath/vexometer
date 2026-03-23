// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//! Notification protocol types
//!
//! Defines the JSON notification format used between hooks and the daemon.

use serde::{Deserialize, Serialize};

/// A notification to be sent to IRC
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Notification {
    /// Target IRC URL(s) - format: irc://server/channel or ircs://server/channel
    pub to: Vec<String>,

    /// Message to send
    pub privmsg: String,

    /// Optional project name for nick generation
    #[serde(default)]
    pub project: Option<String>,

    /// Optional repository path
    #[serde(default)]
    pub repository: Option<String>,

    /// Optional branch name
    #[serde(default)]
    pub branch: Option<String>,

    /// Optional commit hash
    #[serde(default)]
    pub commit: Option<String>,

    /// Optional author
    #[serde(default)]
    pub author: Option<String>,

    /// Optional URL for more info
    #[serde(default)]
    pub url: Option<String>,

    /// Optional color scheme
    #[serde(default)]
    pub colors: Option<ColorScheme>,
}

/// Color scheme for IRC messages
#[derive(Debug, Clone, Copy, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum ColorScheme {
    /// No colors (plain text)
    #[default]
    None,
    /// mIRC color codes
    Mirc,
    /// ANSI color codes
    Ansi,
}

/// Parsed IRC target from URL
#[derive(Debug, Clone)]
pub struct IrcTarget {
    /// Server hostname
    pub server: String,

    /// Server port (None = default)
    pub port: Option<u16>,

    /// Use TLS
    pub tls: bool,

    /// Channel name (including #)
    pub channel: String,

    /// Optional channel key
    pub key: Option<String>,
}

impl IrcTarget {
    /// Parse an IRC URL into a target
    ///
    /// Supported formats:
    /// - irc://server/channel
    /// - irc://server:port/channel
    /// - ircs://server/channel (TLS)
    /// - irc://server/channel?key=secret
    pub fn parse(url: &str) -> Option<Self> {
        let (tls, rest) = if let Some(rest) = url.strip_prefix("ircs://") {
            (true, rest)
        } else if let Some(rest) = url.strip_prefix("irc://") {
            (false, rest)
        } else {
            return None;
        };

        // Split on first /
        let (server_part, channel_part) = rest.split_once('/')?;

        // Parse server and optional port
        let (server, port) = if let Some((s, p)) = server_part.split_once(':') {
            (s.to_string(), p.parse().ok())
        } else {
            (server_part.to_string(), None)
        };

        // Parse channel and optional key
        let (channel, key) = if let Some((c, params)) = channel_part.split_once('?') {
            let key = params
                .split('&')
                .find_map(|p| p.strip_prefix("key="))
                .map(|s| s.to_string());
            (format_channel(c), key)
        } else {
            (format_channel(channel_part), None)
        };

        Some(Self {
            server,
            port,
            tls,
            channel,
            key,
        })
    }
}

/// Ensure channel name starts with # or &
fn format_channel(name: &str) -> String {
    if name.starts_with('#') || name.starts_with('&') {
        name.to_string()
    } else {
        format!("#{}", name)
    }
}

/// mIRC color codes
#[allow(dead_code)]
pub mod colors {
    pub const WHITE: &str = "\x0300";
    pub const BLACK: &str = "\x0301";
    pub const BLUE: &str = "\x0302";
    pub const GREEN: &str = "\x0303";
    pub const RED: &str = "\x0304";
    pub const BROWN: &str = "\x0305";
    pub const PURPLE: &str = "\x0306";
    pub const ORANGE: &str = "\x0307";
    pub const YELLOW: &str = "\x0308";
    pub const LIGHT_GREEN: &str = "\x0309";
    pub const CYAN: &str = "\x0310";
    pub const LIGHT_CYAN: &str = "\x0311";
    pub const LIGHT_BLUE: &str = "\x0312";
    pub const PINK: &str = "\x0313";
    pub const GREY: &str = "\x0314";
    pub const LIGHT_GREY: &str = "\x0315";
    pub const RESET: &str = "\x0f";
    pub const BOLD: &str = "\x02";
    pub const ITALIC: &str = "\x1d";
    pub const UNDERLINE: &str = "\x1f";
}

/// Format a commit message with optional colors
pub fn format_commit_message(
    notification: &Notification,
    colors: ColorScheme,
) -> String {
    match colors {
        ColorScheme::None => notification.privmsg.clone(),
        ColorScheme::Mirc => format_mirc_message(notification),
        ColorScheme::Ansi => notification.privmsg.clone(), // ANSI not typically supported in IRC
    }
}

fn format_mirc_message(notification: &Notification) -> String {
    let mut parts = Vec::new();

    if let Some(ref project) = notification.project {
        parts.push(format!("{}[{}]{}", colors::BOLD, project, colors::RESET));
    }

    if let Some(ref branch) = notification.branch {
        parts.push(format!("{}{}{}", colors::GREEN, branch, colors::RESET));
    }

    if let Some(ref commit) = notification.commit {
        let short = if commit.len() > 7 { &commit[..7] } else { commit };
        parts.push(format!("{}{}{}", colors::GREY, short, colors::RESET));
    }

    if let Some(ref author) = notification.author {
        parts.push(format!("{}{}{}", colors::CYAN, author, colors::RESET));
    }

    parts.push(notification.privmsg.clone());

    if let Some(ref url) = notification.url {
        parts.push(format!("{}{}{}", colors::LIGHT_BLUE, url, colors::RESET));
    }

    parts.join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_irc_url() {
        let target = IrcTarget::parse("irc://irc.libera.chat/vext").unwrap();
        assert_eq!(target.server, "irc.libera.chat");
        assert_eq!(target.channel, "#vext");
        assert!(!target.tls);
        assert!(target.port.is_none());
    }

    #[test]
    fn test_parse_ircs_url() {
        let target = IrcTarget::parse("ircs://irc.libera.chat:6697/vext").unwrap();
        assert_eq!(target.server, "irc.libera.chat");
        assert_eq!(target.port, Some(6697));
        assert!(target.tls);
    }

    #[test]
    fn test_parse_url_with_key() {
        let target = IrcTarget::parse("irc://server/secret?key=pass123").unwrap();
        assert_eq!(target.channel, "#secret");
        assert_eq!(target.key, Some("pass123".to_string()));
    }

    #[test]
    fn test_channel_formatting() {
        assert_eq!(format_channel("test"), "#test");
        assert_eq!(format_channel("#test"), "#test");
        assert_eq!(format_channel("&local"), "&local");
    }
}
