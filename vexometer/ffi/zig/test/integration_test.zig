// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Vexometer FFI Integration Tests
//
// These tests verify that the Zig FFI correctly implements the interface
// declared in src/abi/Foreign.idr. They test the exported C-ABI functions
// as an external consumer would use them.

const std = @import("std");
const testing = std.testing;

// Import the FFI functions via C linkage (as an external consumer would)
extern fn vexometer_init() callconv(.C) i32;
extern fn vexometer_free(handle: i32) callconv(.C) void;
extern fn vexometer_metric_count() callconv(.C) i32;
extern fn vexometer_analyze(handle: i32, prompt: [*:0]const u8, response: [*:0]const u8) callconv(.C) i32;
extern fn vexometer_get_isa_score(handle: i32) callconv(.C) i32;
extern fn vexometer_get_category_score(handle: i32, category: i32) callconv(.C) i32;
extern fn vexometer_finding_count(handle: i32) callconv(.C) i32;

// =============================================================================
// Lifecycle Tests
// =============================================================================

test "integration: create and destroy session" {
    const handle = vexometer_init();
    try testing.expect(handle > 0);
    vexometer_free(handle);
}

test "integration: multiple sessions are independent" {
    const h1 = vexometer_init();
    try testing.expect(h1 > 0);

    const h2 = vexometer_init();
    try testing.expect(h2 > 0);
    try testing.expect(h1 != h2);

    // Freeing h1 should not affect h2
    vexometer_free(h1);

    // h2 should still be valid
    const count = vexometer_finding_count(h2);
    try testing.expect(count >= 0);

    vexometer_free(h2);
}

test "integration: free invalid handle does not crash" {
    vexometer_free(-1);
    vexometer_free(0);
    vexometer_free(99999);
}

test "integration: double free does not crash" {
    const handle = vexometer_init();
    vexometer_free(handle);
    vexometer_free(handle);
}

// =============================================================================
// Metric Count Tests
// =============================================================================

test "integration: metric count is always 10" {
    try testing.expectEqual(@as(i32, 10), vexometer_metric_count());
}

// =============================================================================
// Analysis Tests
// =============================================================================

test "integration: analyze with valid session" {
    const handle = vexometer_init();
    defer vexometer_free(handle);

    const result = vexometer_analyze(handle, "What is the weather?", "The weather is sunny today.");
    try testing.expect(result >= 0);
}

test "integration: analyze with invalid handle" {
    const result = vexometer_analyze(-1, "prompt", "response");
    try testing.expectEqual(@as(i32, -1), result);
}

// =============================================================================
// Score Retrieval Tests
// =============================================================================

test "integration: ISA score for new session is zero" {
    const handle = vexometer_init();
    defer vexometer_free(handle);

    const score = vexometer_get_isa_score(handle);
    try testing.expectEqual(@as(i32, 0), score);
}

test "integration: ISA score for invalid handle returns -1" {
    const score = vexometer_get_isa_score(-1);
    try testing.expectEqual(@as(i32, -1), score);
}

test "integration: category scores for new session are all zero" {
    const handle = vexometer_init();
    defer vexometer_free(handle);

    var cat: i32 = 0;
    while (cat < 10) : (cat += 1) {
        const score = vexometer_get_category_score(handle, cat);
        try testing.expectEqual(@as(i32, 0), score);
    }
}

test "integration: category score out of range returns -1" {
    const handle = vexometer_init();
    defer vexometer_free(handle);

    try testing.expectEqual(@as(i32, -1), vexometer_get_category_score(handle, -1));
    try testing.expectEqual(@as(i32, -1), vexometer_get_category_score(handle, 10));
    try testing.expectEqual(@as(i32, -1), vexometer_get_category_score(handle, 255));
}

test "integration: category score for invalid handle returns -1" {
    try testing.expectEqual(@as(i32, -1), vexometer_get_category_score(-1, 0));
}

// =============================================================================
// Finding Count Tests
// =============================================================================

test "integration: finding count for new session is zero" {
    const handle = vexometer_init();
    defer vexometer_free(handle);

    const count = vexometer_finding_count(handle);
    try testing.expectEqual(@as(i32, 0), count);
}

test "integration: finding count for invalid handle returns -1" {
    const count = vexometer_finding_count(-1);
    try testing.expectEqual(@as(i32, -1), count);
}

// =============================================================================
// End-to-End Workflow Test
// =============================================================================

test "integration: full analysis workflow" {
    // 1. Create session
    const handle = vexometer_init();
    try testing.expect(handle > 0);
    defer vexometer_free(handle);

    // 2. Verify initial state
    try testing.expectEqual(@as(i32, 0), vexometer_finding_count(handle));
    try testing.expectEqual(@as(i32, 0), vexometer_get_isa_score(handle));

    // 3. Run analysis (stub returns 0 findings)
    const findings = vexometer_analyze(handle, "Explain quantum computing", "Quantum computing uses qubits.");
    try testing.expect(findings >= 0);

    // 4. Check all 10 categories are accessible
    var cat: i32 = 0;
    while (cat < 10) : (cat += 1) {
        const score = vexometer_get_category_score(handle, cat);
        try testing.expect(score >= 0);
    }
}
