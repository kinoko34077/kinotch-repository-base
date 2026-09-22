# ADR 0001: Repository Base v0.2 Hardening

## Status

Proposed for implementation

## Context

KiNoTch. Repository Base v0.1.1 already provides the physical Base/Project
boundary, common Agent rules, the `knt` command router, schemas, profiles,
metadata, and a Base hash check. The repository itself, however, still uses
template identity, keeps Base-wide metadata under `project/meta/`, and does
not execute its schemas as validation rules.

Before implementing KiNoTch. Runtime, the Base must be self-describing,
template-safe, self-testable, and explicit about which contracts belong to
the Base versus the future Runtime.

## Decision

### Repository identity and boundary

`kinotch-repository-base` is represented by the root `README.md`,
`project/project.json`, `project/docs/SPEC.md`, and
`project/docs/CURRENT_STATE.md`. These files describe the Base itself rather
than a newly generated project.

`.kinotch/**`, `AGENTS.md`, `knt.cmd`, the shared CI workflow, and the root
editor/configuration files remain common Base material. `project/**` remains
the individual-project area. Runtime implementation is not copied into the
Base.

### Metadata and templates

Base-wide metadata moves from `project/meta/` to `.kinotch/meta/`. New
repository templates live under `.kinotch/templates/project/`; they are
never used as the Base repository's own identity.

### Validation

`knt doctor` loads the repository's JSON Schema files and validates the
manifest, Action Registry, and Surface Registry. It also checks the selected
profile, profile/surface contradictions, recommended runtime-module
differences, declared paths, and command working directories.

Validation uses a small dependency-free PowerShell JSON-Schema subset that
covers the keywords used by the Base schemas. This keeps `knt doctor`
available before Runtime implementation and avoids imposing a language
runtime or package manager on every project.

Profile runtime modules remain recommendations. A direct contradiction, such
as a `cli` profile with `surfaces.cli = false`, fails diagnostics; a
non-identical recommendation produces a warning.

### Base maintenance and self-tests

`knt base-refresh` regenerates `.kinotch/base-files.json` only when the
manifest identifies the repository as `repository-base`. The protected set
includes the common Base files, shared CI, `AGENTS.md`, `knt.cmd`, and all
`.kinotch/**` files except the index itself. The operation is deterministic.

Base self-tests live under `.kinotch/tests/` and use fixture project data
under `.kinotch/tests/fixtures/`. Tests execute the actual command router in
temporary fixture roots and cover valid and invalid manifests, schema
failures, missing paths, changed Base files, unknown commands, command
failure propagation, verify fallback order, and command working directories.

The Base project's `test` command invokes this runner, so the existing CI
gate remains `doctor` followed by `verify`, with `verify` running the Base
self-tests through its normal fallback.

### Contract ownership

Base v0.2 owns repository-level declarations: manifest, profile, repository
structure, surfaces, and Runtime version/module references. Base schemas that
already exist for Action Registry, Result, Error, Progress, Resource, and
Artifact are documented as defined Base contracts.

Action execution request/context, cancellation, and configuration execution
semantics remain Runtime Phase 1 candidates until a Runtime implementation
and pilot verify them. Error codes use an extensible uppercase identifier
syntax in the Base schema; Runtime documentation will define recommended
meanings later.

`.ai-guidelines` is treated as a separate cross-repository policy source for
UI/UX and domain-wide design policy. KiNoTch. Base owns repository structure,
Agent entry points, and implementation workflow. Neither side copies the
other's full rules.

## Consequences

- A fresh repository can be generated from an explicit template tree without
  confusing template placeholders with Base identity.
- `knt doctor` becomes a real project conformance gate rather than an
  existence report.
- Base changes require index regeneration and self-test evidence.
- Downstream repositories can still declare only the Runtime modules and
  surfaces they need; recommended profile contents are not hard dependencies.
- The PowerShell validator is intentionally limited to the schema keywords
  used by this Base. A future Runtime or tooling package may replace it with a
  standards-complete validator if real requirements justify that dependency.

## Rejected alternatives

1. Keeping `project/meta/` and adding more exceptions would preserve the
   boundary ambiguity this version is intended to remove.
2. Adding Node/Python schema dependencies would make the Base less portable
   before Runtime exists.
3. Implementing Runtime packages together with this work would expand the
   change beyond the Base v0.2 gate and make contract ownership harder to
   verify.
