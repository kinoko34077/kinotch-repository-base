# Current State

Last verified: 2026-09-22 — KiNoTch. Repository Base v0.2 complete

## Implemented

- Base / Project physical boundary
- Base自身のREADME、Project Manifest、SPEC、CURRENT_STATE
- Common AGENTS and fixed read order
- knt command router with doctor, verify, base-check, and base-refresh
- Manifest, Action Registry, Surface Registry, Error, Result, Progress, Resource, and Artifact schema validation
- Profile existence and Profile / Surface / Runtime module diagnostics
- Manifest path and command cwd diagnostics
- Strict Base hash index and deterministic refresh
- Base self-test runner with 15 passing cases
- Base and Runtime Meta under .kinotch/meta/
- New Repository templates under .kinotch/templates/project/
- Runtime Contractの確定済み / Runtime Phase 1候補の区別
- .ai-guidelinesとの責任分離
- PowerShell 7 / Windows PowerShell fallback for Base verification commands

## In progress

- KiNoTch. Runtime implementation has intentionally not started.

## Known issues

- KiNoTch. Runtime implementation does not exist yet by design.
- Runtime module names remain logical declarations until Runtime Phase 1.
- The dependency-free validator implements the JSON Schema keywords used by this Base, not every future JSON Schema keyword.
- The Base smoke command is intentionally unconfigured because Base itself has no production entry point.

## Current constraints

- Runtime packages are not required for Base use.
- Production deploy policy remains project-specific.
- Base-wide Meta belongs under .kinotch/meta/.
- New repositories use .kinotch/templates/project/ as their generation source.

## Next work

1. Create kinotch-runtime v0.1 after this Base gate.
2. Pilot the Runtime first in jev-audit.
3. Add further Surface Packs only after repeated Pilot evidence.

## Verification

- Base hash check: knt base-check
- Repository diagnostics: knt doctor
- Project gate: knt verify
- Smoke entry: knt smoke
- Base self-tests: .kinotch/tests/run-tests.ps1
