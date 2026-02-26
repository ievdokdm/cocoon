# Implementation Plan: Public Presubmit APIs

This plan outlines the steps to refactor the request handler hierarchy and expose specific presubmit APIs publicly.

## Phase 1: Refactor Request Handler Hierarchy
This phase focuses on introducing the `PublicApiRequestHandler` and refactoring `ApiRequestHandler` to inherit from it.

- [ ] Task: Create `PublicApiRequestHandler`
    - [ ] Create `app_dart/lib/src/request_handling/public_api_request_handler.dart`.
    - [ ] Define `PublicApiRequestHandler` as an abstract base class extending `RequestHandler`.
    - [ ] Move `checkRequiredParameters` and `checkRequiredQueryParameters` from `ApiRequestHandler` to `PublicApiRequestHandler`.
- [ ] Task: Refactor `ApiRequestHandler`
    - [ ] Update `app_dart/lib/src/request_handling/api_request_handler.dart` to extend `PublicApiRequestHandler`.
    - [ ] Remove the moved methods from `ApiRequestHandler`.
- [ ] Task: Verify Base Class Refactoring
    - [ ] Run existing tests for `ApiRequestHandler` and `RequestHandler` to ensure no regressions.
    - [ ] Command: `dart test app_dart/test/request_handling/api_request_handler_test.dart`
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Refactor Request Handler Hierarchy' (Protocol in workflow.md)

## Phase 2: Expose Target APIs Publicly
This phase transitions the specified handlers to `PublicApiRequestHandler`.

- [ ] Task: Refactor `GetPresubmitChecks`
    - [ ] Update `app_dart/lib/src/request_handlers/get_presubmit_checks.dart` to extend `PublicApiRequestHandler`.
    - [ ] Remove `authenticationProvider` from the constructor and `super` call.
    - [ ] Update tests in `app_dart/test/request_handlers/get_presubmit_checks_test.dart` to reflect constructor changes.
- [ ] Task: Refactor `GetPresubmitGuardSummaries`
    - [ ] Update `app_dart/lib/src/request_handlers/get_presubmit_guard_summaries.dart` to extend `PublicApiRequestHandler`.
    - [ ] Remove `authenticationProvider` from the constructor and `super` call.
    - [ ] Update tests in `app_dart/test/request_handlers/get_presubmit_guard_summaries_test.dart` to reflect constructor changes.
- [ ] Task: Refactor `GetPresubmitGuard`
    - [ ] Update `app_dart/lib/src/request_handlers/get_presubmit_guard.dart` to extend `PublicApiRequestHandler`.
    - [ ] Remove `authenticationProvider` from the constructor and `super` call.
    - [ ] Update tests in `app_dart/test/request_handlers/get_presubmit_guard_test.dart` to reflect constructor changes.
- [ ] Task: Verify Public Access
    - [ ] Add/Update tests for each handler to verify they return successful responses even when no authentication is provided.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Expose Target APIs Publicly' (Protocol in workflow.md)

## Phase 3: Quality Assurance & Cleanup
Final checks for code quality and standards.

- [ ] Task: Run Code Quality Checks
    - [ ] Execute `dart format --set-exit-if-changed .` in `app_dart`.
    - [ ] Execute `dart analyze --fatal-infos .` in `app_dart`.
- [ ] Task: Final Test Suite Execution
    - [ ] Run all tests in `app_dart` to ensure overall system stability.
    - [ ] Command: `dart test app_dart/test`
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Quality Assurance & Cleanup' (Protocol in workflow.md)
