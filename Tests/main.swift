//
//  main.swift
//  Minimal test runner for Renamy/Core (no XCTest target needed).
//  Run with scripts/test.sh.
//

import Foundation

var passed = 0, failed = 0, expectedFailures = 0, unexpectedPasses = 0

/// Checks a condition. `knownIssue` marks a case that is expected to fail until it is fixed:
/// it is reported but does not fail the run; if it starts passing, the run fails so the mark gets removed.
func check(_ condition: Bool, _ name: String, knownIssue: String? = nil) {
    switch (condition, knownIssue) {
    case (true, nil):
        passed += 1
    case (false, nil):
        failed += 1; print("FAIL  \(name)")
    case (false, let issue?):
        expectedFailures += 1; print("XFAIL \(name) — \(issue)")
    case (true, let issue?):
        unexpectedPasses += 1; print("XPASS \(name) — remove known issue: \(issue)")
    }
}

runFileNameParserTests()
runNamingTests()

print("\n\(passed) passed, \(failed) failed, \(expectedFailures) known issues, \(unexpectedPasses) unexpected passes")
exit(failed == 0 && unexpectedPasses == 0 ? 0 : 1)
