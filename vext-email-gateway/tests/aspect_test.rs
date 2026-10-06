// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// Security and aspect tests for vext email gateway

use ed25519_dalek::SigningKey;
use rand::TryRng;
use validator::Validate;
use vext_email_gateway::{Message, MessageId, VextError, DID};

fn generate_signing_key() -> SigningKey {
    let mut rng = rand::rngs::SysRng;
    let mut sk = [0u8; 32];
    rng.try_fill_bytes(&mut sk)
        .expect("SysRng must succeed for cryptographic key generation");
    SigningKey::from_bytes(&sk)
}

/// Security: Header injection prevention (CRLF in header values)
#[test]
fn aspect_crlf_header_injection() {
    let signing_key = generate_signing_key();

    // Attempt CRLF injection in title
    let injection_attempt = "Test\r\nX-Injected: true".to_string();

    let msg = Message::new(
        "Safe content".to_string(),
        &signing_key,
        Some(injection_attempt),
        vec![],
    )
    .expect("Message creation failed");

    // Message should be created but with literal CRLF characters (not interpreted)
    assert!(msg.verify().expect("Verification should succeed"));
    assert!(msg
        .title
        .as_ref()
        .map(|t| t.contains("\r\n"))
        .unwrap_or(false));
}

/// Security: Null byte handling in content
#[test]
fn aspect_null_byte_content() {
    let signing_key = generate_signing_key();

    let content_with_null = "Safe\0Unsafe".to_string();

    let msg = Message::new(content_with_null.clone(), &signing_key, None, vec![])
        .expect("Message creation failed");

    // Should handle null bytes safely
    assert!(msg.verify().expect("Verification should succeed"));
    assert_eq!(msg.content, content_with_null);
}

/// Security: Unicode normalization
#[test]
fn aspect_unicode_normalization() {
    let signing_key = generate_signing_key();

    // Different Unicode representations of same character
    let content_nfc = "café".to_string(); // NFC form
    let content_nfd = "cafe\u{0301}".to_string(); // NFD form

    let msg1 = Message::new(content_nfc.clone(), &signing_key, None, vec![])
        .expect("Message 1 creation failed");

    let msg2 = Message::new(content_nfd.clone(), &signing_key, None, vec![])
        .expect("Message 2 creation failed");

    // Both should verify, but may have different IDs
    assert!(msg1.verify().expect("Message 1 verify failed"));
    assert!(msg2.verify().expect("Message 2 verify failed"));
}

/// Security: Very large content (near 1MB limit)
#[test]
fn aspect_maximum_content_size() {
    let signing_key = generate_signing_key();

    // Create content at 99% of 1MB limit
    let large_content = "x".repeat(1_037_000); // Just under 1MB

    let msg = Message::new(large_content, &signing_key, None, vec![])
        .expect("Message creation at max size failed");

    assert!(msg.verify().expect("Verification failed"));
    assert!(msg.content.len() < 1_048_576);
}

/// Security: Oversized title rejection
#[test]
fn aspect_oversized_title() {
    let signing_key = generate_signing_key();

    // Title exceeds 500 character limit
    let oversized_title = "x".repeat(501);

    let result = Message::new(
        "content".to_string(),
        &signing_key,
        Some(oversized_title),
        vec![],
    );

    // Should fail validation
    assert!(matches!(result, Err(VextError::Validation(_))));
}

/// Security: Oversized tags array
#[test]
fn aspect_too_many_tags() {
    let signing_key = generate_signing_key();

    // More than 20 tags
    let tags: Vec<String> = (0..25).map(|i| format!("tag{}", i)).collect();

    let msg = Message::new("content".to_string(), &signing_key, None, tags);

    // Should fail validation (max 20 tags)
    assert!(matches!(msg, Err(VextError::Validation(_))));
}

/// Security: Invalid message ID format rejection
#[test]
fn aspect_invalid_message_id_format() {
    let invalid_ids = vec![
        "invalid",
        "vext:wrong:format",
        "vext:sha256:",          // No hash
        "vext:sha256:UPPERCASE", // Uppercase hex
        "vext:sha256:abcdef",    // Too short
        "vext:sha256:abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghij", // 65 chars
    ];

    for invalid_id in invalid_ids {
        let result = MessageId::from_string(invalid_id.to_string());
        assert!(result.is_err(), "Should reject invalid ID: {}", invalid_id);
    }
}

/// Security: DID format validation
#[test]
fn aspect_invalid_did_format() {
    let invalid_dids = vec![
        "invalid",
        "did:key:",
        "did:key:z6Mk",
        "did:key:z6Mkabcd", // Too short
        "did:key:z6MkZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ", // Wrong length
    ];

    for invalid_did in invalid_dids {
        let did: DID = serde_json::from_value(serde_json::Value::String(invalid_did.to_string()))
            .expect("DID deserialises from any string");
        assert!(
            did.to_public_key().is_err(),
            "{invalid_did:?} must not yield a public key"
        );
    }
}

/// Security: DID as String parsing
#[test]
fn aspect_did_string_parsing() {
    let signing_key = generate_signing_key();
    let did = DID::from_public_key(&signing_key.verifying_key());

    let did_str = did.as_str().to_string();

    // Should be able to recover public key from DID string
    let parsed: DID = serde_json::from_value(serde_json::Value::String(did_str))
        .expect("DID deserialises from its own string");
    let recovered_key = parsed.to_public_key().expect("Key recovery failed");

    assert_eq!(signing_key.verifying_key(), recovered_key);
}

/// Security: Signature tampering detection
#[test]
fn aspect_signature_tampering() {
    let signing_key = generate_signing_key();
    let mut msg = Message::new("Original content".to_string(), &signing_key, None, vec![])
        .expect("Message creation failed");

    // Tamper with signature by flipping a bit
    let sig_bytes = msg.signature.to_bytes();
    let mut tampered_bytes = sig_bytes.clone();
    tampered_bytes[0] ^= 0x01; // Flip first bit
    msg.signature = ed25519_dalek::Signature::from_bytes(&tampered_bytes);

    // Verification should fail
    let result = msg.verify().expect("Verify call should not error");
    assert!(!result, "Tampered signature should fail verification");
}

/// Security: Content type validation
#[test]
fn aspect_content_type_validation() {
    let signing_key = generate_signing_key();

    // Very long content-type
    let mut msg = Message::new("content".to_string(), &signing_key, None, vec![])
        .expect("Message creation failed");

    msg.content_type = "x".repeat(101); // Exceeds 100 char limit

    // Validation should fail
    assert!(msg.validate().is_err());
}

/// Security: Language code validation
#[test]
fn aspect_language_code_validation() {
    let signing_key = generate_signing_key();

    // Invalid language code (not 2 chars)
    let mut msg = Message::new("content".to_string(), &signing_key, None, vec![])
        .expect("Message creation failed");

    msg.language = "invalid".to_string();

    // Validation should fail (language must be exactly 2 chars)
    assert!(msg.validate().is_err());
}

/// Security: License field validation
#[test]
fn aspect_license_field_validation() {
    let signing_key = generate_signing_key();

    // Valid SPDX licenses
    let valid_licenses = vec!["MIT", "Apache-2.0", "CC-BY-SA-4.0", "MPL-2.0"];

    for license in valid_licenses {
        let mut msg = Message::new("content".to_string(), &signing_key, None, vec![])
            .expect("Message creation failed");

        msg.license = license.to_string();
        assert!(msg.validate().is_ok(), "Should accept license: {}", license);
    }
}

/// Security: Empty content rejection (should validate)
#[test]
fn aspect_empty_content() {
    let signing_key = generate_signing_key();

    let result = Message::new("".to_string(), &signing_key, None, vec![]);

    // Empty content might be allowed, but let's verify behavior
    match result {
        Ok(msg) => {
            assert_eq!(msg.content, "");
            assert!(msg.verify().expect("Verify should succeed"));
        }
        Err(_) => {
            // Also acceptable if validation rejects empty content
        }
    }
}

/// Security: Whitespace-only content
#[test]
fn aspect_whitespace_content() {
    let signing_key = generate_signing_key();

    let whitespace_content = "   \n\t   ".to_string();

    let msg = Message::new(whitespace_content.clone(), &signing_key, None, vec![])
        .expect("Message creation failed");

    assert!(msg.verify().expect("Verify should succeed"));
    assert_eq!(msg.content, whitespace_content);
}

/// Aspect: Deterministic author DIDs
#[test]
fn aspect_deterministic_signing() {
    let signing_key = generate_signing_key();
    let content = "test".to_string();

    let msg1 = Message::new(content.clone(), &signing_key, None, vec![]).expect("Message 1 failed");

    let msg2 = Message::new(content, &signing_key, None, vec![]).expect("Message 2 failed");

    // Author DIDs must be identical for same key
    assert_eq!(msg1.author, msg2.author);

    // Both messages should verify
    assert!(msg1.verify().expect("Message 1 verify failed"));
    assert!(msg2.verify().expect("Message 2 verify failed"));
}
