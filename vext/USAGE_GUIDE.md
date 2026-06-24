<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# vext Usage Guide

## Quick Start

### 1. Start the Daemon

```bash
# Start vext daemon with default settings
irkerd

# Or run in foreground with debug output
irkerd --foreground --debug

# Or run as background service
sudo systemctl start vext
sudo systemctl status vext
```

### 2. Send Your First Notification

```bash
# Send notification to IRC channel
echo '{"to":"irc://irc.libera.chat/testchannel","privmsg":"Hello from vext!"}' | \
  nc -u 127.0.0.1 6659
```

### 3. Configure Repository Hook

For Git:
```bash
# Copy example hook to repository
cp irkerhook.py /path/to/repo.git/hooks/post-receive
chmod +x /path/to/repo.git/hooks/post-receive

# Edit to set IRC channel
# Then make a commit to test!
```

## Starting and Managing the Daemon

### Command-Line Options

```bash
# Show help
irkerd --help
irkerd -h

# Display version
irkerd --version

# Run in foreground (don't daemonize)
irkerd --foreground

# Set custom port
irkerd --port 6660

# Set custom bind address
irkerd --listen 0.0.0.0

# Enable debug logging
irkerd --debug

# Specify config file
irkerd --config /etc/vext/vext.conf

# Custom PID file location
irkerd --pidfile /var/run/vext.pid

# Set log file
irkerd --logfile /var/log/vext/vext.log

# Combine options
irkerd --listen 0.0.0.0 --port 6659 --debug --foreground
```

### Systemd Service Management

```bash
# Start daemon
sudo systemctl start vext

# Stop daemon
sudo systemctl stop vext

# Restart daemon
sudo systemctl restart vext

# Reload configuration (if supported)
sudo systemctl reload vext

# Check status
sudo systemctl status vext

# Enable autostart on boot
sudo systemctl enable vext

# Disable autostart
sudo systemctl disable vext

# View service logs
sudo journalctl -u vext -f              # Follow logs
sudo journalctl -u vext -n 50           # Last 50 lines
sudo journalctl -u vext -S "1 hour ago" # Last hour
```

### Manual Service Management

```bash
# Start in background (manual)
irkerd --pidfile /var/run/vext.pid --logfile /var/log/vext/vext.log &

# Stop (using PID file)
kill $(cat /var/run/vext.pid)

# Force stop
pkill -f irkerd

# Check if running
pgrep -f irkerd
ps aux | grep irkerd
```

## Sending Notifications

### Basic Notification

```bash
# Simple message to single channel
echo '{"to":"irc://irc.libera.chat/commits","privmsg":"New commit pushed!"}' | \
  nc -u localhost 6659
```

### Multi-Channel Notification

```bash
# Send to multiple channels in one request
echo '{
  "to": [
    "irc://irc.libera.chat/commits",
    "irc://irc.libera.chat/announcements"
  ],
  "privmsg": "Major release v1.2.0 published!"
}' | nc -u localhost 6659
```

### With Color Formatting

```bash
# ANSI color codes
echo '{
  "to": "irc://irc.libera.chat/commits",
  "privmsg": "[abc123d] Alice: Fix critical bug",
  "color": "ANSI"
}' | nc -u localhost 6659

# mIRC color codes
echo '{
  "to": "irc://irc.libera.chat/commits",
  "privmsg": "[abc123d] Alice: Fix critical bug",
  "color": "mIRC"
}' | nc -u localhost 6659
```

### Custom Bot Nickname

```bash
# Override default bot nick
echo '{
  "to": "irc://irc.libera.chat/commits",
  "privmsg": "Notification message",
  "nick": "my-custom-bot"
}' | nc -u localhost 6659
```

### Using Python Script

```python
#!/usr/bin/env python3
import json
import socket

def send_notification(host, port, to_channel, message):
    """Send notification to vext daemon."""
    notification = {
        "to": to_channel,
        "privmsg": message,
        "color": "ANSI"
    }

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(
        json.dumps(notification).encode('utf-8'),
        (host, port)
    )
    sock.close()

# Usage
send_notification(
    "localhost",
    6659,
    "irc://irc.libera.chat/mychannel",
    "[commit] Alice: Implement new feature"
)

print("Notification sent!")
```

### Using TCP Instead of UDP

```bash
# TCP is more reliable but slightly slower
echo '{"to":"irc://irc.libera.chat/commits","privmsg":"Important message"}' | \
  nc localhost 6659  # nc without -u uses TCP
```

### Using Bash Script

```bash
#!/bin/bash

# Configuration
VEXT_HOST="localhost"
VEXT_PORT="6659"
IRC_SERVER="irc.libera.chat"
IRC_CHANNEL="mychannel"

# Function to send notification
send_irc_notification() {
    local message=$1
    local channel=${2:-$IRC_CHANNEL}

    local json_payload=$(cat <<EOF
{
    "to": "irc://${IRC_SERVER}/${channel}",
    "privmsg": "${message}",
    "color": "ANSI"
}
EOF
)

    echo "$json_payload" | nc -u "$VEXT_HOST" "$VEXT_PORT"
}

# Usage examples
send_irc_notification "Build started for commit abc123d"
send_irc_notification "Build completed successfully" "announcements"
send_irc_notification "Deployment to production failed" "alerts"
```

## Repository Hook Configuration

### Git Configuration

#### Basic Git Hook

```python
#!/usr/bin/env python3
"""
Git post-receive hook for vext notifications
Save as: /path/to/repo.git/hooks/post-receive
"""

import sys
import json
import socket
from subprocess import check_output, CalledProcessError

# Configuration
VEXT_HOST = "localhost"
VEXT_PORT = 6659
VEXT_CHANNEL = "#myproject-commits"
VEXT_SERVER = "irc.libera.chat"

def send_notification(message):
    """Send notification to vext daemon."""
    notification = {
        "to": f"irc://{VEXT_SERVER}/{VEXT_CHANNEL}",
        "privmsg": message,
        "color": "ANSI"
    }

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto(
            json.dumps(notification).encode('utf-8'),
            (VEXT_HOST, VEXT_PORT)
        )
        sock.close()
    except Exception as e:
        print(f"Error sending notification: {e}", file=sys.stderr)

def get_commit_info(commit_hash):
    """Extract commit information."""
    try:
        subject = check_output(
            ["git", "log", "--format=%s", "-n1", commit_hash],
            text=True
        ).strip()

        author = check_output(
            ["git", "log", "--format=%an", "-n1", commit_hash],
            text=True
        ).strip()

        return author, subject
    except CalledProcessError as e:
        print(f"Git error: {e}", file=sys.stderr)
        return None, None

# Main hook logic
while True:
    line = sys.stdin.readline()
    if not line:
        break

    try:
        old_rev, new_rev, ref = line.split()

        # Determine commits to process
        if old_rev == "0" * 40:
            # New branch - all commits
            commits = check_output(
                ["git", "rev-list", new_rev],
                text=True
            ).strip().split('\n')
            branch = "new branch"
        else:
            # Regular push
            commits = check_output(
                ["git", "rev-list", f"{old_rev}..{new_rev}"],
                text=True
            ).strip().split('\n')
            branch = ref.split('/')[-1]

        # Send notification for each commit
        for commit in commits:
            if commit:
                author, subject = get_commit_info(commit)
                if author and subject:
                    msg = f"[{commit[:7]}] {author}: {subject}"
                    send_notification(msg)

    except CalledProcessError as e:
        print(f"Error processing push: {e}", file=sys.stderr)

print("Git hook executed successfully")
```

#### Advanced Git Hook with Environment Configuration

```python
#!/usr/bin/env python3
"""
Advanced Git hook with configuration file support
"""

import sys
import os
import json
import socket
from subprocess import check_output, CalledProcessError
from pathlib import Path

class GitHookConfig:
    def __init__(self):
        # Load from environment variables first
        self.vext_host = os.getenv("VEXT_HOST", "localhost")
        self.vext_port = int(os.getenv("VEXT_PORT", "6659"))
        self.irc_server = os.getenv("IRC_SERVER", "irc.libera.chat")
        self.irc_channel = os.getenv("IRC_CHANNEL", "#commits")
        self.color_mode = os.getenv("IRC_COLOR", "ANSI")
        self.max_message_length = int(os.getenv("MAX_MESSAGE_LENGTH", "512"))

        # Try to load from .vext.conf file in repo
        config_file = Path(".vext.conf")
        if config_file.exists():
            self.load_config_file(config_file)

    def load_config_file(self, config_file):
        """Load configuration from file."""
        try:
            import configparser
            config = configparser.ConfigParser()
            config.read(config_file)

            if "irc" in config:
                self.irc_server = config["irc"].get("server", self.irc_server)
                self.irc_channel = config["irc"].get("channel", self.irc_channel)

            if "vext" in config:
                self.vext_host = config["vext"].get("host", self.vext_host)
                self.vext_port = int(config["vext"].get("port", self.vext_port))
        except Exception as e:
            print(f"Warning: Could not load config file: {e}", file=sys.stderr)

config = GitHookConfig()

def send_notification(message):
    """Send notification to vext daemon."""
    # Truncate if necessary
    if len(message) > config.max_message_length:
        message = message[:config.max_message_length - 3] + "..."

    notification = {
        "to": f"irc://{config.irc_server}/{config.irc_channel}",
        "privmsg": message,
        "color": config.color_mode
    }

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto(
            json.dumps(notification).encode('utf-8'),
            (config.vext_host, config.vext_port)
        )
        sock.close()
    except Exception as e:
        print(f"Error sending notification: {e}", file=sys.stderr)

# Process commits...
# (same as basic example)
```

### Mercurial Configuration

```python
#!/usr/bin/env python3
"""
Mercurial hook for vext notifications
Add to .hg/hgrc:

[hooks]
commit.irker = python:/path/to/hg-irker-hook.py:notify
"""

import os
import sys
import json
import socket

def notify(ui, repo, **kwargs):
    """Mercurial hook function."""
    # Configuration
    vext_host = ui.config("irker", "host") or "localhost"
    vext_port = int(ui.config("irker", "port") or "6659")
    irc_channel = ui.config("irker", "channel") or "#commits"

    changeset = kwargs.get("node")
    ctx = repo[changeset]

    # Format message
    message = f"[{changeset[:7]}] {ctx.user()}: {ctx.description()}"

    # Send notification
    notification = {
        "to": f"irc://irc.libera.chat/{irc_channel}",
        "privmsg": message
    }

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto(
            json.dumps(notification).encode('utf-8'),
            (vext_host, vext_port)
        )
        sock.close()
    except Exception as e:
        ui.write(f"Error sending notification: {e}\n")
```

### Subversion Configuration

```bash
#!/bin/bash
# SVN post-commit hook
# Save as: /path/to/repo/hooks/post-commit

REPOS="$1"
REV="$2"

# Configuration
VEXT_HOST="localhost"
VEXT_PORT="6659"
IRC_CHANNEL="commits"
IRC_SERVER="irc.libera.chat"

# Get commit information
AUTHOR=$(svnlook author -r $REV $REPOS)
LOG=$(svnlook log -r $REV $REPOS)
FILES=$(svnlook changed -r $REV $REPOS | wc -l)

# Format message
MESSAGE="[r$REV] $AUTHOR: $LOG (Files: $FILES)"

# Send notification
PAYLOAD=$(cat <<EOF
{
    "to": "irc://${IRC_SERVER}/${IRC_CHANNEL}",
    "privmsg": "${MESSAGE}",
    "color": "ANSI"
}
EOF
)

echo "$PAYLOAD" | nc -u "$VEXT_HOST" "$VEXT_PORT"

exit 0
```

## Configuration Management

### Environment Variables

```bash
# Set in shell or systemd service
export IRKERD_HOST=0.0.0.0
export IRKERD_PORT=6659
export IRKERD_NICK=vext-bot
export IRKERD_COLOR_MODE=ANSI
export IRKERD_USE_TCP=false
export IRKERD_LOGLEVEL=INFO
export IRKERD_LOGFILE=/var/log/vext/vext.log
```

### Configuration File (.vext.conf)

```ini
[daemon]
host = 0.0.0.0
port = 6659
threads = 4
user = irker
group = irker

[irc]
nick = vext-notify
realname = vext Notification System
timeout = 120

[features]
color_mode = ANSI
rate_limit = 2
flood_limit = 1000
```

### Per-Repository Configuration (.vext-repo.conf)

```ini
[vext]
host = localhost
port = 6659

[irc]
server = irc.libera.chat
channel = #myproject
color = ANSI
```

## Monitoring and Troubleshooting

### Check Daemon Status

```bash
# Is daemon running?
ps aux | grep irkerd
pgrep -f irkerd

# Is it listening on the right port?
netstat -tlnp | grep 6659
ss -tlnp | grep 6659

# Recent activity in logs?
tail -f /var/log/vext/vext.log
journalctl -u vext -f
```

### Test IRC Connectivity

```bash
# Can you reach the IRC server?
ping irc.libera.chat
telnet irc.libera.chat 6667

# Check with nc
echo -n "" | nc -w 5 irc.libera.chat 6667
```

### Debug Hook Execution

```bash
# Test hook manually
cd /path/to/repo.git
python3 hooks/post-receive <<< "0000000000000000000000000000000000000000 abc123 refs/heads/main"

# Run with debug output
python3 -u hooks/post-receive 2>&1 | tee hook-debug.log

# Check hook permissions
ls -la hooks/post-receive
# Should be: -rwxr-xr-x (755)
```

### Common Issues and Solutions

**Issue: Notifications not appearing in IRC**
```bash
# 1. Check daemon is running
systemctl status vext

# 2. Check logs
journalctl -u vext -n 50

# 3. Test connectivity
echo '{"to":"irc://irc.libera.chat/testchannel","privmsg":"test"}' | \
  nc -u localhost 6659

# 4. Check firewall
sudo ufw status
```

**Issue: Hook script not executing**
```bash
# 1. Check permissions
ls -la /path/to/repo.git/hooks/post-receive
# Should be executable (x)

# 2. Test hook directly
/path/to/repo.git/hooks/post-receive

# 3. Check shebang line
head -1 /path/to/repo.git/hooks/post-receive
# Should be: #!/usr/bin/env python3

# 4. Check git config
cat /path/to/repo.git/config
```

**Issue: Connection refused**
```bash
# 1. Check daemon port
sudo ss -tlnp | grep 6659

# 2. Try different port
IRKERD_PORT=6660 irkerd --foreground

# 3. Check firewall
sudo ufw allow 6659
```

## Advanced Usage

### Rotating Logs

```bash
# Manual rotation
sudo systemctl stop vext
sudo mv /var/log/vext/vext.log /var/log/vext/vext.log.1
sudo systemctl start vext

# Or use logrotate (automatic)
cat > /etc/logrotate.d/vext << 'EOF'
/var/log/vext/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 irker irker
}
EOF
```

### High-Availability Setup

```bash
# Primary daemon
irkerd --listen 0.0.0.0 --port 6659 &

# Secondary daemon (standby)
irkerd --listen 0.0.0.0 --port 6660 &

# Hook sends to both
echo '{"to":"irc://irc.libera.chat/commits","privmsg":"msg"}' | \
  nc -u localhost 6659 &
echo '{"to":"irc://irc.libera.chat/commits","privmsg":"msg"}' | \
  nc -u localhost 6660
```

### Rate Limiting and Batching

```bash
# Configure rate limits to prevent IRC flooding
IRKERD_RATE_LIMIT=2         # 2 messages per second
IRKERD_FLOOD_LIMIT=1000     # 1000 messages per minute

irkerd --foreground --debug
```

## Performance Tuning

### Memory Optimization

```bash
# Monitor daemon memory usage
watch -n 1 'ps aux | grep irkerd | grep -v grep'

# Limit memory usage (if needed)
# Use cgroups or systemd unit configuration
```

### Connection Pooling

```bash
# Daemon automatically pools IRC connections
# Configure thread pool size in config:
[daemon]
threads = 4  # Adjust based on number of channels
```

## Conclusion

vext provides flexible, powerful IRC notifications for your repositories. Start with the basic examples and expand based on your specific needs. For more information, see [README.md](README.md) and [FEATURES.md](FEATURES.md).

