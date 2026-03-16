-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Vext-Email-Gateway Foreign Function Interface Declarations
--
-- NOTE: This Foreign.idr needs per-component customization for the
-- vext email bridge. It should define FFI functions for:
--   - vext_email_init / vext_email_free
--   - vext_email_send / vext_email_receive
--   - vext_email_verify (verify vext signatures on email content)
--
-- The email gateway bridges the vext verifiable communications protocol
-- to standard email (SMTP/IMAP), embedding vext proofs in email headers.
--
-- TODO: Replace with vext-email-gateway-specific types matching
-- email message, delivery status, and verification result types.

module VextEmailGateway.ABI.Foreign

import VextEmailGateway.ABI.Types
import VextEmailGateway.ABI.Layout

%default total

--------------------------------------------------------------------------------
-- Library Lifecycle
--------------------------------------------------------------------------------

||| Initialize the vext email gateway
||| Returns a handle to the library instance, or Nothing on failure
export
%foreign "C:vext_email_init, libvext_email_gateway"
prim__init : PrimIO Bits64

||| Safe wrapper for library initialization
export
init : IO (Maybe Handle)
init = do
  ptr <- primIO prim__init
  pure (createHandle ptr)

||| Clean up library resources
export
%foreign "C:vext_email_free, libvext_email_gateway"
prim__free : Bits64 -> PrimIO ()

||| Safe wrapper for cleanup
export
free : Handle -> IO ()
free h = primIO (prim__free (handlePtr h))

--------------------------------------------------------------------------------
-- Core Operations (placeholder — needs email gateway customization)
--------------------------------------------------------------------------------

||| Process email message
export
%foreign "C:vext_email_process, libvext_email_gateway"
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
%foreign "C:vext_email_version, libvext_email_gateway"
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
