# KiNoTch. Repository Base Specification

Status: active for Base v0.5.4

## Purpose

KiNoTch. Repository Base standardizes the common structure, Agent entry points, command vocabulary, Project/Base boundary, Runtime connection declarations, and verification gate for KiNoTch. repositories.

The Base reduces the effort to create, read, repair, and verify a repository without forcing every project to adopt an unnecessary Surface, Runtime implementation, language, or deployment policy.

## Acceptance Criteria

1. An Agent can start work using a fixed read order.
2. Individual and common layers are physically separated.
3. Project-specific information does not need to be written under .kinotch/.
4. Changes to Base-managed files can be detected.
5. project/project.json can be machine-validated.
6. knt doctor can diagnose repository structure and project conformance.
7. knt verify is a usable Project verification entry point.
8. The repository works as a Base without Runtime implementation.
9. Unneeded Surface and Runtime dependencies are not forced.
10. Common knowledge other than the human-facing README is not duplicated in each repository.
11. Low-risk shared conveniences can be recorded as Project-level `DEFAULT`, `OVERRIDE`, or `DISABLED` states without changing Domain code.
12. `knt init` can generate a selected multi-profile Project and `knt migrate` is dry-run by default with explicit, non-destructive apply.
13. Surface Profiles and Runtime module selection are independent; `knt init` leaves `runtime.modules` empty unless a Project explicitly declares modules.
14. Surface Defaults and Tool Defaults are defined by one machine-readable Default Catalog and can be selected without router hard-coded lists.
15. `minimal`, `web-app`, `cli`, `windows-gui`, `mcp`, `api`, `agent`, and `library` are valid Surface Profiles, with `windows` retained as an alias.
16. Selecting `ci-test`, `pwa`, `generated-integrity`, or `file-io` materializes only removable, Domain-neutral implementation files; the L1 `verify` router remains available independently and is not a Tool Default.
17. Selecting `cli`, `windows`, `mcp`, or `api` materializes only removable helpers or permissive boundary descriptors; it does not add a framework, dispatch registry, HTTP policy, or Domain behavior.
18. `knt migrate` can perform a read-only repository-shape probe without a Project Manifest and refuses `--apply` until both a Project Manifest and repository-local `.kinotch/` Base exist; an external Base override is read-only, explicit apply materializes only missing safe helpers, validates Defaults against existing Manifest Surfaces, and preserves overrides.
19. `ci-test` provides a separate doctor → setup → verify workflow, generated-integrity checks both source and artifact hashes, PWA defaults are relative-base-path safe, and the generated file-io helper is explicitly UTF-8 text-only.
20. Default materialization records final file provenance and doctor rejects modified provenance-tracked DEFAULT files without changing their state automatically.
21. Template-backed Default integrity checks are derived from the Default template tree; adding a template does not require a second doctor switch.
22. CLI, Windows, MCP, API, Agent, Config, and Logging helpers remain removable Surface/Tool conveniences and do not change Runtime semantics or Project-owned policy.
23. Manifest paths, command working directories, Default materialization targets, and generated helper paths remain inside their trusted roots and reject link/reparse-point traversal.
24. Default upgrade planning compares the current template tree with recorded provenance, removes only unchanged stale files, preserves modified stale files, and reconciles `DISABLED` cleanup only after explicit `--apply`.

## Fixed read order

README.md -> project/project.json -> project/docs/INDEX.md -> project/docs/CURRENT_STATE.md -> relevant project/docs, code, and tests.

Base / Runtime development additionally reads .kinotch/meta/README.md and the relevant Meta documents.

## Ownership and boundary

The Base owns README entry conventions, Project Manifest, Profile, repository structure, Surface declarations, Base schemas, common command routing, and Runtime version/module references.

The project owns its purpose, Domain Core, project contracts, implementation, tests, and project-specific command values under project/**.

The Runtime owns execution implementations and the cross-repository Execution Contract once Runtime Phase 1 is verified.

## Inputs and outputs

Inputs are the repository files, project/project.json, contract registries, Base schemas, profile declarations, Default state, and command arguments. doctor emits diagnostics and an exit code, including Catalog semantics and DEFAULT Tool/Surface compatibility. verify delegates to the configured project verification command or test then build fallback. base-check reports common-file drift. init generates only a missing Project Overlay. migrate reports candidates and writes only after explicit `--apply` with a repository-local Base, preserving existing Default states. Base self-tests report individual behavior failures and an aggregate exit code.

## Constraints

- Runtime packages are not required for Base use.
- Surface Profiles do not imply Runtime modules. Existing explicit Runtime module declarations remain Project-owned.
- Default Catalog entries are low-risk, removable Surface or Tool conveniences; only entries with actual materialized behavior are cataloged, and they do not define Runtime execution semantics. The v0.5.3 Tool catalog is exactly `ci-test`, `generated-integrity`, `file-io`, `pwa`, `config`, and `logging`.
- Production deployment policy remains Project-owned.
- Surface adapters must not duplicate Domain Core behavior.
- Generated artifacts must be regenerated from their canonical source and remain inside the Project root.
- Default implementations must remain Surface / Tool conveniences; they must not define Domain formats, deploy policy, Runtime modules, or public API semantics.

## Exceptions and fallback

Missing or invalid JSON, schema violations, missing required paths, direct profile/surface contradictions, and Base drift fail doctor or base-check. A missing optional project command is not an error. verify uses test then build only when no direct verify command is configured and stops on the first non-zero command result.

## .ai-guidelines relationship

KiNoTch. Base owns repository structure, Agent entry points, and implementation workflow. .ai-guidelines remains the cross-repository source for UI/UX and domain-wide design policy. The two sources are referenced by responsibility and do not duplicate each other's complete rules.

## Tests

Base self-tests under .kinotch/tests/ cover manifest and registry schema validation, Default state and provenance validation, required paths, profile checks, init/migrate safety, command routing, verify fallback, Surface Kit helpers, Base hash protection, CI host declarations, and fixture isolation. The CI gate runs doctor followed by setup and verify on Ubuntu PowerShell, Windows PowerShell Core, and Windows PowerShell 5.1.
