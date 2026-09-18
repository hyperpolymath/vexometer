// SPDX-License-Identifier: MPL-2.0
//! CLI for vex-verbosity-compressor.
//!
//! `analyse FILE`  — print a JSON analysis (findings + LPS proxy) to stdout.
//! `compress FILE` — print the compressed text to stdout (`--report` prints
//!                   a JSON report instead). `-` reads stdin.
//!
//! Exit codes: 0 success, 1 usage or I/O error.

use std::io::Read;
use std::process::ExitCode;

use vex_verbosity_compressor::{analyse, compress};

const USAGE: &str = "usage: vex-verbosity-compressor <analyse|compress> <FILE|-> [--report]
  analyse   print JSON findings and the LPS proxy score
  compress  print the compressed text (--report: JSON report instead)
  --version print the version";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.iter().any(|a| a == "--version") {
        println!("vex-verbosity-compressor {}", env!("CARGO_PKG_VERSION"));
        return ExitCode::SUCCESS;
    }
    let (command, path, report_flag) = match args.as_slice() {
        [c, p] => (c.as_str(), p.as_str(), false),
        [c, p, flag] if flag == "--report" => (c.as_str(), p.as_str(), true),
        _ => {
            eprintln!("{USAGE}");
            return ExitCode::FAILURE;
        }
    };

    let text = match read_input(path) {
        Ok(t) => t,
        Err(e) => {
            eprintln!("vex-verbosity-compressor: cannot read {path}: {e}");
            return ExitCode::FAILURE;
        }
    };

    match command {
        "analyse" | "analyze" => {
            let analysis = analyse(&text);
            println!(
                "{}",
                serde_json::to_string_pretty(&analysis).expect("analysis serializes")
            );
            ExitCode::SUCCESS
        }
        "compress" => {
            let result = compress(&text);
            if report_flag {
                println!(
                    "{}",
                    serde_json::to_string_pretty(&result).expect("report serializes")
                );
            } else {
                println!("{}", result.output);
            }
            ExitCode::SUCCESS
        }
        _ => {
            eprintln!("{USAGE}");
            ExitCode::FAILURE
        }
    }
}

fn read_input(path: &str) -> std::io::Result<String> {
    if path == "-" {
        let mut buf = String::new();
        std::io::stdin().read_to_string(&mut buf)?;
        Ok(buf)
    } else {
        std::fs::read_to_string(path)
    }
}
