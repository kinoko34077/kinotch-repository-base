# Current State

Last verified: Base v0.2 implementation in progress

## Implemented

- Base / Project physical boundary
- Common AGENTS and fixed read order
- knt command router with doctor, verify, and base-check entry points
- Base hash index and shared CI gate
- Manifest, Action, Surface, Result, Error, Progress, Resource, and Artifact schemas
- Profile declarations
- Base and Runtime Meta documents
- Base v0.2 design ADR and implementation plan

## In progress

- Base v0.2 self-tests
- Schema validation in knt doctor
- Deterministic Base index refresh
- Template separation and Base identity hardening

## Known issues

- Runtime implementation does not exist yet by design.
- Schema validation and self-test execution are being completed in Base v0.2.

## Current constraints

- Runtime module names are logical declarations until Runtime Phase 1.
- Production deploy policy remains project-specific.
- Base-wide Meta belongs under .kinotch/meta/.

## Next work

1. Complete knt doctor schema, profile, path, and command diagnostics.
2. Complete Base self-test fixtures and command-router coverage.
3. Add and verify deterministic base-refresh.
4. Finish Base v0.2 gate, then create kinotch-runtime v0.1.

## Verification

- Base hash check: knt base-check
- Repository diagnostics: knt doctor
- Project gate: knt verify
- Base self-tests: .kinotch/tests/run-tests.ps1
