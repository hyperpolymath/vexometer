-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Vexometer ABI Type Definitions
--
-- Defines the Application Binary Interface types for the vexometer
-- Irritation Surface Analyser. These types are shared between the
-- Ada analysis engine (via C pragma conventions) and the Zig FFI layer.
--
-- The 10 irritation metric categories map directly to Ada's Metric_Category
-- enumeration in vexometer-core.ads.

module Vexometer.ABI.Types

import Data.Bits
import Data.Vect

%default total

--------------------------------------------------------------------------------
-- Irritation Metric Categories
--------------------------------------------------------------------------------

||| The 10 irritation metric categories measured by vexometer.
||| Each maps to a specific dimension of AI assistant behaviour.
||| Values 0-9 match the Ada Metric_Category enumeration.
public export
data MetricCategory
    = TemporalIntrusion      -- 0: Response timing annoyances
    | LinguisticPathology    -- 1: Language/phrasing irritants
    | EpistemicFailure       -- 2: Knowledge/reasoning errors
    | Paternalism            -- 3: Condescending behaviour
    | TelemetryAnxiety       -- 4: Privacy/tracking concerns
    | InteractionCoherence   -- 5: Conversation flow breaks
    | CompletionIntegrity    -- 6: Incomplete/truncated output
    | StrategicRigidity      -- 7: Inability to adapt approach
    | ScopeFidelity          -- 8: Scope creep or scope miss
    | RecoveryCompetence     -- 9: Error recovery ability

||| Convert MetricCategory to its C-compatible integer value (0-9)
public export
categoryToInt : MetricCategory -> Bits8
categoryToInt TemporalIntrusion    = 0
categoryToInt LinguisticPathology  = 1
categoryToInt EpistemicFailure     = 2
categoryToInt Paternalism          = 3
categoryToInt TelemetryAnxiety     = 4
categoryToInt InteractionCoherence = 5
categoryToInt CompletionIntegrity  = 6
categoryToInt StrategicRigidity    = 7
categoryToInt ScopeFidelity        = 8
categoryToInt RecoveryCompetence   = 9

||| Total number of metric categories (compile-time constant)
public export
metricCategoryCount : Nat
metricCategoryCount = 10

--------------------------------------------------------------------------------
-- Severity Levels
--------------------------------------------------------------------------------

||| Severity level for individual findings.
||| Values 0-4 match the Ada Severity_Level enumeration.
public export
data SeverityLevel = None | Low | Medium | High | Critical

||| Convert SeverityLevel to its C-compatible integer value (0-4)
public export
severityToInt : SeverityLevel -> Bits8
severityToInt None     = 0
severityToInt Low      = 1
severityToInt Medium   = 2
severityToInt High     = 3
severityToInt Critical = 4

--------------------------------------------------------------------------------
-- FFI Struct Types (C-compatible layout)
--------------------------------------------------------------------------------

||| Finding struct for FFI (C-compatible layout).
||| Matches Ada's Finding record via C pragma conventions.
|||
||| Layout: category(1) + severity(1) + location(4) + length(4) + confidence(4) = 14 bytes
||| Note: actual C struct may have padding; Zig extern struct handles this.
public export
record FindingFFI where
    constructor MkFindingFFI
    category   : Bits8     -- MetricCategory enum value (0-9)
    severity   : Bits8     -- SeverityLevel enum value (0-4)
    location   : Bits32    -- Character offset in analysed text
    length     : Bits32    -- Match length in characters
    confidence : Bits32    -- Fixed-point 0.000-1.000 as millionths (0-1000000)

||| Metric result for FFI.
||| Represents the computed score for a single irritation dimension.
|||
||| Layout: category(1) + value(4) + confidence(4) + sample_size(4) = 13 bytes
public export
record MetricResultFFI where
    constructor MkMetricResultFFI
    category    : Bits8    -- MetricCategory enum value (0-9)
    value       : Bits32   -- Score as millionths (0-1000000 maps to 0.0-1.0)
    confidence  : Bits32   -- Confidence as millionths
    sample_size : Bits32   -- Number of findings contributing to this metric

||| ISA Report: aggregated results across all 10 metric categories.
||| Contains one MetricResultFFI per category plus an overall ISA score.
public export
record ISAReportFFI where
    constructor MkISAReportFFI
    metrics     : Vect 10 MetricResultFFI  -- One result per category
    overall_isa : Bits32                   -- Overall ISA score * 1000

--------------------------------------------------------------------------------
-- Size Proofs
--------------------------------------------------------------------------------

||| Minimum packed size of FindingFFI (no padding).
||| 1 (category) + 1 (severity) + 4 (location) + 4 (length) + 4 (confidence) = 14 bytes
export
findingFFIPackedSize : Nat
findingFFIPackedSize = 14

||| Minimum packed size of MetricResultFFI (no padding).
||| 1 (category) + 4 (value) + 4 (confidence) + 4 (sample_size) = 13 bytes
export
metricResultFFIPackedSize : Nat
metricResultFFIPackedSize = 13

||| Category value is always in range 0-9
export
categoryInRange : (c : MetricCategory) -> So (categoryToInt c < 10)
categoryInRange TemporalIntrusion    = Oh
categoryInRange LinguisticPathology  = Oh
categoryInRange EpistemicFailure     = Oh
categoryInRange Paternalism          = Oh
categoryInRange TelemetryAnxiety     = Oh
categoryInRange InteractionCoherence = Oh
categoryInRange CompletionIntegrity  = Oh
categoryInRange StrategicRigidity    = Oh
categoryInRange ScopeFidelity        = Oh
categoryInRange RecoveryCompetence   = Oh

||| Severity value is always in range 0-4
export
severityInRange : (s : SeverityLevel) -> So (severityToInt s < 5)
severityInRange None     = Oh
severityInRange Low      = Oh
severityInRange Medium   = Oh
severityInRange High     = Oh
severityInRange Critical = Oh
