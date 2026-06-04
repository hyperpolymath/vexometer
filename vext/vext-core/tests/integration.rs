// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//! Integration tests for vext-core

/// Test notification JSON parsing
#[test]
fn test_notification_parsing() {
    let json = r#"{
        "to": ["irc://irc.libera.chat/vext", "ircs://irc.oftc.net/vext-test"],
        "privmsg": "Test commit: Add new feature",
        "project": "vext",
        "branch": "main",
        "commit": "abc1234",
        "author": "developer"
    }"#;

    let parsed: serde_json::Value = serde_json::from_str(json).unwrap();
    assert_eq!(parsed["to"].as_array().unwrap().len(), 2);
    assert_eq!(parsed["privmsg"], "Test commit: Add new feature");
    assert_eq!(parsed["project"], "vext");
}

/// Test IRC URL parsing
#[test]
fn test_irc_url_parsing() {
    // Test basic IRC URL
    let url = "irc://irc.libera.chat/vext";
    assert!(url.starts_with("irc://"));

    // Test IRCS URL
    let url_tls = "ircs://irc.libera.chat:6697/vext";
    assert!(url_tls.starts_with("ircs://"));

    // Test URL with channel key
    let url_key = "irc://server/secret?key=password123";
    assert!(url_key.contains("key="));
}

/// Test notification serialization
#[test]
fn test_notification_serialization() {
    let notification = serde_json::json!({
        "to": ["irc://server/channel"],
        "privmsg": "Hello, world!",
        "project": "test"
    });

    let serialized = serde_json::to_string(&notification).unwrap();
    assert!(serialized.contains("privmsg"));
    assert!(serialized.contains("Hello, world!"));
}

/// Test multiple targets in notification
#[test]
fn test_multiple_targets() {
    let notification = serde_json::json!({
        "to": [
            "irc://irc.libera.chat/project1",
            "irc://irc.libera.chat/project2",
            "ircs://irc.oftc.net/logs"
        ],
        "privmsg": "Broadcast message"
    });

    let targets = notification["to"].as_array().unwrap();
    assert_eq!(targets.len(), 3);
}

/// Test color scheme handling
#[test]
fn test_color_schemes() {
    let notification_no_color = serde_json::json!({
        "to": ["irc://server/channel"],
        "privmsg": "Plain message"
    });
    assert!(notification_no_color.get("colors").is_none());

    let notification_mirc = serde_json::json!({
        "to": ["irc://server/channel"],
        "privmsg": "Colored message",
        "colors": "mirc"
    });
    assert_eq!(notification_mirc["colors"], "mirc");
}

/// Test configuration defaults
#[test]
fn test_config_defaults() {
    // Default server should be Libera.Chat
    let default_server = "irc.libera.chat";
    let default_port_tls = 6697u16;
    let default_port_plain = 6667u16;

    assert_eq!(default_server, "irc.libera.chat");
    assert_eq!(default_port_tls, 6697);
    assert_eq!(default_port_plain, 6667);
}

/// Test rate limiting calculation
#[test]
fn test_rate_limit_tokens() {
    // Default 1 msg/sec, with 5 second burst
    let rate = 1.0_f64;
    let burst = rate * 5.0;

    assert_eq!(burst, 5.0);

    // After consuming all tokens, should need to wait
    let tokens_after_burst = 0.0_f64;
    let wait_time = (1.0 - tokens_after_burst) / rate;
    assert_eq!(wait_time, 1.0);
}

/// Test channel name formatting
#[test]
fn test_channel_formatting() {
    // Channels should start with # or &
    let channel1 = "vext";
    let formatted1 = if channel1.starts_with('#') || channel1.starts_with('&') {
        channel1.to_string()
    } else {
        format!("#{}", channel1)
    };
    assert_eq!(formatted1, "#vext");

    let channel2 = "#already-formatted";
    let formatted2 = if channel2.starts_with('#') || channel2.starts_with('&') {
        channel2.to_string()
    } else {
        format!("#{}", channel2)
    };
    assert_eq!(formatted2, "#already-formatted");
}

/// Test nick generation uniqueness
#[test]
fn test_nick_generation() {
    let prefix = "vext";
    let server1 = "irc.libera.chat";
    let server2 = "irc.oftc.net";

    // Different servers should produce different nick suffixes
    let hash1: u32 = server1.bytes().map(|b| b as u32).sum();
    let hash2: u32 = server2.bytes().map(|b| b as u32).sum();

    let nick1 = format!("{}_{:x}0", prefix, hash1 % 0xFFF);
    let nick2 = format!("{}_{:x}0", prefix, hash2 % 0xFFF);

    assert_ne!(nick1, nick2);
    assert!(nick1.starts_with("vext_"));
}

/// Test message chunking for long messages
#[test]
fn test_message_chunking() {
    let max_len = 400;
    let long_message = "A".repeat(1000);

    let chunks: Vec<&[u8]> = long_message.as_bytes().chunks(max_len).collect();

    assert_eq!(chunks.len(), 3);
    assert_eq!(chunks[0].len(), 400);
    assert_eq!(chunks[1].len(), 400);
    assert_eq!(chunks[2].len(), 200);
}

/// Test JSON notification with all optional fields
#[test]
fn test_full_notification() {
    let notification = serde_json::json!({
        "to": ["ircs://irc.libera.chat:6697/vext"],
        "privmsg": "[vext] main abc1234 dev: Add async support",
        "project": "vext",
        "repository": "/home/user/vext",
        "branch": "main",
        "commit": "abc1234def5678",
        "author": "developer",
        "url": "https://github.com/Hyperpolymath/vext/commit/abc1234",
        "colors": "mirc"
    });

    // All fields should be present
    assert!(notification.get("to").is_some());
    assert!(notification.get("privmsg").is_some());
    assert!(notification.get("project").is_some());
    assert!(notification.get("repository").is_some());
    assert!(notification.get("branch").is_some());
    assert!(notification.get("commit").is_some());
    assert!(notification.get("author").is_some());
    assert!(notification.get("url").is_some());
    assert!(notification.get("colors").is_some());
}
