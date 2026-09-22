# KiNoTch. Repository Default-First Standardization v0.1

## Purpose

KiNoTch. repositories provide safe, removable common conveniences as
standard Defaults before demanding cross-language proof. Changes that carry
Domain meaning, public compatibility, persistent format, or authority remain
separate Portable Contract candidates and are evaluated by Runtime Pilots.

This document is the canonical policy. Runtime and Project documents refer to
it instead of copying the full policy.

## Four layers

Each shared element has one source of truth.

```text
L1 Hard Base
    ↓
L2 Surface / Tool Defaults
    ↓
L3 Portable Semantic Contracts
    ↓
L4 Project Overlay / Domain
```

### L1 — Hard Base

Hard Base contains repository operation itself: `AGENTS.md`, `.kinotch/`, the
`project/` boundary, Project Manifest, documentation/ADR skeleton, the `knt`
router, `doctor`, `verify`, Base checks, Base refresh, Schema validation, and
common command vocabulary. It must not contain Project-specific information.
Individual repositories do not edit it directly; changes come from the
Repository Base source of truth.

### L2 — Surface / Tool Defaults

Defaults are common conveniences that do not own Domain meaning, public
compatibility, persistent data, or authority. They must be safe to remove and
must be overrideable or disableable per Project. Initial Default Pack
candidates are CLI, Windows, MCP, and API common options and hooks.

These are defaults, not mandatory universal libraries. Existing Framework
dispatch remains authoritative where it already exists.

### L3 — Portable Semantic Contracts

Portable Contract candidates require the same meaning, the same change reason,
low conversion cost, and no loss of Domain state across implementations.
Current candidates include operation identity, operation input, request or
correlation identity, error code/message/details, optional retryability, narrow
progress meaning, and narrow artifact-reference meaning. Runtime maturity
labels apply only to this layer.

### L4 — Project Overlay / Domain

Project owns Domain algorithms and models, Project UI and state machines,
persistent formats, provider/deploy/auth policy, Project resource authority,
Project error meaning, and Default overrides or disablement. Domain code must
not be changed merely to fit a Default or Portable Contract.

## Default states

Project-level Default state uses exactly three values:

```text
DEFAULT   use the selected standard behavior
OVERRIDE  use Project-provided behavior or settings
DISABLED  do not provide the Default for this Project
```

Portable maturity labels such as `pilot-exercised`, `PARTIAL GO`, `REVISE`,
or `stable` do not determine Default state.

## Decision rule

For a new candidate `X`, ask in order:

1. Is it required for repository operation itself? If yes, L1 Hard Base.
2. Does it carry no Domain meaning and remain safely removable? If yes, L2
   Default.
3. Must multiple implementations share the same meaning and change reason?
   If yes, evaluate as an L3 Portable Contract candidate.
4. Otherwise keep it in L4 Project Overlay / Domain.

Low-risk, removable conveniences are provided as Defaults first and observed
in use. A Project may override or disable a Default when it duplicates an
existing Framework, adds adapter-only complexity, leaks Domain information,
adds unused dependencies, or makes the existing path harder to understand.
Default retirement requires the same problem to repeat across Projects.

## Initialization and migration

`knt init --profile <profile>` selects one or more Default Packs and creates a
Project overlay from the Base templates. Repeated profiles are allowed. The
initializer must not overwrite an existing `project/project.json`.

`knt migrate` is opt-in and non-destructive: detect differences, show
candidates, apply only after explicit selection, and preserve Project
overrides. It must never rewrite Domain files automatically.

Default Pack distribution remains language- and Surface-appropriate. It does
not imply one universal Runtime library, and it does not promote a Default to
Portable Contract merely because it is used by more than one Project.

## Ownership

Repository Base owns this policy, L1 structure, Default metadata, and the
initialization safety boundary. Runtime owns execution semantics and Portable
Contract definitions. Project owns Domain behavior and the selected
Default/Override/Disabled state.
