<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# vext Installation Guide

## Prerequisites

### System Requirements

- **Operating System**: Linux (Ubuntu, Debian, CentOS), macOS, or FreeBSD
- **Python**: Version 2.7+ or 3.4+ (3.6+ recommended)
- **Version Control Tools**: Git, Mercurial (optional), or Subversion (optional)
- **Network**: Outbound TCP/UDP access to IRC server
- **User Privileges**: Ability to create system users and install to `/usr/local` or `/opt`

### Required Tools

```bash
# Check Python installation
python --version        # Should show 2.7+ or 3.4+
python3 --version       # For Python 3

# Check Git installation (minimum requirement)
git --version

# Optional: Check other VCS tools
hg --version            # For Mercurial support
svn --version           # For Subversion support
```

### Network Requirements

- **Outbound**: TCP/UDP port 6667-6697 (IRC servers, 6697 is typically TLS)
- **Inbound**: TCP/UDP port 6659 (daemon listener, configurable)
- **DNS**: Access to IRC server DNS records
- **Firewall**: Allow bidirectional traffic with IRC servers

## Installation Methods

### Method 1: From Source (Recommended for Development)

#### Step 1: Clone Repository

```bash
# Clone the vext repository
git clone https://github.com/Hyperpolymath/vext.git
cd vext
git checkout main  # or latest stable branch
```

#### Step 2: Create Virtual Environment (Optional but Recommended)

```bash
# Create isolated Python environment
python3 -m venv venv
source venv/bin/activate  # On macOS/Linux
# or
venv\Scripts\activate     # On Windows

# Upgrade pip
pip install --upgrade pip setuptools wheel
```

#### Step 3: Install Dependencies

```bash
# Install package and dependencies
pip install -e .

# Or with development dependencies
pip install -e ".[dev,test]"
```

#### Step 4: Verify Installation

```bash
# Check daemon installation
irkerd --help

# Check hook installation
python -m irker.irkerhook --help

# Test import
python -c "import irker; print(irker.__version__)"
```

#### Step 5: Create System User (Recommended)

```bash
# Create unprivileged user for daemon
sudo useradd -r -s /bin/false -d /var/empty irker

# Or on macOS
sudo dscl . -create /Users/irker UserShell /usr/bin/false
sudo dscl . -create /Users/irker RealName "IRC Notification Daemon"
```

#### Step 6: Install as System Service

```bash
# Copy systemd service file
sudo cp systemd/vext.service /etc/systemd/system/

# Or create custom service file
sudo tee /etc/systemd/system/vext.service > /dev/null <<'EOF'
[Unit]
Description=vext IRC Notification Daemon
After=network.target

[Service]
Type=simple
User=irker
Group=irker
ExecStart=/usr/local/bin/irkerd
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable vext
sudo systemctl start vext
sudo systemctl status vext
```

### Method 2: Package Manager Installation

#### Ubuntu/Debian

```bash
# Update package list
sudo apt-get update

# Install from distribution (if available)
sudo apt-get install irker

# Or build from source
sudo apt-get install python3-dev git
git clone https://github.com/Hyperpolymath/vext.git
cd vext
sudo python3 setup.py install
```

#### CentOS/RHEL

```bash
# Install dependencies
sudo yum install python36-devel git

# Clone and install
git clone https://github.com/Hyperpolymath/vext.git
cd vext
sudo python36 setup.py install
```

#### macOS (Homebrew)

```bash
# If formula is available
brew install vext

# Or from source
brew install python3
git clone https://github.com/Hyperpolymath/vext.git
cd vext
pip3 install -e .
```

### Method 3: Docker Container Deployment

#### Create Dockerfile

```dockerfile
FROM python:3.9-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    mercurial \
    subversion \
    && rm -rf /var/lib/apt/lists/*

# Create irker user
RUN useradd -r -s /bin/false irker

# Install vext
RUN git clone https://github.com/Hyperpolymath/vext.git /opt/vext
WORKDIR /opt/vext
RUN pip install -e .

# Switch to unprivileged user
USER irker

# Expose daemon port
EXPOSE 6659

# Run daemon
CMD ["irkerd", "--listen", "0.0.0.0", "--port", "6659"]
```

#### Build and Run

```bash
# Build image
docker build -t vext:latest .

# Run container
docker run -d \
  --name vext-daemon \
  -p 6659:6659/tcp \
  -p 6659:6659/udp \
  -v /etc/vext:/etc/vext:ro \
  vext:latest

# Check logs
docker logs -f vext-daemon

# Stop container
docker stop vext-daemon
```

### Method 4: System-Wide Installation (Manual)

#### Step 1: Create Installation Directory

```bash
# Create install directory
sudo mkdir -p /opt/vext/{bin,lib,etc}
sudo chown root:root /opt/vext
```

#### Step 2: Copy Files

```bash
# Copy daemon and scripts
sudo cp irkerd /opt/vext/bin/
sudo cp irkerhook.py /opt/vext/bin/
sudo cp -r irker/ /opt/vext/lib/

# Copy configuration
sudo cp etc/vext.conf /opt/vext/etc/
sudo chmod 640 /opt/vext/etc/vext.conf
sudo chown root:irker /opt/vext/etc/vext.conf
```

#### Step 3: Create Symlinks

```bash
# Link executables to standard locations
sudo ln -s /opt/vext/bin/irkerd /usr/local/bin/irkerd
sudo ln -s /opt/vext/bin/irkerhook.py /usr/local/bin/irkerhook
```

## Post-Installation Configuration

### 1. Create Configuration File

```bash
# Create vext configuration directory
sudo mkdir -p /etc/vext
sudo chown root:root /etc/vext
sudo chmod 755 /etc/vext

# Create main configuration
sudo tee /etc/vext/vext.conf > /dev/null <<'EOF'
[daemon]
# Bind address and port
listen = 0.0.0.0
port = 6659
# Run as user
user = irker
group = irker
# Logging
logfile = /var/log/vext/vext.log
loglevel = INFO
pidfile = /var/run/vext.pid

[irc]
# Bot nickname
nick = vext-notify
# Real name (GECOS field)
realname = vext Notification System
# Connection timeout (seconds)
timeout = 120

[features]
# Color mode: ANSI, mIRC, none
color_mode = ANSI
# Rate limiting (messages per minute)
rate_limit = 2
# Flood threshold (messages per second)
flood_limit = 1000
EOF

sudo chmod 640 /etc/vext/vext.conf
```

### 2. Create Log Directory

```bash
# Create log directory
sudo mkdir -p /var/log/vext
sudo chown irker:irker /var/log/vext
sudo chmod 755 /var/log/vext

# Setup log rotation
sudo tee /etc/logrotate.d/vext > /dev/null <<'EOF'
/var/log/vext/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 irker irker
    sharedscripts
    postrotate
        systemctl reload vext > /dev/null 2>&1 || true
    endscript
}
EOF
```

### 3. Configure Environment Variables

```bash
# Create environment file
sudo tee /etc/default/vext > /dev/null <<'EOF'
# vext daemon environment configuration
IRKERD_HOST=0.0.0.0
IRKERD_PORT=6659
IRKERD_NICK=vext-notify
IRKERD_COLOR_MODE=ANSI
IRKERD_LOGLEVEL=INFO
EOF

# Update systemd service to use environment file
sudo tee /etc/systemd/system/vext.service.d/environment.conf > /dev/null <<'EOF'
[Service]
EnvironmentFile=/etc/default/vext
ExecStart=
ExecStart=/usr/local/bin/irkerd --listen $IRKERD_HOST --port $IRKERD_PORT
EOF

sudo systemctl daemon-reload
```

## Repository-Specific Setup

### Git Repository Hook Installation

#### Method 1: Server-Side Post-Receive Hook

```bash
# Navigate to bare repository
cd /path/to/myproject.git

# Create post-receive hook
cat > hooks/post-receive << 'EOFHOOK'
#!/usr/bin/env python3
# IRC notification hook for git

import sys
import json
import socket
from subprocess import check_output, CalledProcessError

def send_notification(server, port, channel, message):
    """Send JSON notification to vext daemon."""
    notification = {
        "to": f"irc://{server}/{channel}",
        "privmsg": message
    }

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto(
            json.dumps(notification).encode('utf-8'),
            (server, int(port))
        )
        sock.close()
    except Exception as e:
        sys.stderr.write(f"Error sending notification: {e}\n")

# Configuration (can be customized per repository)
VEXT_HOST = "localhost"
VEXT_PORT = "6659"
IRC_CHANNEL = "#myproject-commits"
IRC_SERVER = "irc.libera.chat"

# Process input
while True:
    line = sys.stdin.readline()
    if not line:
        break

    try:
        old_rev, new_rev, ref = line.split()

        # Get commit info
        if old_rev == "0" * 40:
            # New branch
            commits = check_output(
                ["git", "rev-list", new_rev],
                text=True
            ).strip().split('\n')
        else:
            # Regular push
            commits = check_output(
                ["git", "rev-list", f"{old_rev}..{new_rev}"],
                text=True
            ).strip().split('\n')

        # Send notification for each commit
        for commit in commits:
            if not commit:
                continue

            subject = check_output(
                ["git", "log", "--format=%s", "-n1", commit],
                text=True
            ).strip()

            author = check_output(
                ["git", "log", "--format=%an", "-n1", commit],
                text=True
            ).strip()

            message = f"[{commit[:7]}] {author}: {subject}"
            send_notification(VEXT_HOST, VEXT_PORT, IRC_CHANNEL,
                            f"irc://{IRC_SERVER}/{IRC_CHANNEL}",
                            message)

    except CalledProcessError as e:
        sys.stderr.write(f"Git error: {e}\n")
        continue

EOFHOOK

# Make executable
chmod +x hooks/post-receive

# Verify
ls -la hooks/post-receive
```

#### Method 2: Using irkerhook.py

```bash
# Copy irkerhook.py to repository
cp /usr/local/bin/irkerhook /path/to/myproject.git/hooks/

# Make executable
chmod +x /path/to/myproject.git/hooks/irkerhook

# Test the hook
cd /path/to/myproject.git
python hooks/irkerhook --help
```

### Mercurial Repository Hook Installation

```bash
# Add to .hg/hgrc
cat >> /path/to/myrepo/.hg/hgrc << 'EOF'
[hooks]
# Python hook (preferred)
commit.irker = python:/usr/local/bin/irkerhook.py:notify

# Or as external command
# commit.irker = /usr/local/bin/irkerhook --repository $HG_NODE
EOF

# Verify
hg logs
```

### Subversion Repository Hook Installation

```bash
# Create hook script
cat > /path/to/svnrepo/hooks/post-commit << 'EOF'
#!/bin/bash

REPOS="$1"
REV="$2"

# Call irkerhook
/usr/local/bin/irkerhook --repository "$REPOS" $REV

exit 0
EOF

# Make executable
chmod +x /path/to/svnrepo/hooks/post-commit

# Verify permissions
ls -la /path/to/svnrepo/hooks/post-commit
```

## Testing Installation

### 1. Verify Daemon Installation

```bash
# Check daemon is executable
which irkerd
irkerd --version
irkerd --help

# Test daemon start/stop
irkerd --foreground --debug &
DAEMON_PID=$!
sleep 2
kill $DAEMON_PID
```

### 2. Test Daemon Connectivity

```bash
# Start daemon
irkerd --listen 127.0.0.1 --port 6659 --foreground &

# In another terminal, send test notification
echo '{"to":"irc://irc.libera.chat/test","privmsg":"Hello from vext"}' | \
  nc -u 127.0.0.1 6659

# Or with TCP
echo '{"to":"irc://irc.libera.chat/test","privmsg":"Hello from vext"}' | \
  nc 127.0.0.1 6659
```

### 3. Test Hook Execution

```bash
# Create test commit in Git repo
cd /tmp
mkdir test-repo
cd test-repo
git init
git config user.name "Test User"
git config user.email "test@example.com"

# Create hook
cat > .git/hooks/post-receive << 'EOF'
#!/bin/bash
echo "Hook triggered!" >&2
EOF

chmod +x .git/hooks/post-receive

# Make a test commit
echo "test" > testfile.txt
git add testfile.txt
git commit -m "Test commit"
```

### 4. System Service Testing

```bash
# Check service status
sudo systemctl status vext

# View service logs
sudo journalctl -u vext -f

# Test service restart
sudo systemctl restart vext
sudo systemctl status vext

# Check daemon is listening
sudo netstat -tlnp | grep 6659
# or
sudo ss -tlnp | grep 6659
```

### 5. End-to-End Testing

```bash
# 1. Start daemon
sudo systemctl start vext

# 2. Send test notification
python3 << 'EOTEST'
import json
import socket

notification = {
    "to": "irc://irc.libera.chat/testchannel",
    "privmsg": "Test notification from vext"
}

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(
    json.dumps(notification).encode(),
    ("localhost", 6659)
)
sock.close()

print("Notification sent!")
EOTEST

# 3. Check daemon logs
sudo journalctl -u vext -n 20
```

## Troubleshooting Installation

### Issue: Python Version Mismatch

```bash
# Solution: Use explicit Python version
python3 setup.py install
# or specify shebang in hook scripts
#!/usr/bin/env python3
```

### Issue: Permission Denied Errors

```bash
# Solution: Fix file permissions
sudo chown -R irker:irker /var/log/vext
sudo chmod 755 /var/log/vext
sudo chmod 644 /var/log/vext/*.log
```

### Issue: Port Already in Use

```bash
# Find process using port 6659
sudo lsof -i :6659
# or
sudo ss -tlnp | grep 6659

# Change daemon port in systemd service
sudo systemctl edit vext
# Add: Environment="IRKERD_PORT=6660"
```

### Issue: Cannot Connect to IRC Server

```bash
# Test network connectivity
ping irc.libera.chat
telnet irc.libera.chat 6667

# Check firewall rules
sudo iptables -L -n | grep 6667
sudo ufw status

# Enable outbound IRC ports
sudo ufw allow out 6667,6697/tcp
```

### Issue: Daemon Not Starting

```bash
# Check for syntax errors
python3 -m py_compile /usr/local/bin/irkerd

# Run daemon in foreground to see errors
irkerd --foreground --debug

# Check systemd logs
sudo journalctl -u vext -n 50
```

## Uninstallation

```bash
# Stop service
sudo systemctl stop vext
sudo systemctl disable vext

# Remove service file
sudo rm /etc/systemd/system/vext.service

# Remove installed files
sudo rm /usr/local/bin/irkerd
sudo rm /usr/local/bin/irkerhook
sudo pip uninstall vext

# Remove configuration
sudo rm -rf /etc/vext

# Remove logs
sudo rm -rf /var/log/vext

# Remove user
sudo userdel irker
sudo groupdel irker
```

## Next Steps

After installation, see:
- [USAGE_GUIDE.md](USAGE_GUIDE.md) for operating vext
- [CONFIGURATION.md](CONFIGURATION.md) for detailed configuration options
- [README.md](README.md) for project overview

