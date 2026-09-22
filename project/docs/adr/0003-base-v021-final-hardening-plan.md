# Repository Base v0.2.1 Final Hardening Implementation Plan

> For agentic workers: use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax.

**Goal:** Close the Base v0.2 line by making protected-path indexing deterministic across Windows and Linux, completing the validator subset behavior, and aligning the Base's own registry, documentation, tests, and version.

**Architecture:** Keep the existing PowerShell router, dependency-free validator, and fixture runner. Add one OS-independent repository-relative path normalizer to the Base index script, use it for production indexing and fixture setup, and make validator recursion apply schema-valued `additionalProperties` and exact-cardinality `oneOf`. Do not add Runtime implementation or third-party dependencies.

**Tech Stack:** PowerShell 5.1/7-compatible scripts, JSON Schema subset documents, JSON fixtures, GitHub Actions on Ubuntu, and the existing `knt.cmd` wrapper.

**Spec:** KiNoTch. Repository Base v0.2.1 Final Hardening instruction sheet supplied by the repository owner on 2026-09-22.

## Global Constraints

- Runtime implementation remains out of scope.
- Canonical protected paths use repository-relative `/` separators on every OS.
- The validator supports only `type`, `required`, `properties`, `additionalProperties`, `items`, `oneOf`, `enum`, `const`, `pattern`, `minLength`, and `uniqueItems`, plus schema metadata.
- `additionalProperties` schema objects validate unknown properties; `oneOf` requires exactly one matching candidate.
- Base version changes to `0.2.1` only after all tests and final gates pass.
- Existing CI remains Ubuntu `pwsh`, with doctor before verify.
- Work in the current `main` checkout and push each completed commit.

## Review Focus

- Windows-style and Unix-style absolute paths must normalize to the same canonical relative path.
- Unknown command/path manifest values must be rejected through their schema-valued `additionalProperties` rules.
- A value matching zero or multiple `oneOf` candidates must fail with an identifiable error.
- Base self-tests must not silently pass because production and fixture path logic share an untested Windows-only assumption.
- The final Base index, Surface Registry, CURRENT_STATE, and version must agree after refresh.

## File Map

- Path normalization: `.kinotch/scripts/update-base-index.ps1`, `.kinotch/tests/run-tests.ps1`.
- Schema behavior: `.kinotch/scripts/knt-validation.ps1`, `.kinotch/tests/run-tests.ps1`.
- Validator contract documentation: `.kinotch/README_BASE.md`.
- Base identity/closeout: `project/contracts/surfaces.json`, `project/docs/CURRENT_STATE.md`, `project/docs/INDEX.md`, `AGENTS.md`, `.kinotch/BASE_VERSION`.
- Generated index: `.kinotch/base-files.json`, `.kinotch/FILE_INVENTORY.txt`.

### Task 1: Normalize protected paths across platforms

- [ ] Add explicit Windows-style, Unix-style, no-leading-separator, and slash-only index assertions to the self-test.
- [ ] Run the new tests and observe the expected failures against the current Windows-only implementation.
- [ ] Add `ConvertTo-BaseRelativePath` with separator normalization, root-prefix validation, and canonical `/` output; use it from `Get-BaseProtectedPaths` and the fixture helper.
- [ ] Run the focused and full self-test suites.
- [ ] Refresh the Base index, run `base-check`, commit `fix: normalize Base paths across platforms`, and push.

### Task 2: Complete validator subset semantics

- [ ] Add failing tests for invalid command/path additional properties, valid command string/object values, and an overlapping `oneOf` fixture.
- [ ] Run the new tests and confirm the current validator incorrectly accepts the invalid/overlapping cases.
- [ ] Apply schema-valued `additionalProperties` recursively and require exactly one `oneOf` match, with zero/multiple match information in errors.
- [ ] Document the supported keyword subset and the rule that new schema keywords require validator support or explicit exclusion.
- [ ] Run the full self-test suite and the router gates.
- [ ] Commit `fix: complete Base schema subset validation` and push.

### Task 3: Align Base v0.2.1 state and close out

- [ ] Add the Base Surface Registry empty mapping assertion and correct CURRENT_STATE's schema-definition wording.
- [ ] Update stale current-boundary references, set `BASE_VERSION` to `0.2.1`, regenerate the index/inventory, and verify all generated paths.
- [ ] Run Windows gates, self-tests, whitespace checks, and local/remote SHA checks.
- [ ] Confirm the pushed Ubuntu GitHub Actions workflow succeeds.
- [ ] Commit `chore: align Base v0.2.1 repository state` and push.

