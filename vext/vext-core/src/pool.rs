// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//! Connection pool management
//!
//! Manages multiple IRC connections per server with automatic scaling.

use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

use tokio::sync::Mutex;
use tracing::{debug, info, warn};

use crate::config::Config;
use crate::error::{VextError, VextResult};
use crate::irc_client::{generate_nick, IrcConnection};
use crate::protocol::IrcTarget;

/// Connection pool entry for a server
struct ServerPool {
    /// Active connections
    connections: Vec<Arc<Mutex<IrcConnection>>>,
    /// Round-robin index for load balancing
    next_index: usize,
}

impl ServerPool {
    fn new() -> Self {
        Self {
            connections: Vec::new(),
            next_index: 0,
        }
    }

    /// Get next connection using round-robin
    fn next_connection(&mut self) -> Option<Arc<Mutex<IrcConnection>>> {
        if self.connections.is_empty() {
            return None;
        }
        let conn = self.connections[self.next_index].clone();
        self.next_index = (self.next_index + 1) % self.connections.len();
        Some(conn)
    }
}

/// Pool of IRC connections across multiple servers
pub struct ConnectionPool {
    /// Per-server connection pools
    pools: HashMap<String, ServerPool>,
    /// Configuration
    config: Config,
}

impl ConnectionPool {
    /// Create a new connection pool
    pub fn new(config: Config) -> Self {
        Self {
            pools: HashMap::new(),
            config,
        }
    }

    /// Get or create a connection for the given target
    pub async fn get_connection(
        &mut self,
        target: &IrcTarget,
    ) -> VextResult<Arc<Mutex<IrcConnection>>> {
        let server_key = format!("{}:{}", target.server, target.port.unwrap_or(
            if target.tls { 6697 } else { 6667 }
        ));

        // Get or create server pool
        let pool = self.pools.entry(server_key.clone()).or_insert_with(ServerPool::new);

        // Try to find a healthy existing connection
        for conn in &pool.connections {
            let guard = conn.lock().await;
            if guard.is_healthy() {
                drop(guard);
                return Ok(conn.clone());
            }
        }

        // Check if we can create a new connection
        if pool.connections.len() >= self.config.max_connections {
            // Try to reap dead connections
            pool.connections.retain(|_conn| {
                // This is a sync check, actual health check needs the connection
                true // Keep for now, will be checked on use
            });

            if pool.connections.len() >= self.config.max_connections {
                return Err(VextError::PoolExhausted {
                    server: target.server.clone(),
                });
            }
        }

        // Create new connection
        let port = target.port.unwrap_or(self.config.port_for(&target.server));
        let tls = target.tls || self.config.use_tls_for(&target.server);
        let nick = generate_nick(
            &self.config.nick_prefix,
            &target.server,
            pool.connections.len(),
        );

        info!(
            "Creating new connection to {} (TLS: {}, nick: {})",
            server_key, tls, nick
        );

        let conn = IrcConnection::connect(
            &target.server,
            port,
            tls,
            &nick,
            &self.config,
        )
        .await?;

        let conn = Arc::new(Mutex::new(conn));
        pool.connections.push(conn.clone());

        Ok(conn)
    }

    /// Send a message to a target
    pub async fn send_message(
        &mut self,
        target: &IrcTarget,
        message: &str,
    ) -> VextResult<()> {
        let conn = self.get_connection(target).await?;
        let mut guard = conn.lock().await;

        // Ensure we're in the channel
        if !guard.channels.contains(&target.channel) {
            guard.join(&target.channel, target.key.as_deref()).await?;
        }

        guard.privmsg(&target.channel, message).await?;
        guard.last_activity = Instant::now();

        Ok(())
    }

    /// Cleanup idle connections
    pub async fn cleanup_idle(&mut self) {
        let idle_timeout = Duration::from_secs(self.config.idle_timeout);

        for (server, pool) in &mut self.pools {
            let mut to_remove = Vec::new();

            for (i, conn) in pool.connections.iter().enumerate() {
                let guard = conn.lock().await;
                if guard.last_activity.elapsed() > idle_timeout {
                    debug!("Connection {} to {} is idle, marking for removal", i, server);
                    to_remove.push(i);
                }
            }

            // Remove idle connections (in reverse to preserve indices)
            for i in to_remove.into_iter().rev() {
                if let Some(conn) = pool.connections.get(i) {
                    let mut guard = conn.lock().await;
                    let _ = guard.quit(Some("Idle timeout")).await;
                }
                pool.connections.remove(i);
            }
        }
    }

    /// Gracefully shutdown all connections
    pub async fn shutdown(&mut self) {
        info!("Shutting down connection pool");
        for (server, pool) in &mut self.pools {
            for conn in &pool.connections {
                let mut guard = conn.lock().await;
                if let Err(e) = guard.quit(Some("vext shutting down")).await {
                    warn!("Error during shutdown of {}: {}", server, e);
                }
            }
        }
        self.pools.clear();
    }

    /// Get statistics about the pool
    pub fn stats(&self) -> PoolStats {
        let mut total_connections = 0;
        let mut servers = Vec::new();

        for (server, pool) in &self.pools {
            servers.push(server.clone());
            total_connections += pool.connections.len();
        }

        PoolStats {
            total_connections,
            servers,
        }
    }
}

/// Pool statistics
#[derive(Debug)]
#[allow(dead_code)]
pub struct PoolStats {
    pub total_connections: usize,
    pub servers: Vec<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pool_creation() {
        let config = Config::default();
        let pool = ConnectionPool::new(config);
        let stats = pool.stats();
        assert_eq!(stats.total_connections, 0);
        assert!(stats.servers.is_empty());
    }
}
