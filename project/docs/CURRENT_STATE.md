# Current State

Last verified: 2026-09-23 — KiNoTch. Repository Base v0.2.1 complete

## Implemented

- Base / Project physical boundary
- Base自身のREADME、Project Manifest、SPEC、CURRENT_STATE
- Common AGENTS and fixed read order
- knt command router with doctor, verify, base-check, and base-refresh
- Project Manifest / Action Registry / Surface Registry runtime schema validation
- Error / Result / Progress / Resource / Artifact schema definitions
- Profile existence and Profile / Surface / Runtime module diagnostics
- Manifest path and command cwd diagnostics
- Strict Base hash index and deterministic refresh
- Base self-test runner with 27 passing cases
- Base and Runtime Meta under .kinotch/meta/
- New Repository templates under .kinotch/templates/project/
- Runtime Contractの確定済み / Runtime Phase 1候補の区別
- .ai-guidelinesとの責任分離
- PowerShell 7 / Windows PowerShell fallback for Base verification commands
- Cross-platform repository-relative Base path normalization
- Exact-one `oneOf` and schema-valued `additionalProperties` validation
- Base Schema keyword subset audit

## In progress

- KiNoTch. Runtime v0.1 reference implementation now exists in the separate
  `kinotch-runtime` repository.
- Runtime v0.1 Execution Contract canonicalization is complete in Runtime.
- The first `jev-audit` CLI/MCP Pilot evaluation is complete, with a maturity
  matrix and accepted ADR in Runtime.
- The `kinotch-api` JavaScript design probe is complete: Action ID and error
  semantics are PARTIAL GO through a test-only probe; production Runtime
  integration remains HOLD.
- Runtime Portable Contract semantics are owned by `kinotch-runtime`; Base
  does not duplicate the portable definitions.
- The SynTrail-LM design-only third Pilot evaluation is complete in Runtime:
  Progress is PARTIAL GO, direct CancellationToken mapping is REVISE/REJECTED,
  and Resource / Artifact are HOLD. No SynTrail-LM production code or Rust
  Runtime crate was added.

## Known issues

- Runtime v0.1 exists as a small, provisional Python reference implementation.
- The first `jev-audit` Pilot is complete, but one Python repo is not enough to
  declare a stable cross-repository Contract.
- Runtime module names remain logical declarations until Runtime Phase 1.
- The dependency-free validator implements the JSON Schema keywords used by this Base, not every future JSON Schema keyword.
- Execution schemas under `.kinotch/schemas/` are Base validation compatibility
  copies. The Runtime canonical source is maintained in the separate Runtime
  repository and is not independently edited here.
- The Base smoke command is intentionally unconfigured because Base itself has no production entry point.

## Current constraints

- Runtime packages are not required for Base use.
- Production deploy policy remains project-specific.
- Base-wide Meta belongs under .kinotch/meta/.
- New repositories use .kinotch/templates/project/ as their generation source.

## Next work

1. Keep the `kinotch-api` production boundary unchanged unless a pure
   application operation appears without Response or Context wrapping.
2. Consider `SynTrail-LM` as the next heterogeneous candidate only for
   Progress, Cancellation, Resource, or Artifact where existing behavior gives
   those meanings a real need. The design probe was performed against its
   exact `origin/main` without modifying its dirty user worktree; see the
   Runtime Pilot report for the evidence and per-Contract decisions.
3. Keep Runtime provisional until an additional heterogeneous repository
   validates the same meanings.

## Verification

- Base hash check: knt base-check
- Repository diagnostics: knt doctor
- Project gate: knt verify
- Smoke entry: knt smoke
- Base self-tests: .kinotch/tests/run-tests.ps1
