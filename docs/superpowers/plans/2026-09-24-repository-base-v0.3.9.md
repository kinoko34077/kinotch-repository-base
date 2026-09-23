# Repository Base v0.3.9 Phase 5 Maintenance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Default materialization atomic, make Project-root containment OS-aware, and prevent `migrate --apply --profile` from recording a Surface Default that the current Manifest does not enable.

**Architecture:** Keep the existing PowerShell router and dependency-free self-test runner. Split Default materialization into an in-memory per-file plan and a write-only apply phase; centralize path comparison in a Base helper used by file-io and generated-integrity templates; validate explicit migrate Surface selections against the existing Manifest without adding an adoption command.

**Tech Stack:** PowerShell 5.1/7, dependency-free JSON validation, existing `.kinotch/tests/run-tests.ps1` fixtures, SHA-256 file checks.

**Spec:** `C:/Users/kinok/.codex/attachments/7f2bfbfc-0fc4-4a07-a2af-1d2ed617d98d/貼り付けたテキスト.txt`

## Global Constraints

- Do not add a new Default, Runtime Contract, Pilot, maturity state, Surface Pack, or `knt adopt-surface` command.
- Keep Runtime package version `0.1.0`; only synchronize its embedded Base copy after Base `0.3.9` is finalized.
- Keep Phase 5 current; do not reopen Phase 4B/4C.
- `DEFAULT`, `OVERRIDE`, and `DISABLED` remain the only Default states.
- Do not modify `refil-viewer`, `standby-display`, `SynTrail-LM`, or other existing Project repositories in this change.
- Base version changes from `0.3.8` to `0.3.9` only after all regression and gate checks pass.

## Review Focus

- A conflict in the first, middle, or last template file must produce `OVERRIDE` without creating any missing sibling file; owned by Task 1 tests.
- Identical existing files must not be treated as conflicts, and missing siblings must still be created; owned by Task 1 tests.
- Project root itself, `..`, absolute paths, and sibling-prefix paths must be rejected while valid descendants remain accepted; owned by Task 2 tests.
- Windows comparisons must ignore case while Unix comparisons must preserve case; owned by Task 2 tests through the helper's explicit platform parameter and the template scripts.
- Explicit migrate profile selection must warn without writing in dry-run and fail before writing with `--apply` when its Manifest Surface is disabled; doctor must reject the resulting hand-edited `DEFAULT`; owned by Task 3 tests.

### Task 1: Make Default materialization atomic

**Files:**
- Modify: `.kinotch/scripts/knt.ps1` around `Copy-DefaultImplementation`, `Invoke-Init`, and `Invoke-Migrate`.
- Test: `.kinotch/tests/run-tests.ps1` materialization cases.

**Interfaces:**
- Produces `Get-DefaultImplementationPlan(DefaultId, ProjectRoot)` returning internal objects with `relative_path`, `destination`, `template_path`, and `status` (`MISSING`, `IDENTICAL`, or `CONFLICT`).
- Produces `Apply-DefaultImplementationPlan(Plan, DefaultId, Kind, ConflictingDefaults)` which performs no copy when any plan item is `CONFLICT` and records the Default for later `OVERRIDE` state handling.

- [ ] Add failing fixture tests for PWA conflicts at an early, middle, and late template path, asserting no missing PWA file is materialized and the Project-owned conflicting file remains unchanged.
- [ ] Add failing fixture test for identical existing PWA file plus missing siblings, asserting the Default remains `DEFAULT` and only missing files are generated.
- [ ] Run the focused self-test and confirm the new atomicity assertions fail against the current sequential-copy implementation.
- [ ] Implement the plan/apply split; preflight all sorted template files before creating directories or copying files, and emit one concise conflict message plus `OVERRIDE` state.
- [ ] Route both `init` and `migrate --apply` through the same plan/apply functions; preserve existing conflict-state handling and legacy output for identical/missing files.
- [ ] Run the focused self-test again and confirm the atomicity cases pass.
- [ ] Commit as `fix: make Default materialization atomic` after the focused suite is green.

### Task 2: Make Project-root containment OS-aware

**Files:**
- Create: `.kinotch/scripts/path-containment.ps1` with PowerShell 5.1-compatible comparison and containment helpers.
- Modify: `.kinotch/templates/defaults/file-io/tools/file-io.ps1`.
- Modify: `.kinotch/templates/defaults/generated-integrity/tools/check-generated.ps1`.
- Modify: `.kinotch/templates/defaults/generated-integrity/tools/update-generated-integrity.ps1`.
- Modify: `.kinotch/tests/run-tests.ps1` path regression cases.

**Interfaces:**
- `Get-KntPathComparison([bool]$Windows = ($env:OS -eq "Windows_NT"))` returns `OrdinalIgnoreCase` on Windows and `Ordinal` otherwise.
- `Test-KntProjectPathContained(Root, Candidate, [bool]$Windows, [switch]$AllowRoot)` normalizes full paths, rejects root itself unless explicitly allowed, and checks a separator-delimited prefix with the selected comparison.

- [ ] Add failing tests for valid descendants, root rejection, `..`, absolute paths, `C:\repo` versus `C:\repo-other`, and `/tmp/Repo` versus `/tmp/repo/x.txt` under both explicit comparison modes.
- [ ] Run the focused self-test and confirm the Unix case-sensitive and root-boundary assertions fail against the current `OrdinalIgnoreCase` prefix checks.
- [ ] Implement the shared helper with `$env:OS -eq "Windows_NT"` default detection and no symlink/junction resolution.
- [ ] Update file-io check/write paths and generated-integrity check/update paths to use the shared helper and keep existing relative-path rejection.
- [ ] Run the focused self-test and verify both Default families use the same containment behavior.
- [ ] Commit as `fix: respect filesystem case sensitivity in path containment` after the focused suite is green.

### Task 3: Enforce migrate Surface/Manifest consistency

**Files:**
- Modify: `.kinotch/scripts/knt.ps1` in `Get-MigrateProfileEntries` and the doctor Default-state validation.
- Test: `.kinotch/tests/run-tests.ps1` migrate and doctor cases.

**Interfaces:**
- Explicit `migrate --profile` selection checks the selected profile's `compatible_surfaces` against `Get-ManifestSurfaceIds` when a Manifest exists.
- Dry-run emits `NOT ENABLED IN MANIFEST` and remains non-mutating; `--apply` throws before Default state or helper writes.
- Doctor validates `DEFAULT` Surface entries against Manifest surfaces; `OVERRIDE` and `DISABLED` remain exempt.

- [ ] Add failing tests for enabled `cli` apply, disabled `cli` apply rejection without writes, disabled `cli` dry-run warning without writes, and hand-edited `defaults.cli=DEFAULT` doctor failure.
- [ ] Run the focused self-test and confirm the disabled-Surface apply currently writes or proceeds instead of rejecting.
- [ ] Implement the explicit-profile guard and the doctor Surface Default check without adding Manifest mutation.
- [ ] Run the focused self-test and verify existing Tool compatibility and profile behavior remain green.
- [ ] Commit as `fix: enforce Surface Default manifest consistency` after the focused suite is green.

### Task 4: Release Base v0.3.9 and synchronize Runtime

**Files:**
- Modify: `.kinotch/BASE_VERSION`, Base self-test version assertion, Base Current State, and Base Roadmap.
- Regenerate: `.kinotch/base-files.json` and `.kinotch/FILE_INVENTORY.txt` with `base-refresh`.
- Synchronize: `C:/Users/kinok/Documents/Programs/kinotch-runtime/.kinotch/` and other Base-managed common files only.
- Modify: Runtime Current State to record embedded Base `0.3.9` without changing Runtime package `0.1.0`.

- [ ] Run all Base self-tests, doctor, base-check, and verify while still on `0.3.8`.
- [ ] Update Base version and current-state wording to `0.3.9` / Phase 5 maintenance, then run `base-refresh`.
- [ ] Run all Base gates again and inspect the diff for only the requested three fixes plus version/docs/index changes.
- [ ] Commit Base as `chore: release Repository Base v0.3.9` and push `main`.
- [ ] Copy only the finalized Base-managed files into the clean Runtime repository; do not alter Runtime execution contracts.
- [ ] Run Runtime doctor, base-check, project tests, and verify; commit/push as `chore: sync Repository Base v0.3.9 into Runtime`.
- [ ] Verify both local trees are clean and each local HEAD equals its remote main.

## Self-review

- Atomicity is isolated to the existing Default materialization path and is shared by init/migrate without adding persistent plan schema.
- Path safety is centralized for the three specified helper families, preserves the symlink/junction known limitation, and keeps Windows PowerShell 5.1 compatibility.
- Surface adoption remains explicit Project data; migrate never enables Manifest surfaces.
- No new Default, Runtime behavior, Surface Pack, or existing Project repository change is included.
