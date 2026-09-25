# ADR 0005 — Base v0.5.3 Integrity Boundaries

## Context

Base v0.5.2 already protected Default materialization and repository-relative paths, but the refresh index, link boundaries, and Default cleanup authority still had lifecycle gaps. The v0.5.3 work also formalizes the confidentiality boundary for cross-repository GitHub operations.

## Decisions

1. A `BASE_VERSION` identifies one protected Base snapshot. `base-refresh` rejects protected path or hash changes when the version is unchanged; protected changes require a version bump before index regeneration.
2. Provenance is evidence, not deletion authority. Default cleanup may remove only current template paths or explicitly cataloged `retired_paths`; unrelated or modified paths are preserved and reported.
3. Base integrity and Default writes never cross symlink, junction, or reparse-point boundaries below trusted roots. Projects that require link traversal own that behavior through `OVERRIDE`.
4. Cross-repository findings use the GitHub Development Control confidentiality and idempotence rules; this ADR does not duplicate that policy.

## Alternatives considered

- Allowing refresh to rewrite the same-version index was rejected because identical version labels would describe different Base contents.
- Treating every provenance path as deletable was rejected because editable Project data could be removed by stale metadata.
- Resolving links transparently was rejected for the Default safety boundary because a conservative refusal is easier to audit and recover from.

## Consequences

Base changes now require an explicit version transition, Default upgrades are safer for Project edits, and link-based layouts may need an `OVERRIDE`. Runtime semantics and the existing Default state vocabulary are unchanged.
