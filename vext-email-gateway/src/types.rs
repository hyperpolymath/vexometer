// SPDX-License-Identifier: PMPL-1.0-or-later
// Core types for vext email gateway

use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fmt;
use thiserror::Error;
use validator::Validate;

/// Errors that can occur in vext operations
#[derive(Error, Debug)]
pub enum VextError {
    #[error("Invalid signature")]
    InvalidSignature,

    #[error("Invalid message ID (hash mismatch)")]
    InvalidMessageId,

    #[error("Invalid DID format: {0}")]
    InvalidDID(String),

    #[error("Invalid email address: {0}")]
    InvalidEmail(String),

    #[error("Message too large: {0} bytes (max: {1})")]
    MessageTooLarge(usize, usize),

    #[error("Rate limit exceeded")]
    RateLimitExceeded,

    #[error("Validation error: {0}")]
    Validation(String),

    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),

    #[error("SMTP error: {0}")]
    Email(#[from] lettre::transport::smtp::Error),

    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
}

pub type Result<T> = std::result::Result<T, VextError>;

/// Decentralized Identifier (DID) - cryptographically verifiable identity
///
/// Format: did:key:z6Mk<hex(public_key_bytes)>
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct DID(String);

impl DID {
    /// Create DID from Ed25519 public key
    pub fn from_public_key(public_key: &VerifyingKey) -> Self {
        DID(format!("did:key:z6Mk{}", hex::encode(public_key.as_bytes())))
    }

    /// Extract public key from DID
    pub fn to_public_key(&self) -> Result<VerifyingKey> {
        if !self.0.starts_with("did:key:z6Mk") {
            return Err(VextError::InvalidDID(self.0.clone()));
        }

        let hex_part = &self.0["did:key:z6Mk".len()..];
        let bytes = hex::decode(hex_part).map_err(|_| VextError::InvalidDID(self.0.clone()))?;
        if bytes.len() != 32 {
            return Err(VextError::InvalidDID(self.0.clone()));
        }

        let mut key_bytes = [0u8; 32];
        key_bytes.copy_from_slice(&bytes);
        VerifyingKey::from_bytes(&key_bytes)
            .map_err(|_| VextError::InvalidDID(self.0.clone()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for DID {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// Content-addressed message ID
///
/// Format: vext:sha256:<64 lower-hex chars>
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct MessageId(String);

impl MessageId {
    /// Create message ID from hash
    pub fn from_hash(hash: [u8; 32]) -> Self {
        MessageId(format!("vext:sha256:{}", hex::encode(hash)))
    }

    /// Parse and validate message ID from string
    pub fn from_string(s: String) -> Result<Self> {
        if !s.starts_with("vext:sha256:") {
            return Err(VextError::InvalidMessageId);
        }

        let hex_part = &s["vext:sha256:".len()..];
        if hex_part.len() != 64 {
            return Err(VextError::InvalidMessageId);
        }

        if !hex_part
            .chars()
            .all(|c| c.is_ascii_hexdigit() && !c.is_uppercase())
        {
            return Err(VextError::InvalidMessageId);
        }

        Ok(MessageId(s))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// Extract hash bytes
    pub fn hash_bytes(&self) -> Result<[u8; 32]> {
        let hex_part = &self.0["vext:sha256:".len()..];
        let bytes = hex::decode(hex_part).map_err(|_| VextError::InvalidMessageId)?;
        if bytes.len() != 32 {
            return Err(VextError::InvalidMessageId);
        }
        let mut arr = [0u8; 32];
        arr.copy_from_slice(&bytes);
        Ok(arr)
    }
}

impl fmt::Display for MessageId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// Vext message - core data structure
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct Message {
    /// Content-addressed ID (SHA-256 of canonical message)
    pub id: MessageId,

    /// Author's DID (public key)
    pub author: DID,

    /// Ed25519 signature over canonical representation
    #[serde(with = "signature_serde")]
    pub signature: Signature,

    /// Creation timestamp (UTC)
    pub created: chrono::DateTime<chrono::Utc>,

    /// Optional expiration
    pub expires: Option<chrono::DateTime<chrono::Utc>>,

    /// Content type (MIME-style)
    #[validate(length(max = 100))]
    pub content_type: String,

    /// Message content (max 1MB for email compatibility)
    #[validate(length(max = 1_048_576))]
    pub content: String,

    /// Optional title
    #[validate(length(max = 500))]
    pub title: Option<String>,

    /// Tags for categorization
    #[validate(length(max = 20))]
    pub tags: Vec<String>,

    /// Language code (ISO 639-1)
    #[validate(length(equal = 2))]
    pub language: String,

    /// Reply to another message
    pub in_reply_to: Option<MessageId>,

    /// References to other messages
    #[validate(length(max = 100))]
    pub references: Vec<MessageId>,

    /// License (SPDX identifier)
    #[validate(length(max = 100))]
    pub license: String,

    /// Optional payment info
    pub payment: Option<Payment>,
}

/// Payment information (optional)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Payment {
    /// Payment URI (Lightning, etc.)
    pub uri: String,

    /// Amount (with unit)
    pub amount: String,
}

/// Custom serde for Signature (ed25519_dalek doesn't impl Serialize)
mod signature_serde {
    use super::*;
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S>(sig: &Signature, serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(&hex::encode(sig.to_bytes()))
    }

    pub fn deserialize<'de, D>(deserializer: D) -> std::result::Result<Signature, D::Error>
    where
        D: Deserializer<'de>,
    {
        let s = String::deserialize(deserializer)?;
        let bytes = hex::decode(s).map_err(serde::de::Error::custom)?;
        if bytes.len() != 64 {
            return Err(serde::de::Error::custom("invalid signature length"));
        }
        let mut arr = [0u8; 64];
        arr.copy_from_slice(&bytes);
        Ok(Signature::from_bytes(&arr))
    }
}

impl Message {
    /// Create new message (signs automatically)
    pub fn new(
        content: String,
        signing_key: &SigningKey,
        title: Option<String>,
        tags: Vec<String>,
    ) -> Result<Self> {
        let created = chrono::Utc::now();
        let author = DID::from_public_key(&signing_key.verifying_key());

        // Create unsigned message
        let mut msg = Message {
            id: MessageId::from_hash([0; 32]), // placeholder; replaced after hashing
            author: author.clone(),
            signature: Signature::from_bytes(&[0; 64]), // placeholder; replaced after signing
            created,
            expires: None,
            content_type: "text/plain".to_string(),
            content: content.clone(),
            title,
            tags,
            language: "en".to_string(),
            in_reply_to: None,
            references: vec![],
            license: "CC-BY-SA-4.0".to_string(),
            payment: None,
        };

        // Canonical representation
        let canonical = msg.canonical_json()?;

        // Hash
        let mut hasher = Sha256::new();
        hasher.update(canonical.as_bytes());
        let hash: [u8; 32] = hasher.finalize().into();

        // Sign
        let signature = signing_key.sign(&hash);

        // Update message
        msg.id = MessageId::from_hash(hash);
        msg.signature = signature;

        // Validate
        msg.validate()
            .map_err(|e| VextError::Validation(e.to_string()))?;

        Ok(msg)
    }

    /// Verify message signature and ID
    pub fn verify(&self) -> Result<bool> {
        // 1. Canonical representation (same as when signing)
        let canonical = self.canonical_json()?;

        // 2. Hash
        let mut hasher = Sha256::new();
        hasher.update(canonical.as_bytes());
        let hash: [u8; 32] = hasher.finalize().into();

        // 3. Verify message ID matches hash
        let expected_id = MessageId::from_hash(hash);
        if self.id != expected_id {
            return Ok(false);
        }

        // 4. Extract public key from DID
        let public_key = self.author.to_public_key()?;

        // 5. Verify signature
        Ok(public_key.verify(&hash, &self.signature).is_ok())
    }

    /// Canonical JSON representation (for signing/hashing)
    fn canonical_json(&self) -> Result<String> {
        // Create minimal representation (only signed fields)
        let canonical = serde_json::json!({
            "author": self.author.as_str(),
            "content": &self.content,
            "content_type": &self.content_type,
            "created": self.created.to_rfc3339(),
            "language": &self.language,
            "license": &self.license,
            "tags": &self.tags,
            "title": &self.title,
        });

        // Serialize with sorted keys, no whitespace
        Ok(serde_json::to_string(&canonical)?)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    fn generate_signing_key() -> SigningKey {
        use rand::RngCore;
        let mut rng = rand::rngs::OsRng;
        let mut sk = [0u8; 32];
        rng.fill_bytes(&mut sk);
        SigningKey::from_bytes(&sk)
    }

    #[test]
    fn test_did_roundtrip() {
        let signing_key = generate_signing_key();
        let did = DID::from_public_key(&signing_key.verifying_key());
        let recovered = did.to_public_key().unwrap();
        assert_eq!(signing_key.verifying_key(), recovered);
    }

    #[test]
    fn test_message_verify() {
        let signing_key = generate_signing_key();
        let msg = Message::new(
            "Test content".to_string(),
            &signing_key,
            Some("Test".to_string()),
            vec!["test".to_string()],
        )
        .unwrap();

        assert!(msg.verify().unwrap());
    }

    #[test]
    fn test_tampered_message_fails() {
        let signing_key = generate_signing_key();
        let mut msg = Message::new(
            "Test content".to_string(),
            &signing_key,
            Some("Test".to_string()),
            vec!["test".to_string()],
        )
        .unwrap();

        // Tamper with content
        msg.content = "Tampered content".to_string();

        // Verification should fail
        assert!(!msg.verify().unwrap());
    }

    // Property-based testing: message creation always produces valid messages
    proptest! {
        #[test]
        fn prop_message_always_valid(content in "\\PC{1,1000}", title in "\\PC{1,100}") {
            let signing_key = generate_signing_key();
            let msg = Message::new(
                content,
                &signing_key,
                Some(title),
                vec!["test".to_string()],
            ).unwrap();

            prop_assert!(msg.verify().unwrap());
        }
    }
}

// Optional formal verification annotations (Kani).
#[cfg(feature = "kani")]
mod verification {
    use super::*;

    fn generate_signing_key() -> SigningKey {
        use rand::RngCore;
        let mut rng = rand::rngs::OsRng;
        let mut sk = [0u8; 32];
        rng.fill_bytes(&mut sk);
        SigningKey::from_bytes(&sk)
    }

    #[kani::proof]
    fn verify_did_roundtrip() {
        let signing_key = generate_signing_key();
        let did = DID::from_public_key(&signing_key.verifying_key());
        let recovered = did.to_public_key().unwrap();
        kani::assert(signing_key.verifying_key() == recovered, "DID roundtrip failed");
    }

    #[kani::proof]
    fn verify_message_id_uniqueness() {
        // Different content -> different IDs
        let signing_key = generate_signing_key();

        let msg1 = Message::new("Content 1".to_string(), &signing_key, None, vec![]).unwrap();
        let msg2 = Message::new("Content 2".to_string(), &signing_key, None, vec![]).unwrap();

        kani::assert(msg1.id != msg2.id, "Different content must have different IDs");
    }
}
