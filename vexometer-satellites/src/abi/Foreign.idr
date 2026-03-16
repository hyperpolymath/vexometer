-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Vexometer-Satellites Foreign Function Interface Declarations
--
-- NOTE: This is still a template Foreign.idr that needs per-component
-- customization. The satellite documentation hub does not have its own
-- FFI requirements yet, but when individual satellites define external
-- interfaces, this module should be replaced with satellite-specific
-- FFI declarations.
--
-- TODO: Customize with satellite-specific types and FFI functions
-- when the satellite protocol is finalised.

module VexometerSatellites.ABI.Foreign

import VexometerSatellites.ABI.Types
import VexometerSatellites.ABI.Layout

%default total

--------------------------------------------------------------------------------
-- Library Lifecycle
--------------------------------------------------------------------------------

||| Initialize the library
||| Returns a handle to the library instance, or Nothing on failure
export
%foreign "C:vexometer_satellites_init, libvexometer_satellites"
prim__init : PrimIO Bits64

||| Safe wrapper for library initialization
export
init : IO (Maybe Handle)
init = do
  ptr <- primIO prim__init
  pure (createHandle ptr)

||| Clean up library resources
export
%foreign "C:vexometer_satellites_free, libvexometer_satellites"
prim__free : Bits64 -> PrimIO ()

||| Safe wrapper for cleanup
export
free : Handle -> IO ()
free h = primIO (prim__free (handlePtr h))

--------------------------------------------------------------------------------
-- Core Operations (placeholder)
--------------------------------------------------------------------------------

||| Process satellite data
export
%foreign "C:vexometer_satellites_process, libvexometer_satellites"
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
%foreign "C:vexometer_satellites_version, libvexometer_satellites"
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
