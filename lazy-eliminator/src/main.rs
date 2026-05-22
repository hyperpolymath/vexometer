// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

use clap::{Parser, Subcommand};
use std::path::PathBuf;
use vex_lazy_eliminator::{Analyzer, Language, TraceReport, VexometerTrace};

#[derive(Parser)]
#[command(name = "vex-lazy-eliminator")]
#[command(about = "Completeness enforcement for LLM-generated code", long_about = None)]
#[command(version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Check code for incompleteness patterns
    Check {
        /// File or directory to check
        path: PathBuf,

        /// Language (auto-detected from extension if not specified)
        #[arg(short, long)]
        language: Option<String>,

        /// Fail on any incompleteness (exit code 1)
        #[arg(short, long)]
        strict: bool,

        /// Output format: text, json
        #[arg(short, long, default_value = "text")]
        output: String,
    },

    /// Generate vexometer trace from before/after samples
    Trace {
        /// Before code file
        #[arg(long)]
        before: PathBuf,

        /// After code file
        #[arg(long)]
        after: PathBuf,

        /// Output trace JSON file
        #[arg(short, long)]
        output: PathBuf,

        /// Scenario description
        #[arg(short, long)]
        description: String,

        /// Original prompt
        #[arg(short, long)]
        prompt: String,

        /// Language
        #[arg(short, long)]
        language: Option<String>,
    },
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Check {
            path,
            language,
            strict,
            output,
        } => {
            let lang = if let Some(lang_str) = language {
                lang_str.parse::<Language>()?
            } else {
                let ext = path
                    .extension()
                    .and_then(|s| s.to_str())
                    .ok_or_else(|| anyhow::anyhow!("Cannot determine file extension"))?;
                Language::from_extension(ext)?
            };

            let code = std::fs::read_to_string(&path)?;
            let analyzer = Analyzer::new(lang);
            let (detections, summary) = analyzer.analyze_with_summary(&code)?;

            match output.as_str() {
                "json" => {
                    let json = serde_json::to_string_pretty(&detections)?;
                    println!("{}", json);
                }
                "text" | _ => {
                    if detections.is_empty() {
                        println!("✓ No incompleteness detected (CII: 0.0)");
                    } else {
                        println!("Found {} incompleteness patterns:", detections.len());
                        println!();
                        for detection in &detections {
                            println!(
                                "  {} at line {}, column {} (severity: {:.2})",
                                detection.kind, detection.line, detection.column, detection.severity
                            );
                            println!("    {}", detection.snippet);
                            println!();
                        }
                        println!("Summary:");
                        println!("  Critical: {}", summary.critical);
                        println!("  High Priority: {}", summary.high_priority);
                        println!("  CII: {:.3}", summary.cii);
                    }
                }
            }

            if strict && !detections.is_empty() {
                std::process::exit(1);
            }
        }

        Commands::Trace {
            before,
            after,
            output,
            description,
            prompt,
            language,
        } => {
            let lang = if let Some(lang_str) = language {
                lang_str.parse::<Language>()?
            } else {
                let ext = before
                    .extension()
                    .and_then(|s| s.to_str())
                    .ok_or_else(|| anyhow::anyhow!("Cannot determine file extension"))?;
                Language::from_extension(ext)?
            };

            let before_code = std::fs::read_to_string(&before)?;
            let after_code = std::fs::read_to_string(&after)?;

            let analyzer = Analyzer::new(lang);
            let before_cii = analyzer.calculate_cii(&before_code)?;
            let after_cii = analyzer.calculate_cii(&after_code)?;

            let trace = VexometerTrace::new(
                description,
                prompt,
                before_code,
                before_cii,
                after_code,
                after_cii,
            );

            trace.save(&output)?;

            let report = TraceReport::new(trace);
            println!("Trace saved to: {}", output.display());
            println!("{}", report.summary);
        }
    }

    Ok(())
}
