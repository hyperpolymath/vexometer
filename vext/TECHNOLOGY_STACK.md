# vext Technology Stack

## Overview

vext uses a hybrid architecture combining Rust for the high-performance daemon and Deno/TypeScript for developer-friendly hooks and tooling.

## Languages & Runtimes

### Rust (vext-core)

**Role**: High-performance IRC notification daemon

- **Version**: Rust 1.70+ (2021 edition)
- **Runtime**: Native binary (no runtime dependencies)
- **Build Tool**: Cargo

**Key Advantages**:
- Memory safety without garbage collection
- Zero-cost abstractions
- Excellent async/await support via Tokio
- Single binary deployment
- Cross-compilation support

### TypeScript/Deno (vext-tools)

**Role**: Hook scripts, CLI utilities, configuration tools

- **Runtime**: Deno 1.40+
- **Type Safety**: Full TypeScript with strict mode
- **Permissions**: Explicit security permissions model

**Key Advantages**:
- Modern JavaScript/TypeScript runtime
- Built-in TypeScript support (no transpilation step)
- Secure by default (explicit permissions)
- Single-file scripts with URL imports
- Excellent cross-platform support

## Core Dependencies

### Rust Dependencies (vext-core)

| Crate | Version | Purpose |
|-------|---------|---------|
| `tokio` | 1.35 | Async runtime and I/O |
| `irc` | 0.15 | IRC protocol implementation |
| `serde` | 1.0 | Serialization/deserialization |
| `serde_json` | 1.0 | JSON parsing |
| `toml` | 0.8 | TOML configuration files |
| `clap` | 4.4 | Command-line argument parsing |
| `tracing` | 0.1 | Structured logging |
| `native-tls` | 0.2 | TLS support |
| `trust-dns-resolver` | 0.23 | DNS resolution (SRV records) |
| `thiserror` | 1.0 | Error type derivation |
| `anyhow` | 1.0 | Error handling |

### Deno Dependencies (vext-tools)

| Module | Source | Purpose |
|--------|--------|---------|
| `@std/path` | JSR | Path manipulation |
| `@std/fs` | JSR | File system operations |
| `@std/cli` | JSR | CLI argument parsing |

## Architecture

### vext-core (Rust Daemon)

```
┌─────────────────────────────────────────────────────────┐
│                       vextd                             │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Listener  │  │   Config    │  │   Logging   │     │
│  │  (TCP/UDP)  │  │   (TOML)    │  │  (tracing)  │     │
│  └──────┬──────┘  └─────────────┘  └─────────────┘     │
│         │                                               │
│         ▼                                               │
│  ┌─────────────────────────────────────────────┐       │
│  │            Connection Pool                   │       │
│  │  ┌───────┐  ┌───────┐  ┌───────┐           │       │
│  │  │ IRC 1 │  │ IRC 2 │  │ IRC 3 │  ...      │       │
│  │  └───────┘  └───────┘  └───────┘           │       │
│  └─────────────────────────────────────────────┘       │
│                                                         │
│  ┌─────────────────────────────────────────────┐       │
│  │            Rate Limiter                      │       │
│  │     Token Bucket Algorithm (per-server)      │       │
│  └─────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────┘
```

### vext-tools (Deno Hooks)

```
┌─────────────────────────────────────────────────────────┐
│                    Git Repository                        │
├─────────────────────────────────────────────────────────┤
│  .git/hooks/post-receive                                │
│       │                                                  │
│       ▼                                                  │
│  ┌─────────────────────────────────────────────┐       │
│  │            vext Git Hook (Deno)              │       │
│  │  ┌───────────┐  ┌───────────┐               │       │
│  │  │ Parse Refs│  │ Get Commit│               │       │
│  │  │ from stdin│  │  Metadata │               │       │
│  │  └─────┬─────┘  └─────┬─────┘               │       │
│  │        └──────┬───────┘                      │       │
│  │               ▼                              │       │
│  │  ┌─────────────────────────────────┐        │       │
│  │  │   Format JSON Notification      │        │       │
│  │  └─────────────┬───────────────────┘        │       │
│  │                │                             │       │
│  └────────────────┼─────────────────────────────┘       │
│                   │ TCP                                  │
└───────────────────┼─────────────────────────────────────┘
                    ▼
              vextd daemon
```

## Communication Protocol

### JSON Notification Format

```json
{
  "to": ["ircs://server/channel"],
  "privmsg": "Message text",
  "project": "project-name",
  "branch": "main",
  "commit": "abc1234",
  "author": "developer",
  "url": "https://example.com/commit/abc1234",
  "colors": "mirc"
}
```

### IRC URL Schema

| URL Format | Description |
|------------|-------------|
| `irc://server/channel` | Plain IRC (port 6667) |
| `ircs://server/channel` | TLS IRC (port 6697) |
| `irc://server:port/channel` | Custom port |
| `irc://server/channel?key=pass` | Channel with key |

## Build System

### Cargo (Rust)

```toml
[workspace]
members = ["vext-core"]
resolver = "2"

[profile.release]
lto = true
codegen-units = 1
panic = "abort"
strip = true
```

### Deno (TypeScript)

```json
{
  "tasks": {
    "build": "deno check src/**/*.ts",
    "test": "deno test --allow-read --allow-write --allow-net",
    "hook:git": "deno run --allow-net --allow-env --allow-read src/hooks/git.ts"
  }
}
```

### Just (Task Runner)

Common tasks via [just](https://github.com/casey/just):

```bash
just build      # Build all components
just test       # Run all tests
just lint       # Run linters
just format     # Format code
just validate   # Full CI check
```

## Security Considerations

### Rust (vext-core)

- Memory-safe by design
- No unsafe code in critical paths
- TLS enabled by default
- Rate limiting prevents flood attacks
- Sandboxed IRC commands (no arbitrary execution)

### Deno (vext-tools)

- Explicit permission model
- Only `--allow-net`, `--allow-read`, `--allow-env` required
- No arbitrary file system access
- URL imports verified by integrity checks

## Platform Support

| Platform | vext-core | vext-tools |
|----------|-----------|------------|
| Linux x86_64 | Full | Full |
| Linux ARM64 | Full | Full |
| macOS x86_64 | Full | Full |
| macOS ARM64 | Full | Full |
| Windows | Partial | Full |
| FreeBSD | Full | Partial |

## Performance Characteristics

### vext-core Daemon

- **Memory**: ~5-10 MB base, ~1 MB per active connection
- **CPU**: Minimal (async I/O, event-driven)
- **Throughput**: 10,000+ notifications/second
- **Latency**: <10ms notification to IRC send

### Connection Pool

- **Max Connections**: Configurable (default: 4 per server)
- **Idle Timeout**: 5 minutes (configurable)
- **Reconnection**: Automatic with exponential backoff

## Development Dependencies

### Rust

```bash
# Testing
cargo install cargo-tarpaulin  # Coverage
cargo install cargo-audit      # Security audit

# Linting
rustup component add clippy
rustup component add rustfmt
```

### Deno

Built-in tooling:
- `deno fmt` - Code formatting
- `deno lint` - Linting
- `deno test` - Testing
- `deno check` - Type checking

## Migration from Python

This project was migrated from Python to Rust + Deno for:

1. **Performance**: Rust's async I/O handles more connections with less memory
2. **Safety**: Memory safety and type safety reduce runtime errors
3. **Deployment**: Single binary simplifies installation
4. **Modern Tooling**: Deno provides better developer experience for scripting
5. **Policy Compliance**: RSR (Rhodium Standard Repository) language requirements

See `.migration/PYTHON_TO_RUST_RESCRIPT.md` for migration details.

## License

- **SPDX Identifier**: `MPL-2.0`
- **Style**: Palimpsest dual licensing
