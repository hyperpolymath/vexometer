-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Vext Foreign Function Interface Declarations
--
-- NOTE: This Foreign.idr needs per-component customization for the
-- vext verifiable communications protocol. It should define FFI
-- functions for:
--   - vext_init / vext_free
--   - vext_create_message / vext_verify_message
--   - vext_sign / vext_verify_signature
--
-- Vext combines Idris2 (proofs) and Rust (implementation) to provide
-- a formally verified messaging protocol. This module should declare
-- the C-compatible bridge between Idris2 proofs and Rust crypto.
--
-- TODO: Replace with vext-specific types matching the protocol's
-- message, signature, and verification result types.

module Vext.ABI.Foreign

import Vext.ABI.Types
import Vext.ABI.Layout

%default total

--------------------------------------------------------------------------------
-- Library Lifecycle
--------------------------------------------------------------------------------

||| Initialize the vext protocol library
||| Returns a handle to the library instance, or Nothing on failure
export
%foreign "C:vext_init, libvext"
prim__init : PrimIO Bits64

||| Safe wrapper for library initialization
export
init : IO (Maybe Handle)
init = do
  ptr <- primIO prim__init
  pure (createHandle ptr)

||| Clean up library resources
export
%foreign "C:vext_free, libvext"
prim__free : Bits64 -> PrimIO ()

||| Safe wrapper for cleanup
export
free : Handle -> IO ()
free h = primIO (prim__free (handlePtr h))

--------------------------------------------------------------------------------
-- Core Operations (placeholder — needs vext customization)
--------------------------------------------------------------------------------

||| Process protocol message
export
%foreign "C:vext_process, libvext"
prim__process : Bits64 -> Bits32 -> PrimIO Bits32

||| Safe wrapper with error handling
export
process : Handle -> Bits32 -> IO (Either Result Bits32)
process h input = do
  result <- primIO (prim__process (handlePtr h) input)
  pure $ case result of
    0 => Left Error
    n => Right n

--------------------------------------------------------------------------------
-- Version Information
--------------------------------------------------------------------------------

||| Get library version
export
%foreign "C:vext_version, libvext"
prim__version : PrimIO Bits64

||| Get version as string
export
%foreign "support:idris2_getString, libidris2_support"
prim__getString : Bits64 -> String

||| Get version string
export
version : IO String
version = do
  ptr <- primIO prim__version
  pure (prim__getString ptr)
