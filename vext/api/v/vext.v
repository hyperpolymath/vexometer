// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Vext V-lang API — High-level client for verifiable communications.
// Wraps the Zig FFI which implements the Idris2 ABI.
module vext

// ═══════════════════════════════════════════════════════════════════════
// Types (mirror Idris2 ABI)
// ═══════════════════════════════════════════════════════════════════════

pub enum VerifyResult {
	verified
	tampered
	expired
	unknown
}

pub enum HashAlgo {
	sha256
	sha3_256
	blake3
}

pub struct IntegrityCheck {
pub:
	message  []u8
	hash     string
	algo     HashAlgo
}

pub struct FeedVerification {
pub:
	feed_url   string
	content    []u8
	signature  string
}

pub struct Attestation {
pub:
	subject    string
	chain_hash string
	timestamp  i64
	algo       HashAlgo
}

// ═══════════════════════════════════════════════════════════════════════
// FFI bindings (calls into Zig layer)
// ═══════════════════════════════════════════════════════════════════════

fn C.vext_verify_integrity(msg_ptr &u8, msg_len int, hash_ptr &u8, algo int) int
fn C.vext_verify_feed(url_ptr &u8, content_ptr &u8, content_len int, sig_ptr &u8) int
fn C.vext_chain_append(chain_ptr voidptr, hash_ptr &u8) int
fn C.vext_attest(subject_ptr &u8, chain_hash_ptr &u8, algo int) voidptr
fn C.vext_check_attestation(att_ptr voidptr) int

// ═══════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════

// verify_integrity checks message integrity against a known hash.
pub fn verify_integrity(check IntegrityCheck) VerifyResult {
	result := C.vext_verify_integrity(check.message.data, check.message.len,
		check.hash.str, int(check.algo))
	return match result {
		0 { .verified }
		1 { .tampered }
		2 { .expired }
		else { .unknown }
	}
}

// verify_feed verifies feed content provenance and signature.
pub fn verify_feed(feed FeedVerification) VerifyResult {
	result := C.vext_verify_feed(feed.feed_url.str, feed.content.data,
		feed.content.len, feed.signature.str)
	return match result {
		0 { .verified }
		1 { .tampered }
		2 { .expired }
		else { .unknown }
	}
}

// check_attestation verifies an attestation document.
pub fn check_attestation(att &Attestation) VerifyResult {
	result := C.vext_check_attestation(att)
	return match result {
		0 { .verified }
		1 { .tampered }
		2 { .expired }
		else { .unknown }
	}
}
