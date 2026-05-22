# SPDX-License-Identifier: MPL-2.0
# English (US) translations for vext

# Notification messages
notification-commit = { $author } committed to { $branch }: { $message }
notification-push = { $author } pushed { $count } commits to { $branch }
notification-merge = { $author } merged { $source } into { $target }

# Status messages
status-connected = Connected to IRC server { $server }
status-disconnected = Disconnected from IRC server { $server }
status-joining = Joining channel { $channel }
status-rate-limited = Rate limited on { $target }, queuing message

# Error messages
error-connection-failed = Failed to connect to { $server }: { $reason }
error-invalid-target = Invalid IRC target: { $target }
error-send-failed = Failed to send message to { $target }

# Help messages
help-usage = Usage: vextd [OPTIONS]
help-listen = Listen address for UDP notifications (default: 127.0.0.1:6659)
help-server = Default IRC server (default: irc.libera.chat)
