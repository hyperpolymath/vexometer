// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//! vextd - IRC notification daemon for version control systems
//!
//! A high-performance, async IRC daemon that receives JSON notifications
//! and relays them to configured IRC channels with connection pooling.

mod config;
mod error;
mod irc_client;
mod listener;
mod pool;
mod protocol;

use std::net::SocketAddr;
use std::sync::Arc;

use anyhow::Result;
use clap::Parser;
use tokio::sync::RwLock;
use tracing::{info, Level};
use tracing_subscriber::FmtSubscriber;

use crate::config::Config;
use crate::pool::ConnectionPool;

/// vextd - IRC notification daemon
#[derive(Parser, Debug)]
#[command(name = "vextd")]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Listen address for notifications
    #[arg(short, long, default_value = "127.0.0.1:6659")]
    listen: SocketAddr,

    /// Configuration file path
    #[arg(short, long)]
    config: Option<std::path::PathBuf>,

    /// Enable verbose logging
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,

    /// Run in foreground (don't daemonize)
    #[arg(short = 'n', long)]
    foreground: bool,

    /// Default IRC server (if not specified in notification)
    #[arg(long, default_value = "irc.libera.chat")]
    default_server: String,

    /// Default IRC port
    #[arg(long, default_value = "6697")]
    default_port: u16,

    /// Use TLS for IRC connections
    #[arg(long, default_value = "true")]
    tls: bool,

    /// Maximum connections per server
    #[arg(long, default_value = "4")]
    max_connections: usize,

    /// Nick prefix for the bot
    #[arg(long, default_value = "vext")]
    nick: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    // Initialize logging
    let log_level = match args.verbose {
        0 => Level::INFO,
        1 => Level::DEBUG,
        _ => Level::TRACE,
    };

    let subscriber = FmtSubscriber::builder()
        .with_max_level(log_level)
        .with_target(false)
        .with_thread_ids(true)
        .with_file(true)
        .with_line_number(true)
        .finish();

    tracing::subscriber::set_global_default(subscriber)?;

    info!("vextd {} starting", env!("CARGO_PKG_VERSION"));

    // Load configuration
    let config = if let Some(config_path) = args.config {
        Config::from_file(&config_path)?
    } else {
        Config::new(
            args.default_server,
            args.default_port,
            args.tls,
            args.max_connections,
            args.nick,
        )
    };

    info!("Loaded configuration: {:?}", config);

    // Initialize connection pool
    let pool = Arc::new(RwLock::new(ConnectionPool::new(config.clone())));

    // Start the notification listener
    info!("Starting notification listener on {}", args.listen);
    listener::run(args.listen, pool).await?;

    Ok(())
}
