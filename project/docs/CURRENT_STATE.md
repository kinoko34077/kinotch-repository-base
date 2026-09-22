# Current State

Last verified: 2026-09-22 — KiNoTch. Repository Base v0.2.1 complete

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
- Base self-test runner with 25 passing cases
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

## Known issues

- Runtime v0.1 exists as a small, provisional Python reference implementation.
- Runtime Execution Contract validation and the first `jev-audit` Pilot are not
  complete yet.
- Runtime module names remain logical declarations until Runtime Phase 1.
- The dependency-free validator implements the JSON Schema keywords used by this Base, not every future JSON Schema keyword.
- `result.schema.json` contains a `$ref` for the future Runtime contract; it is an explicitly excluded definition keyword and is not validated by `knt doctor`.
- The Base smoke command is intentionally unconfigured because Base itself has no production entry point.

## Current constraints

- Runtime packages are not required for Base use.
- Production deploy policy remains project-specific.
- Base-wide Meta belongs under .kinotch/meta/.
- New repositories use .kinotch/templates/project/ as their generation source.

## Next work

1. Validate Runtime v0.1 contracts and keep the reference implementation
   provisional until Pilot evidence exists.
2. Pilot the Runtime first in jev-audit without changing its Audit Core.
3. Add further Surface Packs only after repeated Pilot evidence.

## Verification

- Base hash check: knt base-check
- Repository diagnostics: knt doctor
- Project gate: knt verify
- Smoke entry: knt smoke
- Base self-tests: .kinotch/tests/run-tests.ps1
