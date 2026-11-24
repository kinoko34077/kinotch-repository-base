# ADR 0006 — Reference-based Repository Base (proposal)

Status: Proposed / B0 investigation (#66). This is not an accepted specification or a release authorization.

## Context and decision drivers

The initial context/target/roadmap at `b06e2db25b0567413fe73816bb06dcf7179a40e0` separates common and individual ownership; distribution was an initial mechanism, not the goal. The current accepted snapshot is 0.5.24 (`3c36e3f78fc39c4aa53d08d578a624e141bf18e1`). Current doctor, base-check, init/migrate and Default provenance assume local materialization. RootOverride/BaseOverride already route to external schemas and catalog but doctor skips the local Base integrity check for RootOverride; this is NOT production admission.

Observed examples: memory-game 0.3.8 (web-app OVERRIDE), kinotch-api 0.3.8 (api/mcp/ci-test/generated-integrity OVERRIDE), kinotch-default-canary 0.5.13 (cli/ci-test/config/logging DEFAULT with materialized hashes). Runtime embeds 0.5.13 and owns portable execution semantics. Remaining adopters need inventory before B0 acceptance.

## Alternatives

| Approach | Update without consumer commit | Reproduction and trust | Decision |
|---|---|---|---|
| Copy protected tree / patch | No | Per-consumer drift and synchronization | Legacy only |
| Git submodule / exact package pin alone | No | Strong snapshot identity, manual update | Optional fixed mode, not normal default |
| Execute floating main or raw URL | Yes | Unreviewed revisions and arbitrary origin risk | Reject |
| Reviewed compatibility channel resolving to immutable commit | Yes | Requires explicit authority, immutable resolution and verification | Proposed |
| New hosted API / package service | Possible | New operating and authentication burden | Not justified |

## Proposed responsibility and placement

- Base owns shared commands, schemas, Default catalog and implementations, rules, shared tests and Base CI logic; retain ADR0004 layer separation. Runtime owns portable runtime semantics, devflow owns cross-repository operation/bootstrap, .ai-guidelines owns its independent rules.
- Consumer owns manifest, selected capability states, local configuration, Domain, overrides and consumer tests. DEFAULT resolves central implementation; OVERRIDE uses only the consumer implementation; DISABLED never resolves or runs the capability. Reuse the existing catalog instead of a second selection mechanism.
- Keep only platform-required local entry/configuration: minimal launcher, AGENTS discovery pointer, workflow trigger/job entry, Git/editor configuration where required by host. Distinguish one-time skeleton generation and necessary generated/deployed assets from live shared implementations; generated assets require explicit reproducible generation and must not silently overwrite overrides. Audit each exception.
- Separate immutable Base root from writable consumer root in router and validation. Verify Base integrity against the admitted snapshot; verify consumer against manifest and selected capabilities. Do not weaken legacy hash/provenance checks. External Base operations may write consumer files only under a separately specified authorized consumer operation and path-containment checks; never mutate the shared cache. Keep existing legacy write denial until replacement is proven.

## Resolution contract candidate (B1)

A small trusted entry uses the fixed canonical public Base repository, not an arbitrary URL supplied by a consumer. A compatibility channel (name illustrative: stable/v1) identifies an approved revision, not latest main. Resolve once at execution start to an exact Git commit and verify approval and integrity before executing ANY fetched code, including validators. Git identity alone or hashes provided by the same untrusted content do not establish approval. Prefer existing GitHub review/protection infrastructure; the exact approval authority, immutable history proof, channel format and revocation/rollback policy are unresolved B0/B1 security design items. Do not enable a live moving channel until reviewed and authorized.

Cache immutable snapshots by revision outside tracked consumer files; atomic admission, concurrency safety and path/link containment are required. Avoid hooks, arbitrary remotes, submodule execution, credentials and mutable caches as trust roots. Offline use is explicit and limited to verified previously admitted snapshots; report SHA and offline/stale status. Fail closed for formal verification when required freshness/trust is unavailable; never silently fetch or execute another revision. Pinning/rollback must select an approved compatible revision, not arbitrary code. Record consumer HEAD, selected capabilities, Base SHA and evidence; doctor/setup/verify in one CI run share the same resolved revision.

## CI / bootstrap

Preserve required job/check context, issuer and permission boundary. Prefer a minimal caller retaining current triggers/check contract and a pinned trusted dispatcher resolving the admitted Base revision; compare reusable workflow context semantics before B3. Do not replace check evidence with unrelated success or expose privileged credentials to untrusted PR code. Base-specific CI references are #66; general CI consolidation and rollout are devflow #1121/#1122. Existing #63/#65 and draft #64 are separate; do not distribute legacy patch. Devflow minimal bootstrap does not imply Base adoption; integrate reference-mode seed only with the owning bootstrap mechanism and explicit selection in B4.

## Evidence and gates

B0: inventory current capability placement, helper path assumptions and host exceptions; compare approval alternatives; identify legacy compatibility constraints.
B1: prove immutable resolution, trusted admission, online/offline/pin/rollback, corrupt/unknown/unapproved rejection, no consumer mutation, three supported PowerShell hosts.
B2: exercise real DEFAULT/OVERRIDE/DISABLED routing, schema/rule discovery, no duplicated selection logic; preserve consumer-specific configuration and tests.
B3: prove central CI logic, check-context compatibility and equivalent evidence; avoid duplicate independent guarantees.
B4: representative legacy adopter and new bootstrap; measure tracked shared files and prove overrides preserved; no fleet-wide migration.
B5: accepted specs/implementation/tests; central compatible change observed on next ordinary consumer execution without consumer Git tree change, plus rollback/offline/security negatives. Fleet migration has separate issues.

The initial probe in project/tests/reference-base-probe.ps1 isolates a synthetic overly strict Base schema from the current schema. It tests existing external reference mechanics and write denial, not network resolution, release approval, production Base integrity, or final acceptance. No actual consumer or protected Base path is modified.
