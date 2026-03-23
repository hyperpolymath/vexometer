// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//! IRC client implementation
//!
//! Handles connection to IRC servers, authentication, and message sending.

use std::collections::HashSet;
use std::sync::Arc;
use std::time::{Duration, Instant};

use tokio::io::{AsyncWrite, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::Mutex;
use tokio::time::timeout;
use tokio_native_tls::TlsConnector;
use tracing::{debug, info};

use crate::config::Config;
use crate::error::{VextError, VextResult};

/// Rate limiter for IRC messages
pub struct RateLimiter {
    /// Tokens available
    tokens: f64,
    /// Maximum tokens
    max_tokens: f64,
    /// Tokens per second
    rate: f64,
    /// Last update time
    last_update: Instant,
}

impl RateLimiter {
    pub fn new(rate: f64) -> Self {
        Self {
            tokens: rate * 5.0, // Start with 5 seconds worth
            max_tokens: rate * 10.0,
            rate,
            last_update: Instant::now(),
        }
    }

    /// Try to consume a token, returns wait time if rate limited
    pub fn try_consume(&mut self) -> Option<Duration> {
        let now = Instant::now();
        let elapsed = now.duration_since(self.last_update).as_secs_f64();
        self.last_update = now;

        // Replenish tokens
        self.tokens = (self.tokens + elapsed * self.rate).min(self.max_tokens);

        if self.tokens >= 1.0 {
            self.tokens -= 1.0;
            None
        } else {
            // Calculate wait time
            let wait = (1.0 - self.tokens) / self.rate;
            Some(Duration::from_secs_f64(wait))
        }
    }
}

/// An active IRC connection
pub struct IrcConnection {
    /// Server hostname
    pub server: String,
    /// Server port
    pub port: u16,
    /// Whether TLS is enabled
    pub tls: bool,
    /// Current nick
    pub nick: String,
    /// Channels we've joined
    pub channels: HashSet<String>,
    /// Write half of the connection
    writer: Arc<Mutex<Box<dyn AsyncWrite + Send + Unpin>>>,
    /// Rate limiter
    rate_limiter: Arc<Mutex<RateLimiter>>,
    /// Last activity time
    pub last_activity: Instant,
    /// Connection is alive
    pub alive: bool,
}

impl IrcConnection {
    /// Connect to an IRC server
    pub async fn connect(
        server: &str,
        port: u16,
        tls: bool,
        nick: &str,
        config: &Config,
    ) -> VextResult<Self> {
        let addr = format!("{}:{}", server, port);
        info!("Connecting to IRC server: {} (TLS: {})", addr, tls);

        let connect_timeout = Duration::from_secs(config.connect_timeout);

        let stream = timeout(connect_timeout, TcpStream::connect(&addr))
            .await
            .map_err(|_| VextError::Timeout(format!("Connection to {} timed out", addr)))?
            .map_err(|e| VextError::Connection(e.to_string()))?;

        let writer: Box<dyn AsyncWrite + Send + Unpin> = if tls {
            let connector = native_tls::TlsConnector::builder()
                .build()
                .map_err(|e| VextError::Tls(e.to_string()))?;
            let connector = TlsConnector::from(connector);
            let tls_stream = connector
                .connect(server, stream)
                .await
                .map_err(|e| VextError::Tls(e.to_string()))?;
            let (_, writer) = tokio::io::split(tls_stream);
            Box::new(writer)
        } else {
            let (_, writer) = tokio::io::split(stream);
            Box::new(writer)
        };

        let mut conn = Self {
            server: server.to_string(),
            port,
            tls,
            nick: nick.to_string(),
            channels: HashSet::new(),
            writer: Arc::new(Mutex::new(writer)),
            rate_limiter: Arc::new(Mutex::new(RateLimiter::new(config.rate_limit))),
            last_activity: Instant::now(),
            alive: true,
        };

        // Register with server
        conn.register(nick).await?;

        Ok(conn)
    }

    /// Send a raw IRC command
    async fn send_raw(&self, command: &str) -> VextResult<()> {
        // Check rate limit
        {
            let mut limiter = self.rate_limiter.lock().await;
            if let Some(wait) = limiter.try_consume() {
                debug!("Rate limited, waiting {:?}", wait);
                tokio::time::sleep(wait).await;
            }
        }

        let mut writer = self.writer.lock().await;
        let line = format!("{}\r\n", command);
        debug!(">> {}", command);
        writer
            .write_all(line.as_bytes())
            .await
            .map_err(VextError::Network)?;
        writer.flush().await.map_err(VextError::Network)?;
        Ok(())
    }

    /// Register with the IRC server (NICK + USER)
    async fn register(&mut self, nick: &str) -> VextResult<()> {
        self.send_raw(&format!("NICK {}", nick)).await?;
        self.send_raw(&format!(
            "USER {} 0 * :vext IRC notification bot",
            nick
        ))
        .await?;
        self.nick = nick.to_string();
        Ok(())
    }

    /// Join a channel
    pub async fn join(&mut self, channel: &str, key: Option<&str>) -> VextResult<()> {
        if self.channels.contains(channel) {
            debug!("Already in channel {}", channel);
            return Ok(());
        }

        let cmd = if let Some(k) = key {
            format!("JOIN {} {}", channel, k)
        } else {
            format!("JOIN {}", channel)
        };

        self.send_raw(&cmd).await?;
        self.channels.insert(channel.to_string());
        self.last_activity = Instant::now();
        info!("Joined channel {}", channel);
        Ok(())
    }

    /// Send a PRIVMSG to a channel.
    ///
    /// Long messages are split into chunks that respect UTF-8 character
    /// boundaries so multi-byte characters are never torn across packets.
    pub async fn privmsg(&self, target: &str, message: &str) -> VextResult<()> {
        // IRC limit is typically 512 bytes including CRLF.
        // Leave room for "PRIVMSG <target> :" prefix + CRLF.
        let max_len = 400;
        let mut remaining = message;

        while !remaining.is_empty() {
            let chunk = if remaining.len() <= max_len {
                remaining
            } else {
                // Walk backwards from max_len to find the nearest UTF-8
                // char boundary so we never split a multi-byte character.
                let mut end = max_len;
                while !remaining.is_char_boundary(end) && end > 0 {
                    end -= 1;
                }
                &remaining[..end]
            };

            self.send_raw(&format!("PRIVMSG {} :{}", target, chunk))
                .await?;
            remaining = &remaining[chunk.len()..];
        }
        Ok(())
    }

    /// Send a NOTICE to a channel
    pub async fn notice(&self, target: &str, message: &str) -> VextResult<()> {
        self.send_raw(&format!("NOTICE {} :{}", target, message))
            .await
    }

    /// Part from a channel
    pub async fn part(&mut self, channel: &str, reason: Option<&str>) -> VextResult<()> {
        let cmd = if let Some(r) = reason {
            format!("PART {} :{}", channel, r)
        } else {
            format!("PART {}", channel)
        };
        self.send_raw(&cmd).await?;
        self.channels.remove(channel);
        Ok(())
    }

    /// Quit from the server
    pub async fn quit(&mut self, message: Option<&str>) -> VextResult<()> {
        let cmd = if let Some(m) = message {
            format!("QUIT :{}", m)
        } else {
            "QUIT :vext shutting down".to_string()
        };
        self.send_raw(&cmd).await?;
        self.alive = false;
        Ok(())
    }

    /// Respond to PING
    pub async fn pong(&self, token: &str) -> VextResult<()> {
        self.send_raw(&format!("PONG :{}", token)).await
    }

    /// Check if connection is healthy
    pub fn is_healthy(&self) -> bool {
        self.alive && self.last_activity.elapsed() < Duration::from_secs(300)
    }
}

/// Generate a unique nick for a connection
pub fn generate_nick(prefix: &str, server: &str, index: usize) -> String {
    // Use first 3 chars of server hash + index for uniqueness
    let hash: u32 = server.bytes().map(|b| b as u32).sum();
    format!("{}_{:x}{}", prefix, hash % 0xFFF, index)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_nick() {
        let nick1 = generate_nick("vext", "irc.libera.chat", 0);
        let nick2 = generate_nick("vext", "irc.libera.chat", 1);
        assert_ne!(nick1, nick2);
        assert!(nick1.starts_with("vext_"));
    }

    #[test]
    fn test_rate_limiter() {
        let mut limiter = RateLimiter::new(2.0); // 2 msgs/sec

        // First few should pass (we start with tokens)
        assert!(limiter.try_consume().is_none());
        assert!(limiter.try_consume().is_none());
    }
}
