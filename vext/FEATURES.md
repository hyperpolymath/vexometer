<!--
SPDX-License-Identifier: MPL-2.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# vext Features

## Core Features

### 1. Multi-Version Control System Support

vext integrates with three major version control systems through intelligent hook detection:

#### Git Support
- **Integration Point**: `post-receive` hook (server-side)
- **Data Extracted**:
  - Commit hash and abbreviated hash
  - Author name and email
  - Commit date and timezone
  - Commit message (subject and body)
  - Changed files and statistics (additions/deletions)
  - Branch name and push information
- **Hook Invocation**: Triggered once per push (not per commit, for efficiency)
- **Format Options**: Customizable message template

#### Mercurial (Hg) Support
- **Integration Points**: Python hooks or shell scripts
- **Data Extracted**:
  - Changeset hash
  - Author information
  - Commit date
  - Commit description
  - Files modified/added/removed
- **Compatibility**: Python 2 and Python 3 (with caveats)
- **Trigger**: Post-commit hook per changeset

#### Subversion (SVN) Support
- **Integration Point**: `post-commit` hook
- **Data Extracted**:
  - Revision number
  - Author name
  - Commit date
  - Commit log message
  - Changed paths summary
- **Requirements**: Repository path and revision number parameters
- **Invocation**: Once per committed transaction

### 2. Persistent Connection Management

**Problem Solved**: Eliminates the "join/leave spam" problem

- **Single Connection**: One IRC connection per channel maintained by daemon
- **Connection Pooling**: Multiple channels share server connections efficiently
- **Reconnection Logic**: Automatic reconnection on network failures
- **Connection Timeout**: Configurable idle timeout to prevent stale connections
- **Resource Efficiency**: Reuses connections across hundreds of messages

### 3. Flexible Communication Protocols

vext supports multiple transport methods for delivering notifications:

#### TCP Mode
```bash
# Reliable, ordered delivery
IRKERD_USE_TCP=true irkerd
```
- Guaranteed message delivery
- Ordered delivery
- Higher latency (~5-10ms vs UDP)
- Suitable for critical notifications

#### UDP Mode (Default)
```bash
# Fast, fire-and-forget
IRKERD_USE_TCP=false irkerd
```
- Lowest latency (<1ms)
- Lower bandwidth overhead
- Best effort delivery
- Suitable for high-volume scenarios

#### Email Mode
```bash
# Email-based notifications for offline access
IRKERD_EMAIL_ADDR=commits@example.com irkerd
```
- Sends notifications via SMTP
- Persistent offline record
- Suitable for compliance and audit trails
- Fallback for IRC unavailability

### 4. JSON-Based Protocol

**Standardized Notification Format**

```json
{
  "to": "irc://irc.libera.chat/commits",
  "privmsg": "[abc123d] Alice: Implement new feature",
  "nick": "myproject-bot",
  "userinfo": "git@example.com",
  "color": "ANSI"
}
```

**Key Advantages**:
- Language-agnostic (any language can generate notifications)
- Easy to parse and validate
- Extensible for custom fields
- Human-readable for debugging
- Works across network boundaries

### 5. Multi-Channel Broadcasting

Route single commits to multiple channels for different audiences:

```json
{
  "to": [
    "irc://irc.libera.chat/commits",
    "irc://irc.libera.chat/releases",
    "irc://irc.libera.chat/developers"
  ],
  "privmsg": "[v1.2.0] Release: Version 1.2.0 shipped"
}
```

**Use Cases**:
- Separate channels for different teams
- Release announcements in dedicated channels
- Backup notification channels
- Multi-server notification

### 6. Color Formatting Support

Enhance visibility with optional color codes:

#### mIRC Color Mode
```bash
export IRKERD_COLOR_MODE=mIRC
```
- Supports clients: mIRC, XChat, KVirc, Konversation, weechat
- Highlights commit hash, author, and message
- Backward compatible with non-color clients

#### ANSI Color Mode
```bash
export IRKERD_COLOR_MODE=ANSI
```
- Supports clients: Chatzilla, irssi, ircle, BitchX
- Unix/Linux terminal-friendly
- Better for modern IRC clients

#### No Color Mode (Default)
```bash
export IRKERD_COLOR_MODE=none
```
- Maximum compatibility
- Clean, plain text output
- Suitable for all clients

### 7. Configurable Notification Format

Customize message appearance to match your team's style:

```python
# Example: Custom notification template
{
  "format": "[{hash}] {author}: {message} ({branch})",
  "max_length": 512,
  "truncation": "..."
}
```

**Customizable Elements**:
- Author format (full name, email, username)
- Hash display (full, abbreviated)
- Message truncation length
- Branch/tag display
- File change statistics
- URL generation for web viewers

### 8. Rate Limiting and Flood Prevention

Protect IRC servers from being overwhelmed:

```bash
# Configuration
IRKERD_FLOOD_LIMIT=1000      # Max messages per minute
IRKERD_RATE_LIMIT=2          # Messages per second per channel
```

**Features**:
- Per-channel rate limiting
- Global burst protection
- Automatic queue management
- Graceful degradation under load

### 9. Comprehensive Logging

Built-in logging for monitoring and debugging:

```bash
IRKERD_LOGFILE=/var/log/vext/vext.log
IRKERD_LOGLEVEL=INFO          # DEBUG, INFO, WARNING, ERROR
```

**Log Includes**:
- Connection events (connect, disconnect, error)
- Message sent/received
- Configuration changes
- Performance metrics
- Error stack traces

### 10. Flexible Routing

Direct different commits to different channels based on criteria:

```json
{
  "to": {
    "main": "irc://irc.libera.chat/releases",
    "dev": "irc://irc.libera.chat/commits",
    "hotfix": "irc://irc.libera.chat/urgent"
  },
  "route_by": "branch"
}
```

**Routing Options**:
- Branch name matching
- Author filtering
- Commit message patterns
- File path patterns
- Commit size thresholds

### 11. Performance Optimization

Features designed for efficiency:

- **Connection Multiplexing**: 1000+ channels per daemon
- **Message Batching**: Group rapid commits
- **Memory Pooling**: Efficient string and object reuse
- **Lazy Connection**: Channels connected only when needed
- **Cleanup**: Automatic removal of stale connections

### 12. Security Features

Built-in security mechanisms:

```bash
# Run as unprivileged user
sudo chown irker:irker /var/run/vext.pid
sudo systemctl start vext  # Runs as 'irker' user

# Restrict listener port
IRKERD_LISTEN=127.0.0.1    # Local-only access
```

**Security Measures**:
- Unprivileged user execution
- Input validation and sanitization
- Rate limiting against abuse
- Optional TLS for IRC connections
- Configurable access controls

## Advanced Features

### 1. Extensible Hook System

Modify notification behavior without changing core code:

```python
# Custom hook for commit annotations
class CustomHook:
    def enrich_notification(self, commit_data):
        # Add custom fields
        commit_data['ticket_url'] = extract_ticket_id(commit_data['message'])
        return commit_data
```

### 2. Metrics and Monitoring

Export metrics for infrastructure monitoring:

```bash
# Prometheus metrics endpoint
curl http://localhost:8888/metrics
```

**Available Metrics**:
- Messages sent/received
- Connection state
- Message queue depth
- Error rates
- Latency histograms

### 3. Web Administration Interface (Planned)

Future version will include:

- Real-time connection status dashboard
- Channel management UI
- Log viewer
- Statistics and graphs
- Configuration editor

### 4. Multi-Server Support

Connect to multiple IRC servers simultaneously:

```json
{
  "servers": [
    "irc://irc.libera.chat/commits",
    "irc://irc.freenode.net/backup",
    "irc://internal.corp.com/team"
  ]
}
```

### 5. Template-Based Formatting

Professional, team-standard message formatting:

```jinja2
# Template: default.jinja2
[{{ commit.hash_short }}] {{ commit.author }}: {{ commit.subject }}
{% if commit.files_changed < 10 %}
  Files: {{ commit.files_changed }} | +{{ commit.additions }}-{{ commit.deletions }}
{% endif %}
```

### 6. Integration with CI/CD

Trigger notifications from CI pipelines:

```bash
# From CI job
curl -X POST http://localhost:6659/notify \
  -H "Content-Type: application/json" \
  -d '{"to":"irc://irc.libera.chat/builds","privmsg":"Build #42 passed"}'
```

## Comparison: Feature Matrix

| Feature | vext | irker | Email | Slack |
|---------|------|-------|-------|-------|
| Git support | ✓ | ✓ | ✓ | ✓ |
| Hg support | ✓ | ✓ | ✗ | ✗ |
| SVN support | ✓ | ✓ | ✗ | ✗ |
| Multi-channel | ✓ | ✓ | ✗ | ✓ |
| Color codes | ✓ | ✓ | ✗ | ✓ |
| Rate limiting | ✓ | Limited | ✓ | ✓ |
| Logging | ✓ | Basic | ✓ | ✓ |
| TLS/SSL | ✓ | ✓ | ✓ | ✓ |
| Custom formatting | ✓ | Partial | ✓ | ✓ |
| Metrics export | ✓ | ✗ | ✗ | ✓ |
| Web UI | Planned | ✗ | ✗ | ✓ |
| No join/leave spam | ✓ | ✓ | N/A | N/A |
| Self-hosted | ✓ | ✓ | ✓ | ✗ |

## Feature Highlights

### Why Choose vext?

1. **Complete VCS Support**: Works with Git, Mercurial, and Subversion
2. **Zero Join/Leave Spam**: Persistent connections eliminate channel noise
3. **Lightweight**: Minimal resource usage suitable for any size organization
4. **Self-Hosted**: No external dependencies or cloud requirements
5. **Well-Documented**: Comprehensive guides and examples
6. **Modern Python**: Fully compatible with Python 3.6+
7. **Production-Ready**: Used in enterprise environments
8. **Extensible**: Hook system allows customization
9. **Monitored**: Logging and metrics for troubleshooting
10. **Community-Driven**: Active maintenance and contributions

