# Current State

Last verified: 2026-09-23 — self-test 42/42; doctor, base-check, and verify passed locally

## Implemented

- Base / Project physical boundary
- Base自身のREADME、Project Manifest、SPEC、CURRENT_STATE
- Common AGENTS and fixed read order
- knt command router with doctor, verify, base-check, and base-refresh
- Project Manifest / Action Registry / Surface Registry runtime schema validation
- Error / Result / Progress / Resource / Artifact schema definitions
- Profile existence and Profile / Surface contradiction diagnostics
- Manifest path and command cwd diagnostics
- Strict Base hash index and deterministic refresh
- Base self-test runner with 42 passing cases
- Base and Runtime Meta under .kinotch/meta/
- New Repository templates under .kinotch/templates/project/
- Runtime Contractの確定済み / Runtime Phase 1候補の区別
- .ai-guidelinesとの責任分離
- PowerShell 7 / Windows PowerShell fallback for Base verification commands
- Cross-platform repository-relative Base path normalization
- Exact-one `oneOf` and schema-valued `additionalProperties` validation
- Base Schema keyword subset audit
- Machine-readable Surface / Tool Default Catalog and Catalog schema validation
- `knt init` support for all eight Surface Profiles and repeated Tool Defaults
- Surface Profile selection no longer injects Runtime modules; new templates start with an empty module list
- `knt migrate` catalog-driven dry-run / explicit apply with `OVERRIDE` and `DISABLED` preservation
- Default implementation templates for `ci-test`, `pwa`, `generated-integrity`, and `file-io`
- Surface Default helpers for `cli`, `windows`, `mcp`, and `api`
- `knt verify` integration for selected PWA and generated-integrity checks
- Manifest-less read-only `knt migrate` repository-shape probe using package, Cargo,
  Python, workflow, and web-asset markers
- Explicit `knt migrate --apply` materialization of missing safe Default helpers

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
- The fourth `standby-display` and fifth `dev_agent` design probes are also
  complete in Runtime. Generated artifact/hash integrity remains Project
  tooling; AgentBackend remains Agent-owned. Only a narrow artifact-reference
  meaning is a provisional PARTIAL GO candidate. No Surface Pack or production
  integration was added.
- Default-first standardization has completed the safe Phase 3B implementation
  slice: low-risk, removable Surface and Tool conveniences have catalog entries
  and selected implementations. Phase 4 canary adoption review is next; no
  existing Project has been modified.
- The canonical four-layer policy is `.kinotch/meta/06_DEFAULT_FIRST_STANDARD.md`.
- The Default Catalog is `.kinotch/defaults/catalog.json`; it is the single
  source for supported Surface / Tool Default identifiers and aliases.
- A read-only local/GitHub adoption classification is recorded in
  `project/docs/DEFAULT_ROLLOUT_DRY_RUN.md`; no existing Project was changed.
- `knt init` now generates a safe multi-profile Project Overlay, and `knt migrate`
  reports Default Pack candidates by default and applies them only with explicit
  `--apply`, preserving existing `OVERRIDE` / `DISABLED` states.

## Known issues

- Runtime v0.1 exists as a small, provisional Python reference implementation.
- The first `jev-audit` Pilot is complete, but one Python repo is not enough to
  declare a stable cross-repository Contract.
- Runtime module declarations are explicit Project data; selecting a Surface
  Profile does not imply or inject Runtime packages.
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

1. Run repository-local canary adoption reviews by dry-run first and preserve
   existing `OVERRIDE` / `DISABLED` implementations.
2. Apply a Default only after an active Project decision and its repository-local
   verification; do not bulk-rewrite existing repositories.
3. Keep Default Pack behavior removable and Project-owned; do not add Domain
   behavior or a universal Surface library.
4. Keep the `kinotch-api` production boundary unchanged unless a pure
   application operation appears without Response or Context wrapping.
5. Keep Runtime provisional until additional heterogeneous repositories
   validate the same Portable meanings.
6. Do not add Runtime modules, Surface Packs, or Domain adapters to Base merely
   because a Default Catalog entry exists.

## Verification

- Base hash check: knt base-check
- Repository diagnostics: knt doctor
- Project gate: knt verify
- Smoke entry: knt smoke
- Base self-tests: .kinotch/tests/run-tests.ps1
