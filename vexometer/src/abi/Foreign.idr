-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Vexometer Foreign Function Interface Declarations
--
-- Declares C-compatible FFI functions for the vexometer analysis engine.
-- The Zig FFI layer (ffi/zig/src/main.zig) implements these functions,
-- bridging to the Ada analysis routines via C pragma conventions.
--
-- No cast is used; all type conversions are explicit and safe.

module Vexometer.ABI.Foreign

import Vexometer.ABI.Types

%default total

--------------------------------------------------------------------------------
-- Session Lifecycle
--------------------------------------------------------------------------------

||| Initialise a new vexometer analysis session.
||| Returns a positive integer handle on success, or -1 on failure.
||| The handle must be freed with vexometer_free when no longer needed.
%foreign "C:vexometer_init,libvexometer_ffi"
export
vexometer_init : PrimIO Int

||| Free a vexometer analysis session and all associated resources.
||| Safe to call with any handle value; invalid handles are ignored.
%foreign "C:vexometer_free,libvexometer_ffi"
export
vexometer_free : Int -> PrimIO ()

--------------------------------------------------------------------------------
-- Analysis Operations
--------------------------------------------------------------------------------

||| Analyse a prompt-response pair for irritation patterns.
||| Parameters:
|||   handle   - Session handle from vexometer_init
|||   prompt   - The user's prompt text (null-terminated C string)
|||   response - The AI assistant's response text (null-terminated C string)
||| Returns: number of findings detected, or -1 on error.
|||
||| Note: In the full implementation, this calls into Ada analysis routines
||| via the C ABI bridge. The Zig FFI layer provides the C-compatible entry
||| point that Ada's pragma Import can reference.
%foreign "C:vexometer_analyze,libvexometer_ffi"
export
vexometer_analyze : Int -> String -> String -> PrimIO Int

--------------------------------------------------------------------------------
-- Score Retrieval
--------------------------------------------------------------------------------

||| Get the overall ISA (Irritation Surface Area) score for a session.
||| Returns: ISA score multiplied by 1000 (fixed-point), or -1 on error.
||| Example: a score of 42.5 is returned as 42500.
%foreign "C:vexometer_get_isa_score,libvexometer_ffi"
export
vexometer_get_isa_score : Int -> PrimIO Int

||| Get the score for a specific metric category.
||| Parameters:
|||   handle         - Session handle from vexometer_init
|||   category_index - MetricCategory ordinal value (0-9)
||| Returns: category score multiplied by 1000, or -1 on error.
%foreign "C:vexometer_get_category_score,libvexometer_ffi"
export
vexometer_get_category_score : Int -> Int -> PrimIO Int

--------------------------------------------------------------------------------
-- Finding/Metric Counts
--------------------------------------------------------------------------------

||| Get the number of findings detected in the current session.
||| Returns: finding count (>= 0), or -1 on error (invalid handle).
%foreign "C:vexometer_finding_count,libvexometer_ffi"
export
vexometer_finding_count : Int -> PrimIO Int

||| Get the total number of metric categories (always 10).
||| This is a constant function useful for FFI consumers that need
||| to know the array size for metric iteration.
%foreign "C:vexometer_metric_count,libvexometer_ffi"
export
vexometer_metric_count : PrimIO Int
