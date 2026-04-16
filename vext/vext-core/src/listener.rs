// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//! Notification listener
//!
//! TCP/UDP listener that accepts JSON notifications and relays them to IRC.

use std::net::SocketAddr;
use std::sync::Arc;

use anyhow::Result;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::net::{TcpListener, TcpStream, UdpSocket};
use tokio::sync::RwLock;
use tracing::{debug, error, info, warn};

use crate::error::VextError;
use crate::pool::ConnectionPool;
use crate::protocol::{format_commit_message, IrcTarget, Notification};

/// Run the notification listener
pub async fn run(addr: SocketAddr, pool: Arc<RwLock<ConnectionPool>>) -> Result<()> {
    let listener = TcpListener::bind(addr).await?;
    info!("Listening for notifications on {}", addr);

    // Spawn cleanup task
    let pool_cleanup = pool.clone();
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(60));
        loop {
            interval.tick().await;
            let mut guard = pool_cleanup.write().await;
            guard.cleanup_idle().await;
        }
    });

    loop {
        match listener.accept().await {
            Ok((stream, peer)) => {
                debug!("Accepted connection from {}", peer);
                let pool = pool.clone();
                tokio::spawn(async move {
                    if let Err(e) = handle_connection(stream, peer, pool).await {
                        warn!("Error handling connection from {}: {}", peer, e);
                    }
                });
            }
            Err(e) => {
                error!("Accept error: {}", e);
            }
        }
    }
}

/// Handle a single TCP connection
async fn handle_connection(
    stream: TcpStream,
    peer: SocketAddr,
    pool: Arc<RwLock<ConnectionPool>>,
) -> Result<()> {
    let reader = BufReader::new(stream);
    let mut lines = reader.lines();

    while let Some(line) = lines.next_line().await? {
        if line.is_empty() {
            continue;
        }

        debug!("Received from {}: {}", peer, line);

        match serde_json::from_str::<Notification>(&line) {
            Ok(notification) => {
                if let Err(e) = process_notification(notification, &pool).await {
                    error!("Failed to process notification: {}", e);
                }
            }
            Err(e) => {
                warn!("Invalid JSON from {}: {} - {}", peer, e, line);
            }
        }
    }

    debug!("Connection from {} closed", peer);
    Ok(())
}

/// Process a notification and send to IRC
async fn process_notification(
    notification: Notification,
    pool: &Arc<RwLock<ConnectionPool>>,
) -> Result<()> {
    if notification.to.is_empty() {
        return Err(VextError::InvalidNotification("No targets specified".to_string()).into());
    }

    let colors = notification.colors.unwrap_or_default();
    let message = format_commit_message(&notification, colors);

    info!(
        "Sending notification to {} targets: {}",
        notification.to.len(),
        notification.privmsg.chars().take(50).collect::<String>()
    );

    for target_url in &notification.to {
        match IrcTarget::parse(target_url) {
            Some(target) => {
                let mut guard = pool.write().await;
                if let Err(e) = guard.send_message(&target, &message).await {
                    error!("Failed to send to {}: {}", target_url, e);
                } else {
                    debug!("Sent to {}", target_url);
                }
            }
            None => {
                warn!("Invalid IRC URL: {}", target_url);
            }
        }
    }

    Ok(())
}

/// Run a UDP listener (for simpler one-shot notifications)
pub async fn run_udp(addr: SocketAddr, pool: Arc<RwLock<ConnectionPool>>) -> Result<()> {
    let socket = UdpSocket::bind(addr).await?;
    info!("UDP listener bound to {}", addr);

    let mut buf = vec![0u8; 65535];

    loop {
        match socket.recv_from(&mut buf).await {
            Ok((len, peer)) => {
                let data = &buf[..len];
                if let Ok(line) = std::str::from_utf8(data) {
                    debug!("UDP from {}: {}", peer, line);
                    match serde_json::from_str::<Notification>(line) {
                        Ok(notification) => {
                            let pool = pool.clone();
                            tokio::spawn(async move {
                                if let Err(e) = process_notification(notification, &pool).await {
                                    error!("Failed to process UDP notification: {}", e);
                                }
                            });
                        }
                        Err(e) => {
                            warn!("Invalid JSON from UDP {}: {}", peer, e);
                        }
                    }
                }
            }
            Err(e) => {
                error!("UDP recv error: {}", e);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_notification() {
        let json = r#"{
            "to": ["irc://irc.libera.chat/vext"],
            "privmsg": "Test commit message"
        }"#;

        let notification: Notification = serde_json::from_str(json).expect("TODO: handle error");
        assert_eq!(notification.to.len(), 1);
        assert_eq!(notification.privmsg, "Test commit message");
    }

    #[test]
    fn test_notification_with_metadata() {
        let json = r#"{
            "to": ["ircs://irc.libera.chat/vext"],
            "privmsg": "Add new feature",
            "project": "vext",
            "branch": "main",
            "commit": "abc1234",
            "author": "dev"
        }"#;

        let notification: Notification = serde_json::from_str(json).expect("TODO: handle error");
        assert_eq!(notification.project, Some("vext".to_string()));
        assert_eq!(notification.branch, Some("main".to_string()));
    }
}
