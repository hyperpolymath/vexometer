// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
//! Gossamer Groove endpoint for Vext.
//!
//! Exposes Vext's integrity verification capabilities via the groove
//! discovery protocol. Any groove-aware system (Gossamer, Burble, PanLL, etc.)
//! can discover Vext by probing GET /.well-known/groove on port 6480.
//!
//! Vext works standalone — integrity verification functions perfectly
//! without any groove consumer. When Burble grooves in, text/voice
//! channels gain cryptographic hash chain verification. When VeriSimDB
//! grooves in, verification proofs are persisted as octad entities.
//!
//! The groove connector types are formally verified in Gossamer's Groove.idr:
//! - IsSubset proves consumers can only connect if Vext satisfies their needs
//! - GrooveHandle is linear: consumers MUST disconnect (no dangling grooves)
//! - GrooveCompat proves Burble↔Vext composition is sound
//!
//! ## Groove Protocol
//!
//! - `GET  /.well-known/groove`         — Capability manifest (JSON)
//! - `POST /.well-known/groove/message` — Receive message from consumer
//! - `GET  /.well-known/groove/recv`    — Pending messages for consumer
//!
//! ## Capabilities Offered
//!
//! - `integrity`         — Hash chain verification for message integrity
//! - `feed-verification` — Proof that feeds are chronological and uninjected
//! - `hash-chain`        — Merkle tree construction and verification
//! - `attestation`       — Digital signature attestation with a2ml proofs
//!
//! ## Capabilities Consumed (enhanced when available)
//!
//! - `voice` (from Burble) — Verify voice channel integrity
//! - `text`  (from Burble) — Verify text channel hash chains
//! - `octad-storage` (from VeriSimDB) — Persist verification proofs

use std::collections::VecDeque;
use std::net::SocketAddr;
use std::sync::Arc;

use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio::sync::Mutex;
use tracing::{debug, error, info, warn};

/// The groove capability manifest for Vext.
/// Matches Groove.idr vextManifest: offers [Integrity, FeedVerify, HashChain, Attestation].
const MANIFEST: &str = r#"{
  "groove_version": "1",
  "service_id": "vext",
  "service_version": "0.1.0",
  "capabilities": {
    "integrity": {
      "type": "integrity",
      "description": "Cryptographic hash chain verification for message integrity",
      "protocol": "http",
      "endpoint": "/api/v1/verify",
      "requires_auth": false,
      "panel_compatible": true
    },
    "feed_verification": {
      "type": "feed-verification",
      "description": "Proof that feeds are chronological, complete, and uninjected (a2ml)",
      "protocol": "http",
      "endpoint": "/api/v1/feed/verify",
      "requires_auth": false,
      "panel_compatible": true
    },
    "hash_chain": {
      "type": "hash-chain",
      "description": "Merkle tree construction and verification for arbitrary data",
      "protocol": "http",
      "endpoint": "/api/v1/chain",
      "requires_auth": false,
      "panel_compatible": false
    },
    "attestation": {
      "type": "attestation",
      "description": "Digital signature attestation with a2ml proofs (Avow integration)",
      "protocol": "http",
      "endpoint": "/api/v1/attest",
      "requires_auth": true,
      "panel_compatible": true
    }
  },
  "consumes": ["voice", "text", "octad-storage"],
  "endpoints": {
    "api": "http://localhost:6480/api/v1",
    "health": "http://localhost:6480/health"
  },
  "health": "/health",
  "applicability": ["individual", "team", "massive-open"]
}"#;

/// Maximum message queue depth to prevent memory exhaustion.
const MAX_QUEUE_DEPTH: usize = 1000;

/// Maximum HTTP request size (16 KiB).
const MAX_REQUEST_SIZE: usize = 16 * 1024;

/// Shared state for the groove endpoint.
pub struct GrooveState {
    /// Inbound message queue (from groove consumers).
    inbound: VecDeque<serde_json::Value>,
    /// Outbound message queue (to groove consumers).
    outbound: VecDeque<serde_json::Value>,
}

impl GrooveState {
    pub fn new() -> Self {
        Self {
            inbound: VecDeque::new(),
            outbound: VecDeque::new(),
        }
    }

    /// Push a message from a groove consumer.
    ///
    /// When the queue is full the oldest message is dropped to make room.
    /// NOTE: Per-client rate limiting should be added upstream (reverse proxy
    /// or future middleware) to prevent a single consumer from flooding the
    /// queue and causing legitimate messages to be evicted.
    pub fn push_inbound(&mut self, msg: serde_json::Value) {
        if self.inbound.len() >= MAX_QUEUE_DEPTH {
            warn!(
                "Groove inbound queue full ({} messages) — dropping oldest message",
                MAX_QUEUE_DEPTH
            );
            self.inbound.pop_front();
        }
        self.inbound.push_back(msg);
    }

    /// Drain all outbound messages for groove consumers.
    pub fn drain_outbound(&mut self) -> Vec<serde_json::Value> {
        self.outbound.drain(..).collect()
    }

    /// Enqueue a message to send to groove consumers.
    pub fn push_outbound(&mut self, msg: serde_json::Value) {
        if self.outbound.len() >= MAX_QUEUE_DEPTH {
            warn!(
                "Groove outbound queue full ({} messages) — dropping oldest message",
                MAX_QUEUE_DEPTH
            );
            self.outbound.pop_front();
        }
        self.outbound.push_back(msg);
    }
}

/// Run the groove discovery HTTP server on port 6480.
///
/// This is a minimal HTTP server that handles only the groove protocol
/// endpoints. It runs alongside the main Vext notification listener.
pub async fn run(state: Arc<Mutex<GrooveState>>) -> anyhow::Result<()> {
    let addr: SocketAddr = "127.0.0.1:6480".parse()?;
    let listener = TcpListener::bind(addr).await?;
    info!("Groove endpoint listening on {}", addr);

    loop {
        match listener.accept().await {
            Ok((mut stream, peer)) => {
                debug!("Groove connection from {}", peer);
                let state = state.clone();
                tokio::spawn(async move {
                    if let Err(e) = handle_groove_request(&mut stream, state).await {
                        warn!("Groove request error from {}: {}", peer, e);
                    }
                });
            }
            Err(e) => {
                error!("Groove accept error: {}", e);
            }
        }
    }
}

/// Handle a single groove HTTP request.
async fn handle_groove_request(
    stream: &mut tokio::net::TcpStream,
    state: Arc<Mutex<GrooveState>>,
) -> anyhow::Result<()> {
    // Read the HTTP request (up to MAX_REQUEST_SIZE).
    let mut buf = vec![0u8; MAX_REQUEST_SIZE];
    let n = stream.read(&mut buf).await?;
    let request = std::str::from_utf8(&buf[..n])?;

    // Parse the request line.
    let first_line = request.lines().next().unwrap_or("");
    let parts: Vec<&str> = first_line.split_whitespace().collect();
    if parts.len() < 2 {
        send_response(stream, 400, "Bad Request").await?;
        return Ok(());
    }

    let method = parts[0];
    let path = parts[1];

    match (method, path) {
        // GET /.well-known/groove — Return the capability manifest.
        ("GET", "/.well-known/groove") => {
            send_json_response(stream, 200, MANIFEST).await?;
        }

        // POST /.well-known/groove/message — Receive a message from a consumer.
        ("POST", "/.well-known/groove/message") => {
            // Extract body (after \r\n\r\n).
            if let Some(sep) = request.find("\r\n\r\n") {
                let body = &request[sep + 4..];

                // Validate body size against MAX_REQUEST_SIZE to prevent
                // oversized payloads from consuming memory or being processed.
                if body.len() > MAX_REQUEST_SIZE {
                    warn!(
                        "Groove POST body too large: {} bytes (max {})",
                        body.len(),
                        MAX_REQUEST_SIZE
                    );
                    send_json_response(
                        stream,
                        413,
                        r#"{"ok":false,"error":"payload too large"}"#,
                    )
                    .await?;
                    return Ok(());
                }

                match serde_json::from_str(body) {
                    Ok(msg) => {
                        let mut guard = state.lock().await;
                        guard.push_inbound(msg);
                        send_json_response(stream, 200, r#"{"ok":true}"#).await?;
                    }
                    Err(_) => {
                        send_json_response(
                            stream,
                            400,
                            r#"{"ok":false,"error":"invalid JSON"}"#,
                        )
                        .await?;
                    }
                }
            } else {
                send_json_response(stream, 400, r#"{"ok":false,"error":"no body"}"#).await?;
            }
        }

        // GET /.well-known/groove/recv — Drain pending outbound messages.
        ("GET", "/.well-known/groove/recv") => {
            let mut guard = state.lock().await;
            let messages = guard.drain_outbound();
            let json = serde_json::to_string(&messages)?;
            send_json_response(stream, 200, &json).await?;
        }

        // GET /health — Simple health check.
        ("GET", "/health") => {
            send_json_response(stream, 200, r#"{"status":"ok","service":"vext"}"#).await?;
        }

        // Unknown route.
        _ => {
            send_response(stream, 404, "Not Found").await?;
        }
    }

    Ok(())
}

/// Send an HTTP response with a text body.
async fn send_response(
    stream: &mut tokio::net::TcpStream,
    status: u16,
    body: &str,
) -> anyhow::Result<()> {
    let response = format!(
        "HTTP/1.0 {} {}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        status,
        status_text(status),
        body.len(),
        body
    );
    stream.write_all(response.as_bytes()).await?;
    Ok(())
}

/// Send an HTTP response with a JSON body.
async fn send_json_response(
    stream: &mut tokio::net::TcpStream,
    status: u16,
    json: &str,
) -> anyhow::Result<()> {
    let response = format!(
        "HTTP/1.0 {} {}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        status,
        status_text(status),
        json.len(),
        json
    );
    stream.write_all(response.as_bytes()).await?;
    Ok(())
}

/// HTTP status code to text.
fn status_text(status: u16) -> &'static str {
    match status {
        200 => "OK",
        400 => "Bad Request",
        404 => "Not Found",
        413 => "Payload Too Large",
        500 => "Internal Server Error",
        _ => "Unknown",
    }
}
