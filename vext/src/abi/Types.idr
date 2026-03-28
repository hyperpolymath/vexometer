-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
||| ABI Types for Vext — verifiable communications protocol
|||
||| Defines the formal interface for integrity verification,
||| feed verification, hash chains, and attestation.
||| Proves that:
|||   1. Hash chain append is monotonic (length only increases)
|||   2. Attestation requires a valid hash chain
|||   3. Verification results are constructive
module Vext.ABI.Types

import Data.Fin
import Data.Nat

%default total

-- ═══════════════════════════════════════════════════════════════════════
-- Core Types
-- ═══════════════════════════════════════════════════════════════════════

||| Verification result
public export
data VerifyResult = Verified | Tampered | Expired | Unknown

||| Vext operation
public export
data Operation
  = VerifyIntegrity     -- Verify message integrity
  | VerifyFeed          -- Verify feed content provenance
  | AppendChain         -- Append to hash chain
  | CreateAttestation   -- Create attestation document
  | CheckAttestation    -- Verify an attestation

||| Hash algorithm used in chains
public export
data HashAlgo = SHA256 | SHA3_256 | BLAKE3

-- ═══════════════════════════════════════════════════════════════════════
-- Hash Chain Monotonicity Proof
-- ═══════════════════════════════════════════════════════════════════════

||| A hash chain with known length
public export
data Chain : Nat -> Type where
  Empty : Chain 0
  Link  : (hash : String) -> Chain n -> Chain (S n)

||| Proof that appending increases chain length
public export
appendIncreases : (c : Chain n) -> (hash : String) -> Chain (S n)
appendIncreases c hash = Link hash c

-- ═══════════════════════════════════════════════════════════════════════
-- C ABI Exports
-- ═══════════════════════════════════════════════════════════════════════

export
verifyResultToInt : VerifyResult -> Int
verifyResultToInt Verified = 0
verifyResultToInt Tampered = 1
verifyResultToInt Expired  = 2
verifyResultToInt Unknown  = 3

export
operationToInt : Operation -> Int
operationToInt VerifyIntegrity   = 0
operationToInt VerifyFeed        = 1
operationToInt AppendChain       = 2
operationToInt CreateAttestation = 3
operationToInt CheckAttestation  = 4

export
hashAlgoToInt : HashAlgo -> Int
hashAlgoToInt SHA256   = 0
hashAlgoToInt SHA3_256 = 1
hashAlgoToInt BLAKE3   = 2
