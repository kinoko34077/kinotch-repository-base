# KiNoTch. Repository Base Specification

Status: active for Base v0.2

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

## Fixed read order

README.md -> project/project.json -> project/docs/INDEX.md -> project/docs/CURRENT_STATE.md -> relevant project/docs, code, and tests.

Base / Runtime development additionally reads .kinotch/meta/README.md and the relevant Meta documents.

## Ownership and boundary

The Base owns README entry conventions, Project Manifest, Profile, repository structure, Surface declarations, Base schemas, common command routing, and Runtime version/module references.

The project owns its purpose, Domain Core, project contracts, implementation, tests, and project-specific command values under project/**.

The Runtime owns execution implementations and the cross-repository Execution Contract once Runtime Phase 1 is verified.

## Inputs and outputs

Inputs are the repository files, project/project.json, contract registries, Base schemas, profile declarations, Default state, and command arguments. doctor emits diagnostics and an exit code. verify delegates to the configured project verification command or test then build fallback. base-check reports common-file drift. init generates only a missing Project Overlay. migrate reports candidates and writes only after explicit `--apply`, preserving existing Default states. Base self-tests report individual behavior failures and an aggregate exit code.

## Constraints

- Runtime packages are not required for Base use.
- Profile runtime_modules are logical recommendations until Runtime Phase 1.
- Production deployment policy remains Project-owned.
- Surface adapters must not duplicate Domain Core behavior.
- Generated artifacts must be regenerated from their canonical source.

## Exceptions and fallback

Missing or invalid JSON, schema violations, missing required paths, direct profile/surface contradictions, and Base drift fail doctor or base-check. A missing optional project command is not an error. verify uses test then build only when no direct verify command is configured and stops on the first non-zero command result.

## .ai-guidelines relationship

KiNoTch. Base owns repository structure, Agent entry points, and implementation workflow. .ai-guidelines remains the cross-repository source for UI/UX and domain-wide design policy. The two sources are referenced by responsibility and do not duplicate each other's complete rules.

## Tests

Base self-tests under .kinotch/tests/ cover manifest and registry schema validation, Default state validation, required paths, profile checks, init/migrate safety, command routing, verify fallback, Base hash protection, and fixture isolation. The CI gate runs doctor followed by verify.
