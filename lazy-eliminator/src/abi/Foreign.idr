-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Lazy-Eliminator Foreign Function Interface Declarations
--
-- NOTE: This Foreign.idr needs per-component customization for the
-- lazy-eliminator satellite. It should define FFI functions for:
--   - lazy_eliminator_init / lazy_eliminator_free
--   - lazy_eliminator_scan_file (detect incomplete code patterns)
--   - lazy_eliminator_get_detections (retrieve detection results)
--
-- The Rust implementation provides the analysis engine; this Idris2
-- module declares the C-compatible interface for external consumers.
--
-- TODO: Replace with lazy-eliminator-specific types matching
-- IncompletenessKind, Language, and DetectionFFI from Types.idr.

module LazyEliminator.ABI.Foreign

import LazyEliminator.ABI.Types
import LazyEliminator.ABI.Layout

%default total

--------------------------------------------------------------------------------
-- Library Lifecycle
--------------------------------------------------------------------------------

||| Initialize the lazy-eliminator library
||| Returns a handle to the library instance, or Nothing on failure
export
%foreign "C:lazy_eliminator_init, liblazy_eliminator"
prim__init : PrimIO Bits64

||| Safe wrapper for library initialization
export
init : IO (Maybe Handle)
init = do
  ptr <- primIO prim__init
  pure (createHandle ptr)

||| Clean up library resources
export
%foreign "C:lazy_eliminator_free, liblazy_eliminator"
prim__free : Bits64 -> PrimIO ()

||| Safe wrapper for cleanup
export
free : Handle -> IO ()
free h = primIO (prim__free (handlePtr h))

--------------------------------------------------------------------------------
-- Core Operations (placeholder — needs lazy-eliminator customization)
--------------------------------------------------------------------------------

||| Scan a file for incompleteness patterns
export
%foreign "C:lazy_eliminator_process, liblazy_eliminator"
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
%foreign "C:lazy_eliminator_version, liblazy_eliminator"
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
