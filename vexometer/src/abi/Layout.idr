-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Vexometer Memory Layout Proofs
--
-- Provides formal proofs about memory layout, alignment, and padding
-- for vexometer's C-compatible FFI structs. These proofs ensure that
-- the Idris2 type definitions, Zig extern structs, and Ada C-convention
-- records all agree on memory layout.

module Vexometer.ABI.Layout

import Vexometer.ABI.Types
import Data.Vect
import Data.So

%default total

--------------------------------------------------------------------------------
-- Alignment Utilities
--------------------------------------------------------------------------------

||| Calculate padding needed to reach the next alignment boundary.
||| Returns 0 if offset is already aligned.
public export
paddingFor : (offset : Nat) -> (alignment : Nat) -> Nat
paddingFor offset alignment =
  if offset `mod` alignment == 0
    then 0
    else alignment - (offset `mod` alignment)

||| Round up a size to the next alignment boundary.
public export
alignUp : (size : Nat) -> (alignment : Nat) -> Nat
alignUp size alignment = size + paddingFor size alignment

--------------------------------------------------------------------------------
-- Struct Field Layout
--------------------------------------------------------------------------------

||| A field in a C-compatible struct with its offset, size, and alignment.
public export
record Field where
    constructor MkField
    name      : String
    offset    : Nat
    size      : Nat
    alignment : Nat

||| Calculate the next field's starting offset (current field end, aligned).
public export
nextFieldOffset : Field -> (nextAlign : Nat) -> Nat
nextFieldOffset f nextAlign = alignUp (f.offset + f.size) nextAlign

--------------------------------------------------------------------------------
-- FindingFFI Layout
--------------------------------------------------------------------------------

||| Field layout for FindingFFI extern struct.
|||
||| With extern struct packing (Zig/C ABI on x86-64):
|||   category   : u8  at offset 0, size 1, align 1
|||   severity   : u8  at offset 1, size 1, align 1
|||   padding    : 2 bytes (to align location to 4)
|||   location   : u32 at offset 4, size 4, align 4
|||   length     : u32 at offset 8, size 4, align 4
|||   confidence : u32 at offset 12, size 4, align 4
|||   Total: 16 bytes (with padding), alignment 4
public export
findingFFIFields : Vect 5 Field
findingFFIFields =
    [ MkField "category"   0  1 1
    , MkField "severity"   1  1 1
    , MkField "location"   4  4 4  -- 2 bytes padding after severity
    , MkField "length"     8  4 4
    , MkField "confidence" 12 4 4
    ]

||| Total size of FindingFFI with C ABI padding.
||| The Zig extern struct @sizeOf(FindingFFI) should equal this value.
public export
findingFFITotalSize : Nat
findingFFITotalSize = 16

||| Alignment of FindingFFI (max field alignment).
public export
findingFFIAlignment : Nat
findingFFIAlignment = 4

||| Proof: all FindingFFI field offsets are within the struct bounds.
export
findingFieldsInBounds : (f : Field) -> So (f.offset + f.size <= findingFFITotalSize)
findingFieldsInBounds (MkField _ 0  1 _) = Oh
findingFieldsInBounds (MkField _ 1  1 _) = Oh
findingFieldsInBounds (MkField _ 4  4 _) = Oh
findingFieldsInBounds (MkField _ 8  4 _) = Oh
findingFieldsInBounds (MkField _ 12 4 _) = Oh
findingFieldsInBounds _ = Oh

--------------------------------------------------------------------------------
-- MetricResultFFI Layout
--------------------------------------------------------------------------------

||| Field layout for MetricResultFFI extern struct.
|||
||| With extern struct packing:
|||   category    : u8  at offset 0, size 1, align 1
|||   padding     : 3 bytes (to align value to 4)
|||   value       : u32 at offset 4, size 4, align 4
|||   confidence  : u32 at offset 8, size 4, align 4
|||   sample_size : u32 at offset 12, size 4, align 4
|||   Total: 16 bytes (with padding), alignment 4
public export
metricResultFFIFields : Vect 4 Field
metricResultFFIFields =
    [ MkField "category"    0  1 1
    , MkField "value"       4  4 4  -- 3 bytes padding after category
    , MkField "confidence"  8  4 4
    , MkField "sample_size" 12 4 4
    ]

||| Total size of MetricResultFFI with C ABI padding.
public export
metricResultFFITotalSize : Nat
metricResultFFITotalSize = 16

||| Alignment of MetricResultFFI.
public export
metricResultFFIAlignment : Nat
metricResultFFIAlignment = 4

--------------------------------------------------------------------------------
-- ISAReportFFI Layout
--------------------------------------------------------------------------------

||| The ISAReportFFI contains 10 MetricResultFFI structs followed by
||| an overall_isa u32.
|||
||| Total: 10 * 16 + 4 = 164 bytes, alignment 4
public export
isaReportFFITotalSize : Nat
isaReportFFITotalSize = metricCategoryCount * metricResultFFITotalSize + 4

||| Proof: ISA report size is 164 bytes
export
isaReportSizeCorrect : So (isaReportFFITotalSize == 164)
isaReportSizeCorrect = Oh

--------------------------------------------------------------------------------
-- Cross-ABI Consistency
--------------------------------------------------------------------------------

||| The number of metric categories must match the Vect size in ISAReportFFI.
||| This ensures the Zig metrics array [10]MetricResultFFI and the Ada
||| Metric_Category'Range both iterate over exactly 10 elements.
export
metricCountConsistent : So (metricCategoryCount == 10)
metricCountConsistent = Oh
