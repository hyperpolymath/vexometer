-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Satellite Template Foreign Function Interface Declarations
--
-- NOTE: This is a template Foreign.idr for new vexometer satellites.
-- When creating a new satellite from this template, replace all
-- placeholder names and add satellite-specific FFI declarations.
--
-- IMPORTANT: Do NOT use cast for type casting. All type
-- conversions must use explicit, type-safe wrappers. See the
-- vexometer/src/abi/Foreign.idr for a reference implementation.
--
-- TODO: Replace {{project}} placeholders with satellite-specific names.
-- TODO: Add satellite-specific FFI function declarations.

module SatelliteTemplate.ABI.Foreign

import SatelliteTemplate.ABI.Types
import SatelliteTemplate.ABI.Layout

%default total

--------------------------------------------------------------------------------
-- Library Lifecycle
--------------------------------------------------------------------------------

||| Initialize the satellite library
||| Returns a handle to the library instance, or Nothing on failure
export
%foreign "C:satellite_template_init, libsatellite_template"
prim__init : PrimIO Bits64

||| Safe wrapper for library initialization
export
init : IO (Maybe Handle)
init = do
  ptr <- primIO prim__init
  pure (createHandle ptr)

||| Clean up library resources
export
%foreign "C:satellite_template_free, libsatellite_template"
prim__free : Bits64 -> PrimIO ()

||| Safe wrapper for cleanup
export
free : Handle -> IO ()
free h = primIO (prim__free (handlePtr h))

--------------------------------------------------------------------------------
-- Core Operations (placeholder — replace with satellite-specific ops)
--------------------------------------------------------------------------------

||| Process data (replace with satellite-specific operation)
export
%foreign "C:satellite_template_process, libsatellite_template"
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
%foreign "C:satellite_template_version, libsatellite_template"
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
