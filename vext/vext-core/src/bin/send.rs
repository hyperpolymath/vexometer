// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//! vext-send - CLI tool for sending notifications to vextd
//!
//! Sends JSON notifications to a running vextd daemon.

use std::io::Write;
use std::net::TcpStream;

use anyhow::Result;
use clap::Parser;
use serde_json::json;

/// Send notifications to vextd
#[derive(Parser, Debug)]
#[command(name = "vext-send")]
#[command(author, version, about)]
struct Args {
    /// Target IRC URL (e.g., irc://server/channel or ircs://server/channel)
    #[arg(short, long)]
    to: Vec<String>,

    /// Message to send
    #[arg(short, long)]
    message: String,

    /// Project name
    #[arg(short, long)]
    project: Option<String>,

    /// Branch name
    #[arg(short, long)]
    branch: Option<String>,

    /// Commit hash
    #[arg(short, long)]
    commit: Option<String>,

    /// Author name
    #[arg(short, long)]
    author: Option<String>,

    /// URL for more info
    #[arg(short, long)]
    url: Option<String>,

    /// vextd server address
    #[arg(long, default_value = "127.0.0.1:6659")]
    server: String,

    /// Use UDP instead of TCP
    #[arg(long)]
    udp: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();

    if args.to.is_empty() {
        eprintln!("Error: at least one --to target is required");
        std::process::exit(1);
    }

    let mut notification = json!({
        "to": args.to,
        "privmsg": args.message,
    });

    if let Some(project) = args.project {
        notification["project"] = json!(project);
    }
    if let Some(branch) = args.branch {
        notification["branch"] = json!(branch);
    }
    if let Some(commit) = args.commit {
        notification["commit"] = json!(commit);
    }
    if let Some(author) = args.author {
        notification["author"] = json!(author);
    }
    if let Some(url) = args.url {
        notification["url"] = json!(url);
    }

    let payload = serde_json::to_string(&notification)?;

    if args.udp {
        use std::net::UdpSocket;
        let socket = UdpSocket::bind("0.0.0.0:0")?;
        socket.send_to(payload.as_bytes(), &args.server)?;
        println!("Sent notification via UDP to {}", args.server);
    } else {
        let mut stream = TcpStream::connect(&args.server)?;
        writeln!(stream, "{}", payload)?;
        stream.flush()?;
        println!("Sent notification via TCP to {}", args.server);
    }

    Ok(())
}
