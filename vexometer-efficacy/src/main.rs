// SPDX-License-Identifier: MPL-2.0
//! CLI for the vexometer efficacy protocol tooling.
//!
//! Subcommands:
//!   report    Evaluate baseline vs after and emit a vexometer-efficacy-v2 JSON report
//!   attempt   Evaluate one configuration and append it to a vexometer-frontier-v1 record
//!   lift      Mechanically lift a v1 efficacy report to the v2.1 shape (ruling e2)
//!   validate  Check stored efficacy/frontier documents against the protocol's rules

use std::collections::BTreeMap;
use std::fs;
use std::process::ExitCode;

use vexometer_efficacy::{
    build_report, check_scenario_registry, evaluate, lift_v1, validate_efficacy, validate_frontier,
    FrontierRecord, Measurement, ReportMeta, EFFICACY_VERSION, FRONTIER_VERSION,
};

const USAGE: &str = "\
vexometer-efficacy — ISA efficacy protocol tooling

USAGE:
  vexometer-efficacy report --baseline FILE --after FILE --targets M1[,M2...]
      --satellite NAME --sample-size N [--scenario-set SHA] [--date YYYY-MM-DD]
      [--methodology STR] [--notes STR] [--frontier-records PATH]...
      [--traces-available true|false] --output FILE

  vexometer-efficacy attempt --baseline FILE --after FILE --targets M1[,M2...]
      --metric M --satellite NAME --config STR --frontier FILE
      [--model-profile STR] [--timestamp ISO8601] [--scenario-set SHA]

  vexometer-efficacy lift --input FILE --output FILE
      (vexometer-efficacy-v1 in, lifted v2 report out, verdict unverified;
      ruling e2)

  vexometer-efficacy validate FILE... [--efficacy FILE]... [--frontier FILE]...
      [--scenario-registry FILE]
      (bare FILEs are routed by their \"version\" field; the flags force a kind)

Measurement FILEs hold all ten ISA metric scores plus the probe result; see
vexometer-efficacy/README.adoc for the format. Pass --frontier-records once
per target metric, in target order (ruling d1). Exit codes: 0 success (any
verdict), 1 usage or data error, 3 validation failed.
";

struct Args {
    values: BTreeMap<String, Vec<String>>,
    positional: Vec<String>,
}

impl Args {
    fn parse(argv: &[String]) -> Result<Args, String> {
        let mut values: BTreeMap<String, Vec<String>> = BTreeMap::new();
        let mut positional = Vec::new();
        let mut i = 0;
        while i < argv.len() {
            match argv[i].strip_prefix("--") {
                Some(key) => {
                    let val = argv
                        .get(i + 1)
                        .ok_or_else(|| format!("--{key} requires a value"))?;
                    values.entry(key.to_string()).or_default().push(val.clone());
                    i += 2;
                }
                None => {
                    positional.push(argv[i].clone());
                    i += 1;
                }
            }
        }
        Ok(Args { values, positional })
    }

    fn no_positional(&self, cmd: &str) -> Result<(), String> {
        match self.positional.first() {
            None => Ok(()),
            Some(arg) => Err(format!("{cmd} takes no positional arguments, got {arg:?}")),
        }
    }

    fn one(&self, key: &str) -> Result<&str, String> {
        match self.values.get(key).map(|v| v.as_slice()) {
            Some([v]) => Ok(v),
            Some(_) => Err(format!("--{key} given more than once")),
            None => Err(format!("--{key} is required")),
        }
    }

    fn opt(&self, key: &str) -> Result<Option<&str>, String> {
        match self.values.get(key).map(|v| v.as_slice()) {
            Some([v]) => Ok(Some(v)),
            Some(_) => Err(format!("--{key} given more than once")),
            None => Ok(None),
        }
    }

    fn many(&self, key: &str) -> Vec<String> {
        self.values.get(key).cloned().unwrap_or_default()
    }
}

fn read_measurement(path: &str) -> Result<Measurement, String> {
    let text = fs::read_to_string(path).map_err(|e| format!("cannot read {path}: {e}"))?;
    serde_json::from_str(&text).map_err(|e| format!("{path} is not a valid measurement: {e}"))
}

fn read_json(path: &str) -> Result<serde_json::Value, String> {
    let text = fs::read_to_string(path).map_err(|e| format!("cannot read {path}: {e}"))?;
    serde_json::from_str(&text).map_err(|e| format!("{path} is not valid JSON: {e}"))
}

fn write_json<T: serde::Serialize>(path: &str, value: &T) -> Result<(), String> {
    let mut text =
        serde_json::to_string_pretty(value).map_err(|e| format!("cannot serialise: {e}"))?;
    text.push('\n');
    fs::write(path, text).map_err(|e| format!("cannot write {path}: {e}"))
}

fn scenario_set_for(args: &Args, measurement: &Measurement) -> Result<String, String> {
    if let Some(s) = args.opt("scenario-set")? {
        return Ok(s.to_string());
    }
    measurement
        .scenario_set
        .clone()
        .ok_or_else(|| "no --scenario-set and none in the measurement file".to_string())
}

fn cmd_report(args: &Args) -> Result<ExitCode, String> {
    args.no_positional("report")?;
    let baseline = read_measurement(args.one("baseline")?)?;
    let after = read_measurement(args.one("after")?)?;
    let targets: Vec<String> = args
        .one("targets")?
        .split(',')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();
    let sample_size: u64 = args
        .one("sample-size")?
        .parse()
        .map_err(|_| "--sample-size must be a non-negative integer".to_string())?;
    let traces_available = match args.opt("traces-available")? {
        None => true,
        Some("true") => true,
        Some("false") => false,
        Some(other) => {
            return Err(format!(
                "--traces-available must be true or false, got {other}"
            ))
        }
    };

    let eval = evaluate(&baseline, &after, &targets).map_err(|e| e.to_string())?;

    if args.opt("frontier-record")?.is_some() {
        return Err(
            "--frontier-record was renamed --frontier-records: pass it once per \
             target metric, in target order (ruling d1)"
                .to_string(),
        );
    }
    let frontier_records = args.many("frontier-records");
    let meta = ReportMeta {
        satellite: args.one("satellite")?.to_string(),
        evaluation_date: args.opt("date")?.map(str::to_string).unwrap_or_else(today),
        sample_size,
        scenario_set: scenario_set_for(args, &baseline)?,
        methodology: args
            .opt("methodology")?
            .unwrap_or("A/B testing with vexometer validation")
            .to_string(),
        traces_available,
        verdict_notes: args.opt("notes")?.map(str::to_string),
        frontier_records: if frontier_records.is_empty() {
            None
        } else {
            Some(frontier_records)
        },
    };

    let (report, warnings) = build_report(&eval, &meta).map_err(|e| e.to_string())?;
    for w in &warnings {
        eprintln!("warning: {w}");
    }
    write_json(args.one("output")?, &report)?;
    println!(
        "verdict: {}  isa_delta: {}  ({} written)",
        report.verdict.as_str(),
        report.isa_delta,
        args.one("output")?
    );
    Ok(ExitCode::SUCCESS)
}

fn cmd_attempt(args: &Args) -> Result<ExitCode, String> {
    args.no_positional("attempt")?;
    let baseline = read_measurement(args.one("baseline")?)?;
    let after = read_measurement(args.one("after")?)?;
    let targets: Vec<String> = args
        .one("targets")?
        .split(',')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();
    let metric = args.one("metric")?;
    if !targets.iter().any(|t| t == metric) {
        return Err(format!("--metric {metric} must be one of --targets"));
    }
    let frontier_path = args.one("frontier")?;
    let scenario_set = scenario_set_for(args, &baseline)?;

    let eval = evaluate(&baseline, &after, &targets).map_err(|e| e.to_string())?;

    let mut record = if fs::metadata(frontier_path).is_ok() {
        let doc = read_json(frontier_path)?;
        serde_json::from_value(doc)
            .map_err(|e| format!("{frontier_path} is not a frontier record: {e}"))?
    } else {
        FrontierRecord::new(
            metric,
            args.opt("model-profile")?.unwrap_or("unspecified"),
            args.opt("timestamp")?
                .map(str::to_string)
                .unwrap_or_else(now_utc)
                .as_str(),
            &scenario_set,
            baseline.metrics[metric].score(),
            f64::NAN, // baseline ISA score: not derivable from one measurement pair
            baseline.probes.pass_rate(),
        )
    };

    // The baseline ISA *score* (not delta) needs the full scoring pipeline;
    // accept it as an explicit flag when creating a record.
    if let Some(isa) = args.opt("baseline-isa")? {
        let v: f64 = isa
            .parse()
            .map_err(|_| "--baseline-isa must be a number".to_string())?;
        record.baseline.insert("isa_score".to_string(), v);
    }
    if record
        .baseline
        .get("isa_score")
        .map(|v| v.is_nan())
        .unwrap_or(true)
    {
        return Err("--baseline-isa is required when creating a new frontier record".to_string());
    }

    let attempt = record
        .append(
            args.one("satellite")?,
            args.one("config")?,
            &eval,
            &scenario_set,
        )
        .map_err(|e| e.to_string())?;
    println!(
        "attempt {}: verdict {} gap_closed {} frontier {}",
        attempt.index,
        attempt.verdict.as_str(),
        attempt.gap_closed,
        attempt.frontier
    );
    write_json(frontier_path, &record)?;
    Ok(ExitCode::SUCCESS)
}

fn cmd_lift(args: &Args) -> Result<ExitCode, String> {
    args.no_positional("lift")?;
    let input = args.one("input")?;
    let doc = read_json(input)?;
    let lifted = lift_v1(&doc).map_err(|e| e.to_string())?;
    let output = args.one("output")?;
    write_json(output, &lifted)?;
    println!("lifted {input} -> {output} (verdict unverified; ruling e2)");
    Ok(ExitCode::SUCCESS)
}

fn cmd_validate(args: &Args) -> Result<ExitCode, String> {
    let efficacy = args.many("efficacy");
    let frontier = args.many("frontier");
    if efficacy.is_empty() && frontier.is_empty() && args.positional.is_empty() {
        return Err("validate needs at least one file to check".to_string());
    }
    let registry = match args.opt("scenario-registry")? {
        Some(path) => Some(read_json(path)?),
        None => None,
    };
    let mut failed = false;
    for path in &args.positional {
        // A bare path is routed by the document's own version discriminant,
        // so mixed report/frontier lists need no flags.
        let doc = read_json(path)?;
        match doc.get("version").and_then(|v| v.as_str()) {
            Some(v) if v == EFFICACY_VERSION => {
                let mut problems = validate_efficacy(&doc);
                problems.extend(registry_problems(registry.as_ref(), &doc));
                report_problems(path, EFFICACY_VERSION, &problems, &mut failed);
            }
            Some(v) if v == FRONTIER_VERSION => {
                let mut problems = validate_frontier(&doc);
                problems.extend(registry_problems(registry.as_ref(), &doc));
                report_problems(path, FRONTIER_VERSION, &problems, &mut failed);
            }
            Some(other) => {
                return Err(format!(
                    "{path}: unknown version {other:?} (expected {EFFICACY_VERSION} or {FRONTIER_VERSION})"
                ));
            }
            None => {
                return Err(format!(
                    "{path}: no \"version\" field; use --efficacy or --frontier to force a kind"
                ));
            }
        }
    }
    for path in &efficacy {
        let doc = read_json(path)?;
        let mut problems = validate_efficacy(&doc);
        problems.extend(registry_problems(registry.as_ref(), &doc));
        report_problems(path, "vexometer-efficacy-v2", &problems, &mut failed);
    }
    for path in &frontier {
        let doc = read_json(path)?;
        let mut problems = validate_frontier(&doc);
        problems.extend(registry_problems(registry.as_ref(), &doc));
        report_problems(path, "vexometer-frontier-v1", &problems, &mut failed);
    }
    Ok(if failed {
        ExitCode::from(3)
    } else {
        ExitCode::SUCCESS
    })
}

/// Check every scenario-set hash a document scores against the held-out
/// registry (ruling f1). Efficacy reports carry one top-level hash; frontier
/// records carry one per attempt as well.
fn registry_problems(registry: Option<&serde_json::Value>, doc: &serde_json::Value) -> Vec<String> {
    let Some(registry) = registry else {
        return Vec::new();
    };
    let mut sets: Vec<&str> = Vec::new();
    if let Some(s) = doc.get("scenario_set").and_then(|v| v.as_str()) {
        sets.push(s);
    }
    if let Some(attempts) = doc.get("attempts").and_then(|v| v.as_array()) {
        sets.extend(
            attempts
                .iter()
                .filter_map(|a| a.get("scenario_set").and_then(|v| v.as_str())),
        );
    }
    sets.sort_unstable();
    sets.dedup();
    sets.iter()
        .flat_map(|s| check_scenario_registry(registry, s))
        .collect()
}

fn report_problems(path: &str, kind: &str, problems: &[String], failed: &mut bool) {
    if problems.is_empty() {
        println!("{path}: valid {kind}");
    } else {
        *failed = true;
        println!("{path}: INVALID {kind}");
        for p in problems {
            println!("  - {p}");
        }
    }
}

fn today() -> String {
    // UTC date without a clock dependency: civil-from-days on the Unix epoch.
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let days = (secs / 86_400) as i64;
    let (y, m, d) = civil_from_days(days);
    format!("{y:04}-{m:02}-{d:02}")
}

fn now_utc() -> String {
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let days = (secs / 86_400) as i64;
    let rem = secs % 86_400;
    let (y, m, d) = civil_from_days(days);
    format!(
        "{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z",
        rem / 3600,
        (rem % 3600) / 60,
        rem % 60
    )
}

/// Howard Hinnant's civil-from-days algorithm (public domain).
fn civil_from_days(z: i64) -> (i64, u32, u32) {
    let z = z + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = (z - era * 146_097) as u64;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (if m <= 2 { y + 1 } else { y }, m, d)
}

fn main() -> ExitCode {
    let argv: Vec<String> = std::env::args().skip(1).collect();
    let (cmd, rest) = match argv.split_first() {
        Some((c, r)) => (c.as_str(), r),
        None => {
            eprint!("{USAGE}");
            return ExitCode::from(1);
        }
    };
    let run = || -> Result<ExitCode, String> {
        let args = Args::parse(rest)?;
        match cmd {
            "report" => cmd_report(&args),
            "attempt" => cmd_attempt(&args),
            "lift" => cmd_lift(&args),
            "validate" => cmd_validate(&args),
            "--help" | "-h" | "help" => {
                print!("{USAGE}");
                Ok(ExitCode::SUCCESS)
            }
            other => Err(format!("unknown subcommand {other}")),
        }
    };
    match run() {
        Ok(code) => code,
        Err(msg) => {
            eprintln!("error: {msg}");
            eprintln!("run vexometer-efficacy --help for usage");
            ExitCode::from(1)
        }
    }
}
