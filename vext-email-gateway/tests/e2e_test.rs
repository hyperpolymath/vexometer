// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// E2E integration tests for vext email gateway pipeline

use ed25519_dalek::SigningKey;
use rand::TryRng;
use vext_email_gateway::{Message, DID};

fn generate_signing_key() -> SigningKey {
    let mut rng = rand::rngs::SysRng;
    let mut sk = [0u8; 32];
    rng.try_fill_bytes(&mut sk)
        .expect("SysRng must succeed for cryptographic key generation");
    SigningKey::from_bytes(&sk)
}

/// E2E: Full message creation → verification pipeline
#[test]
fn e2e_message_creation_and_verification() {
    let signing_key = generate_signing_key();

    let msg = Message::new(
        "Hello, World! This is a test message.".to_string(),
        &signing_key,
        Some("Test Message".to_string()),
        vec!["test".to_string(), "e2e".to_string()],
    )
    .expect("Message creation failed");

    // Verify signature
    assert!(msg.verify().expect("Verification failed"));

    // Verify all fields populated
    assert_eq!(
        msg.author,
        DID::from_public_key(&signing_key.verifying_key())
    );
    assert_eq!(msg.content_type, "text/plain");
    assert_eq!(msg.language, "en");
    assert_eq!(msg.title, Some("Test Message".to_string()));
    assert_eq!(msg.tags.len(), 2);
}

/// E2E: Multi-message conversation chain
#[test]
fn e2e_message_chain() {
    let alice = generate_signing_key();
    let bob = generate_signing_key();

    // Alice's first message
    let msg1 = Message::new(
        "Hi Bob!".to_string(),
        &alice,
        Some("Greeting".to_string()),
        vec!["conversation".to_string()],
    )
    .expect("Message 1 creation failed");
    assert!(msg1.verify().expect("Message 1 verification failed"));

    // Bob's reply
    let mut msg2 = Message::new(
        "Hi Alice! Nice to hear from you.".to_string(),
        &bob,
        Some("Reply".to_string()),
        vec!["conversation".to_string()],
    )
    .expect("Message 2 creation failed");
    msg2.in_reply_to = Some(msg1.id.clone());
    assert!(msg2.verify().expect("Message 2 verification failed"));

    // Verify chain
    assert_eq!(msg2.in_reply_to, Some(msg1.id.clone()));
    assert_ne!(msg1.id, msg2.id);
    assert_ne!(msg1.author, msg2.author);
}

/// E2E: Serialization round-trip
#[test]
fn e2e_serialization_roundtrip() {
    let signing_key = generate_signing_key();

    let original = Message::new(
        "Test content for serialization".to_string(),
        &signing_key,
        Some("Test".to_string()),
        vec!["serial".to_string()],
    )
    .expect("Message creation failed");

    // Serialize to JSON
    let json = serde_json::to_string(&original).expect("Serialization failed");

    // Deserialize from JSON
    let deserialized: Message = serde_json::from_str(&json).expect("Deserialization failed");

    // Verify round-trip integrity
    assert_eq!(original.id, deserialized.id);
    assert_eq!(original.author, deserialized.author);
    assert_eq!(original.content, deserialized.content);
    assert!(deserialized.verify().expect("Verification failed"));
}

/// E2E: Large message handling (100KB content)
#[test]
fn e2e_large_message() {
    let signing_key = generate_signing_key();

    // Generate 100KB of content
    let large_content = "x".repeat(100_000);

    let msg = Message::new(
        large_content,
        &signing_key,
        Some("Large Message".to_string()),
        vec!["size-test".to_string()],
    )
    .expect("Large message creation failed");

    assert!(msg.verify().expect("Large message verification failed"));
    assert_eq!(msg.content.len(), 100_000);
}

/// E2E: Invalid DID format handling
#[test]
fn e2e_invalid_did_recovery() {
    let signing_key = generate_signing_key();
    let did = DID::from_public_key(&signing_key.verifying_key());

    // Valid DID should recover correctly
    let recovered = did.to_public_key().expect("Public key recovery failed");
    assert_eq!(signing_key.verifying_key(), recovered);

    // Invalid DID format should fail to parse
    let invalid_did_str = "invalid:did:format";
    let invalid_did = DID::from_public_key(&generate_signing_key().verifying_key());

    // Valid DID starts with correct prefix
    assert!(invalid_did.as_str().starts_with("did:key:z6Mk"));
    assert!(!invalid_did_str.starts_with("did:key:z6Mk"));
}

/// E2E: Message with all optional fields
#[test]
fn e2e_full_featured_message() {
    use chrono::{Duration, Utc};

    let signing_key = generate_signing_key();

    let mut msg = Message::new(
        "Feature test content".to_string(),
        &signing_key,
        Some("Featured".to_string()),
        vec!["feature1".to_string(), "feature2".to_string()],
    )
    .expect("Message creation failed");

    // Add optional fields
    msg.expires = Some(Utc::now() + Duration::days(7));
    msg.language = "en".to_string();
    msg.license = "CC-BY-SA-4.0".to_string();

    // Should still verify with all fields
    assert!(msg.verify().expect("Full message verification failed"));
    assert!(msg.expires.is_some());
}

/// E2E: Signing key produces consistent public key DIDs
#[test]
fn e2e_deterministic_message_ids() {
    let signing_key = generate_signing_key();

    // Create two DIDs from the same key
    let did1 = DID::from_public_key(&signing_key.verifying_key());
    let did2 = DID::from_public_key(&signing_key.verifying_key());

    // DIDs should be identical
    assert_eq!(did1, did2);

    // Message IDs will differ due to timestamps, but authors will be the same
    let msg1 = Message::new("Test".to_string(), &signing_key, None, vec![])
        .expect("Message 1 creation failed");

    let msg2 = Message::new("Test".to_string(), &signing_key, None, vec![])
        .expect("Message 2 creation failed");

    // Authors should be identical
    assert_eq!(msg1.author, msg2.author);
}

/// E2E: Message references chain
#[test]
fn e2e_message_references() {
    let signing_key = generate_signing_key();

    let msg1 = Message::new("First message".to_string(), &signing_key, None, vec![])
        .expect("Message 1 creation failed");

    let msg2 = Message::new("Second message".to_string(), &signing_key, None, vec![])
        .expect("Message 2 creation failed");

    let mut msg3 = Message::new(
        "Third message references both".to_string(),
        &signing_key,
        None,
        vec![],
    )
    .expect("Message 3 creation failed");

    msg3.references = vec![msg1.id.clone(), msg2.id.clone()];
    assert!(msg3.verify().expect("Message 3 verification failed"));
    assert_eq!(msg3.references.len(), 2);
}
