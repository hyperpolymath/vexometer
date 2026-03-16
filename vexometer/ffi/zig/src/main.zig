// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Vexometer FFI Implementation
//
// Implements the C-compatible FFI declared in src/abi/Foreign.idr.
// Provides handle-based session management for vexometer analysis.
//
// Architecture: External callers -> Zig FFI (this file) -> Ada analysis engine (via C ABI)
// The Ada analysis routines are linked via C pragma conventions.
// This layer manages session state, handle allocation, and type marshalling.

const std = @import("std");

// =============================================================================
// Metric Categories (must match Ada Metric_Category and Idris2 MetricCategory)
// =============================================================================

/// The 10 irritation metric categories.
/// Ordinal values 0-9 match Ada's Metric_Category enumeration.
pub const MetricCategory = enum(u8) {
    temporal_intrusion = 0,
    linguistic_pathology = 1,
    epistemic_failure = 2,
    paternalism = 3,
    telemetry_anxiety = 4,
    interaction_coherence = 5,
    completion_integrity = 6,
    strategic_rigidity = 7,
    scope_fidelity = 8,
    recovery_competence = 9,
};

/// Severity levels for individual findings.
/// Values 0-4 match Ada's Severity_Level enumeration.
pub const SeverityLevel = enum(u8) {
    none = 0,
    low = 1,
    medium = 2,
    high = 3,
    critical = 4,
};

// =============================================================================
// FFI Struct Types (C-compatible extern structs)
// =============================================================================

/// A single irritation finding detected during analysis.
/// Layout must match Ada's Finding record (C convention) and Idris2 FindingFFI.
pub const FindingFFI = extern struct {
    category: u8, // MetricCategory ordinal (0-9)
    severity: u8, // SeverityLevel ordinal (0-4)
    location: u32, // Character offset in analysed text
    length: u32, // Match length in characters
    confidence: u32, // Fixed-point millionths (0-1000000)
};

/// Computed score for a single metric category.
/// Layout must match Idris2 MetricResultFFI.
pub const MetricResultFFI = extern struct {
    category: u8, // MetricCategory ordinal (0-9)
    value: u32, // Score as millionths (0-1000000)
    confidence: u32, // Confidence as millionths
    sample_size: u32, // Number of contributing findings
};

// =============================================================================
// Session Handle Management
// =============================================================================

/// Internal session data associated with each handle.
/// Stores analysis state between init and free.
const HandleData = struct {
    findings: std.ArrayList(FindingFFI),
    metrics: [10]MetricResultFFI,
    overall_isa: u32,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) HandleData {
        var metrics: [10]MetricResultFFI = undefined;
        for (&metrics, 0..) |*m, i| {
            m.* = MetricResultFFI{
                .category = @intCast(i),
                .value = 0,
                .confidence = 0,
                .sample_size = 0,
            };
        }
        return HandleData{
            .findings = std.ArrayList(FindingFFI).init(allocator),
            .metrics = metrics,
            .overall_isa = 0,
            .allocator = allocator,
        };
    }

    fn deinit(self: *HandleData) void {
        self.findings.deinit();
    }
};

/// Global handle registry. Maps integer handles to session data.
/// Uses page_allocator for simplicity in FFI context (no arena needed).
var handles: std.AutoHashMap(i32, *HandleData) = std.AutoHashMap(i32, *HandleData).init(std.heap.page_allocator);
var next_handle: i32 = 1;

// =============================================================================
// Exported FFI Functions
// =============================================================================

/// Initialise a new vexometer analysis session.
/// Returns a positive handle on success, -1 on allocation failure.
export fn vexometer_init() callconv(.C) i32 {
    const allocator = std.heap.page_allocator;
    const data = allocator.create(HandleData) catch return -1;
    data.* = HandleData.init(allocator);

    const handle = next_handle;
    next_handle += 1;

    handles.put(handle, data) catch {
        data.deinit();
        allocator.destroy(data);
        return -1;
    };
    return handle;
}

/// Free a vexometer analysis session and all associated resources.
/// Safe to call with invalid handles (no-op).
export fn vexometer_free(handle: i32) callconv(.C) void {
    if (handles.fetchRemove(handle)) |kv| {
        kv.value.deinit();
        std.heap.page_allocator.destroy(kv.value);
    }
}

/// Get the total number of metric categories (always 10).
/// Useful for FFI consumers iterating over category scores.
export fn vexometer_metric_count() callconv(.C) i32 {
    return 10;
}

/// Analyse a prompt-response pair for irritation patterns.
/// In production, this calls into Ada analysis routines via C ABI bridge.
/// Currently a stub that validates the handle and returns 0 findings.
///
/// Parameters:
///   handle    - Session handle from vexometer_init
///   _prompt   - User's prompt text (null-terminated)
///   _response - AI assistant's response text (null-terminated)
///
/// Returns: number of findings detected, or -1 on error.
export fn vexometer_analyze(handle: i32, _prompt: [*:0]const u8, _response: [*:0]const u8) callconv(.C) i32 {
    _ = handles.get(handle) orelse return -1;
    // In production: call Ada analysis routines via C ABI bridge.
    // Ada exports Calculate_ISA, Calculate_Category_Scores etc. via
    // pragma Export (C, ...) and the linker resolves them at build time.
    //
    // The Ada implementation performs:
    //   1. Pattern matching against data/patterns/*.json definitions
    //   2. Category score calculation with configurable weights
    //   3. ISA aggregation across all 10 dimensions
    //
    // For now, return 0 findings (stub).
    return 0;
}

/// Get the overall ISA score for a session.
/// Returns ISA * 1000 (fixed-point), or -1 on error.
export fn vexometer_get_isa_score(handle: i32) callconv(.C) i32 {
    const data = handles.get(handle) orelse return -1;
    return @intCast(data.overall_isa);
}

/// Get the score for a specific metric category.
/// Parameters:
///   handle   - Session handle
///   category - MetricCategory ordinal (0-9)
/// Returns: category score * 1000, or -1 on error.
export fn vexometer_get_category_score(handle: i32, category: i32) callconv(.C) i32 {
    const data = handles.get(handle) orelse return -1;
    if (category < 0 or category >= 10) return -1;
    const idx: usize = @intCast(category);
    return @intCast(data.metrics[idx].value);
}

/// Get the number of findings detected in the current session.
/// Returns finding count (>= 0), or -1 on error.
export fn vexometer_finding_count(handle: i32) callconv(.C) i32 {
    const data = handles.get(handle) orelse return -1;
    return @intCast(data.findings.items.len);
}

// =============================================================================
// Tests
// =============================================================================

test "metric category enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(MetricCategory.temporal_intrusion));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(MetricCategory.telemetry_anxiety));
    try std.testing.expectEqual(@as(u8, 9), @intFromEnum(MetricCategory.recovery_competence));
}

test "severity level enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(SeverityLevel.none));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(SeverityLevel.critical));
}

test "FindingFFI struct size" {
    // With extern struct padding: u8(1) + u8(1) + pad(2) + u32(4) + u32(4) + u32(4) = 16
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(FindingFFI));
}

test "MetricResultFFI struct size" {
    // With extern struct padding: u8(1) + pad(3) + u32(4) + u32(4) + u32(4) = 16
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(MetricResultFFI));
}

test "init and free lifecycle" {
    const h = vexometer_init();
    try std.testing.expect(h > 0);
    vexometer_free(h);
}

test "double free is safe" {
    const h = vexometer_init();
    vexometer_free(h);
    vexometer_free(h); // Should not crash
}

test "free invalid handle is safe" {
    vexometer_free(-1); // Should not crash
    vexometer_free(0); // Should not crash
    vexometer_free(999999); // Should not crash
}

test "metric count returns 10" {
    try std.testing.expectEqual(@as(i32, 10), vexometer_metric_count());
}

test "finding count on new session is 0" {
    const h = vexometer_init();
    defer vexometer_free(h);
    try std.testing.expectEqual(@as(i32, 0), vexometer_finding_count(h));
}

test "finding count on invalid handle returns -1" {
    try std.testing.expectEqual(@as(i32, -1), vexometer_finding_count(-1));
}

test "isa score on new session is 0" {
    const h = vexometer_init();
    defer vexometer_free(h);
    try std.testing.expectEqual(@as(i32, 0), vexometer_get_isa_score(h));
}

test "isa score on invalid handle returns -1" {
    try std.testing.expectEqual(@as(i32, -1), vexometer_get_isa_score(-1));
}

test "category score on new session is 0" {
    const h = vexometer_init();
    defer vexometer_free(h);
    var cat: i32 = 0;
    while (cat < 10) : (cat += 1) {
        try std.testing.expectEqual(@as(i32, 0), vexometer_get_category_score(h, cat));
    }
}

test "category score out of range returns -1" {
    const h = vexometer_init();
    defer vexometer_free(h);
    try std.testing.expectEqual(@as(i32, -1), vexometer_get_category_score(h, -1));
    try std.testing.expectEqual(@as(i32, -1), vexometer_get_category_score(h, 10));
    try std.testing.expectEqual(@as(i32, -1), vexometer_get_category_score(h, 100));
}

test "analyze stub returns 0 findings" {
    const h = vexometer_init();
    defer vexometer_free(h);
    const result = vexometer_analyze(h, "test prompt", "test response");
    try std.testing.expectEqual(@as(i32, 0), result);
}

test "analyze with invalid handle returns -1" {
    const result = vexometer_analyze(-1, "test", "test");
    try std.testing.expectEqual(@as(i32, -1), result);
}

test "multiple independent sessions" {
    const h1 = vexometer_init();
    const h2 = vexometer_init();
    try std.testing.expect(h1 != h2);
    try std.testing.expect(h1 > 0);
    try std.testing.expect(h2 > 0);
    vexometer_free(h1);
    vexometer_free(h2);
}
