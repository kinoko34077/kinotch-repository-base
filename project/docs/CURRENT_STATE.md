# Current State

Base version: `0.3.9`

Last verified: 2026-09-24 — self-test 74/74; doctor, base-check, and verify passed locally after the Base v0.3.9 index refresh

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
- Base self-test runner with 71 passing cases
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
- Phase 4 Canary shape validation with existing-equivalent `OVERRIDE` detection
- Phase 4A read-only verification completed; Phase 4B adoption has now been
  completed for eight clean Canaries: `jev-audit`, `kinotch-api`,
  `lyric_reader_page`, `weather-widget`, `memory-game`,
  `Structured-Cell-Automaton`, `2bit-cell-automaton`, and `colony-ai`
- `refil-viewer` has a repository-local Base v0.3.8 preparation commit, but its
  existing Vite build currently fails on a duplicate `pageIndex` declaration;
  it is not counted as a clean Canary adoption
- Default implementation templates for `ci-test`, `pwa`, `generated-integrity`, and `file-io`
- Surface Default helpers for `cli`, `windows`, `mcp`, and `api`
- CLI Surface Kit common option parsing, stdout/stderr helpers, generic result rendering, and exit handling; Project-specific arguments remain untouched
- Windows Surface Kit path/drop normalization, lazy native file/folder/save pickers,
  progress state, cooperative cancel flag, Explorer/clipboard, and error-dialog boundary
- MCP Surface Kit boundary descriptor for input validation, working-directory and
  resource-path resolution, diagnostics, generic error conversion, and host-owned dispatch
- `knt verify` integration for selected PWA and generated-integrity checks
- Manifest-less read-only `knt migrate` repository-shape probe using package, Cargo,
  Python, workflow, and web-asset markers
- Shape Probe filters Tool candidates through detected Surface compatibility before
  presenting a Default candidate
- Explicit `knt migrate --apply` materialization of missing safe Default helpers
- `knt verify` remains an L1 Hard Base command; it is not a Tool Default and is not disabled by Default state
- `ci-test` workflow generation with doctor → setup → verify, separate from the Base repository workflow
- Generated-integrity source and artifact SHA-256 stale checks
- Relative-base-path-safe PWA defaults and explicit UTF-8 text-only file-io helper scope
- Existing-surface compatibility validation for explicit `knt migrate --default` selections
- Windows PowerShell 5.1-compatible Windows helper host detection
- Strict Surface/Tool compatibility validation in init, migrate, and doctor
- External `-BaseOverride` restricted to read-only shape probing; writes require a repository-local `.kinotch/`
- Structured `exec` / `args` Project commands with safe forwarded-argument handling; legacy commands reject forwarded arguments
- Project command output is captured separately from its native exit code so `knt verify` propagates failing fallback commands
- Project-root containment checks for generated-integrity and file-io helpers
- Default Catalog semantic validation, Surface `OVERRIDE` detection, verification-aware CI detection, and conflict-to-`OVERRIDE` materialization
- Atomic Default materialization with MISSING / IDENTICAL / CONFLICT preflight planning
- OS-aware Project-root path containment: case-insensitive on Windows and case-sensitive on Unix-like systems
- Explicit migrate Surface/Manifest consistency checks and doctor rejection of disabled `DEFAULT` Surfaces
- Common CI runs Project setup before verification, and shape probing does not classify Wrangler-only Web projects as API
- Common Python build metadata such as `*.egg-info/` is ignored by the Base root hygiene rules
- Common Cloudflare build outputs such as `.wrangler/` and `artifacts/` are ignored by the Base root hygiene rules
- Common Python audit/cache and browser test-report outputs are ignored by the Base root hygiene rules

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
- Default-first standardization completed the safe Phase 3B implementation
  slice, Phase 4A read-only validation, Phase 4B adoption-safety hardening,
  and the Phase 4C adoption review. Eight repositories remain recorded as
  cleanly adopted at Base v0.3.8: `jev-audit`, `kinotch-api`, `lyric_reader_page`,
  `weather-widget`, `memory-game`, `Structured-Cell-Automaton`,
  `2bit-cell-automaton`, and `colony-ai`; existing
  CLI/MCP/API/generated/browser/PWA/Streamlit behavior remains Project-owned
  as `OVERRIDE`.
- Base v0.3.9 is the current maintenance release; existing adopted repositories
  are synchronized only during their normal maintenance cycle.
- Surface Default Kit expansion is a Phase 5 Base feature slice; CLI, Windows,
  and MCP Kits are implemented, while the API Kit expansion remains next.
- `refil-viewer` remains `STAGED`: its Base v0.3.8 files pass doctor and
  base-check, while its existing Vite source still fails on a duplicate
  `pageIndex` declaration. This is a Project bug and is not hidden or fixed by
  Base adoption.
- `standby-display` remains `STAGED`: its PWA and generated-asset boundaries
  are existing `OVERRIDE` implementations, but its root hygiene files differ
  from Base and require an explicit merge decision before adoption.
- `SynTrail-LM` remains `STAGED` for a future clean-tree decision; its
  user-owned dirty files were not modified. `dev_agent` and `IDS-Composit` are
  `NOT_ADOPTED` pending explicit repository-local Base decisions, and
  `srt2subtitle` remains `N/A` because only its GitHub tree was inspected.
- Phase 4C is complete as an adoption decision phase, not as a requirement to
  install Base into every repository. The current position is Phase 5,
  gradual repository adoption and maintenance.
- The canonical four-layer policy is `.kinotch/meta/06_DEFAULT_FIRST_STANDARD.md`.
- The Default Catalog is `.kinotch/defaults/catalog.json`; it is the single
  source for supported Surface / Tool Default identifiers and aliases.
- The Phase 4A read-only classification, Phase 4B adoption record, and Phase
  4C operation state are kept in `project/docs/DEFAULT_ROLLOUT_DRY_RUN.md`.
  That table records adoption state, not Default maturity. No bulk migration
  is planned.
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
- The generated file-io helper is intentionally UTF-8 text-only; binary format
  handling remains Project-owned through the callback boundary.
- Symlink and junction resolution is not fully guaranteed by the text path
  containment helpers; this remains a documented platform boundary.

## Current constraints

- Runtime packages are not required for Base use.
- Production deploy policy remains project-specific.
- Base-wide Meta belongs under .kinotch/meta/.
- New repositories use .kinotch/templates/project/ as their generation source.
- Base v0.3.9 remains the current Phase 5 maintenance baseline while the
  Surface Default Kit feature slice is evaluated; Runtime semantics remain
  unchanged.

## Next work

1. Complete the MCP and API Surface Kit slices without changing
   Runtime semantics or adding fine-grained Catalog entries.
2. Run `doctor`, `base-check`, and the existing Project verification after
   each Surface Kit slice.
3. Preserve existing `OVERRIDE` / `DISABLED` implementations and do not
   bulk-rewrite existing repositories.
4. Keep Default behavior removable and Project-owned; do not add Domain
   behavior or a universal Surface library.
5. Keep Runtime provisional until additional heterogeneous repositories
   validate the same Portable meanings.
6. Do not add Runtime modules or Domain adapters to Base merely because a
   Surface Kit helper exists.
7. After the feature slice, return to normal Phase 5 maintenance and do not
   run a periodic full-repository audit or bulk synchronization.
8. Treat `refil-viewer`, `standby-display`, and `SynTrail-LM` as STAGED, and
   keep `dev_agent` / `IDS-Composit` as NOT_ADOPTED until active work creates a
   concrete adoption reason.

## Verification

- Base hash check: knt base-check
- Repository diagnostics: knt doctor
- Project gate: knt verify
- Smoke entry: knt smoke
- Base self-tests: .kinotch/tests/run-tests.ps1
