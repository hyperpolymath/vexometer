// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// Property-based tests for vext email gateway

use ed25519_dalek::SigningKey;
use proptest::prelude::*;
use rand::TryRng;
use vext_email_gateway::{Message, MessageId, VextError, DID};

fn generate_signing_key() -> SigningKey {
    let mut rng = rand::rngs::SysRng;
    let mut sk = [0u8; 32];
    rng.try_fill_bytes(&mut sk)
        .expect("SysRng must succeed for cryptographic key generation");
    SigningKey::from_bytes(&sk)
}

// Property: All valid message IDs match expected format
#[test]
fn prop_message_id_format() {
    let signing_key = generate_signing_key();

    for _ in 0..100 {
        let msg = Message::new("test content".to_string(), &signing_key, None, vec![])
            .expect("Message creation failed");

        // Check format: vext:sha256:<64 hex chars>
        assert!(msg.id.as_str().starts_with("vext:sha256:"));
        let hex_part = &msg.id.as_str()["vext:sha256:".len()..];
        assert_eq!(hex_part.len(), 64);
        assert!(hex_part
            .chars()
            .all(|c| c.is_ascii_hexdigit() && !c.is_uppercase()));
    }
}

// Property: Message verification always deterministic
proptest! {
    #[test]
    fn prop_message_verification_deterministic(
        content in "\\PC{1,1000}",
    ) {
        let signing_key = generate_signing_key();
        let msg = Message::new(
            content,
            &signing_key,
            None,
            vec![],
        ).expect("Message creation failed");

        // Verify multiple times - result should always be the same
        let result1 = msg.verify().expect("First verify failed");
        let result2 = msg.verify().expect("Second verify failed");
        let result3 = msg.verify().expect("Third verify failed");

        prop_assert_eq!(result1, result2);
        prop_assert_eq!(result2, result3);
        prop_assert!(result1); // All should be true
    }
}

// Property: Same signer always produces same author DID
proptest! {
    #[test]
    fn prop_message_id_deterministic(content in "[a-zA-Z0-9 ]{1,500}") {
        let signing_key = generate_signing_key();

        let msg1 = Message::new(
            content.clone(),
            &signing_key,
            None,
            vec![],
        ).expect("Message 1 creation failed");

        let msg2 = Message::new(
            content,
            &signing_key,
            None,
            vec![],
        ).expect("Message 2 creation failed");

        // Authors should be the same for same signing key
        prop_assert_eq!(msg1.author, msg2.author);
    }
}

// Property: Different content from same key produces different IDs
proptest! {
    #[test]
    fn prop_different_content_different_id(
        content1 in "\\PC{1,100}",
        content2 in "\\PC{1,100}",
    ) {
        let signing_key = generate_signing_key();

        if content1 == content2 {
            return Ok(());
        }

        let msg1 = Message::new(
            content1,
            &signing_key,
            None,
            vec![],
        ).expect("Message 1 creation failed");

        let msg2 = Message::new(
            content2,
            &signing_key,
            None,
            vec![],
        ).expect("Message 2 creation failed");

        prop_assert_ne!(msg1.id, msg2.id);
    }
}

// Property: DID roundtrip always succeeds
#[test]
fn prop_did_roundtrip() {
    for _ in 0..100 {
        let signing_key = generate_signing_key();
        let did = DID::from_public_key(&signing_key.verifying_key());

        // Should always recover to same public key
        let recovered = did.to_public_key().expect("Public key recovery failed");
        assert_eq!(signing_key.verifying_key(), recovered);
    }
}

// Property: Message ID string parsing preserves value
#[test]
fn prop_message_id_string_parsing() {
    let signing_key = generate_signing_key();

    for _ in 0..100 {
        let msg = Message::new("test".to_string(), &signing_key, None, vec![])
            .expect("Message creation failed");

        let id_str = msg.id.as_str().to_string();

        // Parse from string should match original
        let parsed_id = MessageId::from_string(id_str).expect("Message ID parsing failed");

        assert_eq!(msg.id, parsed_id);
    }
}

// Property: Tampered messages always fail verification
proptest! {
    #[test]
    fn prop_tampered_message_fails(tamper_char in "\\PC{1,1}") {
        let signing_key = generate_signing_key();
        let mut msg = Message::new(
            "original content".to_string(),
            &signing_key,
            Some("Original".to_string()),
            vec!["original".to_string()],
        ).expect("Message creation failed");

        // Tamper with content
        msg.content = format!("tampered_{}", tamper_char);

        // Verification should fail
        let result = msg.verify().expect("Verify call should not error");
        prop_assert!(!result);
    }
}

// Property: Message creation always produces non-zero ID
#[test]
fn prop_message_id_never_zero() {
    let signing_key = generate_signing_key();

    for _ in 0..100 {
        let msg = Message::new(
            format!("content_{}", rand::random::<u32>()),
            &signing_key,
            None,
            vec![],
        )
        .expect("Message creation failed");

        // ID should never be all zeros
        let bytes = msg.id.hash_bytes().expect("Hash bytes extraction failed");
        assert!(!bytes.iter().all(|&b| b == 0));
    }
}

// Property: Content length validation
proptest! {
    #[test]
    fn prop_content_length_validation(content in "[a-zA-Z0-9 ]{0,5000}") {
        let signing_key = generate_signing_key();

        match Message::new(
            content.clone(),
            &signing_key,
            None,
            vec![],
        ) {
            Ok(msg) => {
                // Message creation succeeded - verify it
                prop_assert!(msg.verify().expect("Verify should not error"));
                prop_assert_eq!(msg.content.len(), content.len());
            },
            Err(VextError::Validation(_)) => {
                // Expected for some inputs (e.g., oversized)
                prop_assert!(content.len() > 1_048_576);
            },
            Err(_) => {
                // Other errors acceptable
            }
        }
    }
}

// Property: Created timestamp always valid
#[test]
fn prop_message_timestamp_valid() {
    use chrono::Utc;

    let signing_key = generate_signing_key();
    let before = Utc::now();

    let msg = Message::new("test".to_string(), &signing_key, None, vec![])
        .expect("Message creation failed");

    let after = Utc::now();

    // Timestamp should be between before and after
    assert!(msg.created >= before);
    assert!(msg.created <= after);
}

// Property: All created messages are valid (per validator)
proptest! {
    #[test]
    fn prop_all_messages_valid(
        content in "\\PC{1,1000}",
        title in "\\PC{0,500}",
    ) {
        let signing_key = generate_signing_key();
        let msg = Message::new(
            content,
            &signing_key,
            if title.is_empty() { None } else { Some(title) },
            vec!["test".to_string()],
        ).expect("Message creation failed");

        // Should always verify
        prop_assert!(msg.verify().expect("Verify should not error"));
    }
}
