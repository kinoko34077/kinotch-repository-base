# Repository Base v0.2 Hardening Implementation Plan

> For agentic workers: use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax.

Goal: Finish the Base v0.2 hardening described by ADR 0001 so that the Base identifies itself, keeps templates and common metadata separate, validates schemas, tests its router, and documents the Runtime boundary without implementing Runtime packages.

Architecture: Keep the PowerShell command router as the only operational entry point. Add dependency-free JSON Schema subset validation and deterministic Base-index generation. Make the self-test runner execute the real router against temporary fixture repositories. Keep project identity in project/**, common assets in .kinotch/**, and Runtime execution semantics documented as future candidates.

Tech Stack: PowerShell 5.1/7-compatible scripts, JSON Schema documents, JSON fixtures, GitHub Actions, and the existing knt.cmd wrapper. No new package-manager or Runtime dependency.

Spec: project/docs/adr/0001-base-v02-hardening.md

## Global Constraints

- Base-wide metadata is under .kinotch/meta/; project/meta/ must not remain.
- Base templates are under .kinotch/templates/project/ and must not define the Base repository identity.
- Runtime implementation is out of scope; Runtime module names remain logical until Runtime Phase 1.
- JSON schemas must be loaded and used by knt doctor; existence-only checks are insufficient.
- Profile runtime modules are recommendations, but direct profile/surface contradictions fail diagnostics.
- knt base-refresh is permitted only when project.project.type is repository-base.
- Existing CI order remains doctor then verify.
- The validator and self-tests run without Node, Python, or third-party PowerShell modules.
- Work in the current main checkout and push each completed task commit.

## Review Focus

- Malformed JSON reports a schema error and exit code 2 without terminating the test runner unexpectedly; Task 3.
- A profile recommendation mismatch warns without failing a valid project; Task 3.
- Missing command cwd and non-zero command exit are distinguished; Task 3.
- An unindexed .kinotch file is detected until base-refresh regenerates the index; Task 4.
- Fixture execution never mutates the real repository or copies .git; Task 2.

## File Map

- Base identity: README.md, project/project.json, project/docs/{INDEX,SPEC,CURRENT_STATE}.md, project/contracts/surfaces.json.
- Common metadata: move project/meta/*.md to .kinotch/meta/ and update AGENTS.md, .kinotch/README_BASE.md, and .kinotch/docs/BASE_ROADMAP.md.
- Templates: create .kinotch/templates/project/ with README, manifest, docs, contracts, and ignore templates.
- Schemas: modify .kinotch/schemas/project.schema.json, surface.schema.json, and error.schema.json.
- Profiles: add status: planned to .kinotch/profiles/*.json.
- Tooling: create .kinotch/scripts/knt-validation.ps1 and update-base-index.ps1; modify .kinotch/scripts/knt.ps1.
- Tests: create .kinotch/tests/run-tests.ps1 and .kinotch/tests/fixtures/.
- Index: regenerate .kinotch/base-files.json only through the refresh script.

### Task 1: Base identity, boundary, templates, and schema vocabulary

Files:
- Modify README.md, project/project.json, project/docs/INDEX.md, project/docs/SPEC.md, project/docs/CURRENT_STATE.md, project/contracts/surfaces.json.
- Move the seven project/meta documents to .kinotch/meta/ (README plus 00 through 05).
- Create .kinotch/templates/project/README.md, project.json, docs/INDEX.md, docs/CURRENT_STATE.md, docs/SPEC.md, contracts/actions.json, contracts/surfaces.json, and .gitignore.
- Modify AGENTS.md, .kinotch/README_BASE.md, .kinotch/docs/BASE_ROADMAP.md, .kinotch/RUNTIME_INTEGRATION.md, all profile JSON files, the three schemas, and .kinotch/BASE_VERSION.

Produces: repository-base manifest identity, eight canonical surfaces cli, gui_windows, web, api, mcp, agent, library, .kinotch/meta location, and planned profile status.

- [ ] Write acceptance checks for Base README/manifest identity, missing project/meta, seven files under .kinotch/meta (README plus 00 through 05), eight surface names, and planned profile status.
- [ ] Run the pre-change checks:

~~~powershell
Get-Content -Raw project/project.json | ConvertFrom-Json
Test-Path project/meta
.\knt.cmd base-check
~~~

Expected: manifest parses, project/meta is True, and base-check is Base files: OK.
- [ ] Apply identity, move, template, schema, and documentation changes. Set project.name to kinotch-repository-base, project.type to repository-base, description to a Base description, and BASE_VERSION to 0.2.0. Keep PROJECT_NAME only inside template files. Reject unknown surface names. Make Error code a string matching ^[A-Z][A-Z0-9_]*$.
- [ ] Run identity assertions and base-check. Until Task 4 refreshes the index, changed common files may be reported.
- [ ] Commit and push:

~~~powershell
git add README.md AGENTS.md .kinotch project
git commit -m "feat: harden Base identity and boundaries"
git push origin main
~~~

### Task 2: Fixture runner and red self-tests

Files:
- Create .kinotch/tests/run-tests.ps1 and project-only fixture trees under .kinotch/tests/fixtures/ for valid-minimal, invalid-manifest, invalid-actions, invalid-surfaces, missing-files, command-success, command-failure, verify-fallback, and command-cwd.
- After the runner exists, set the Base test command in project/project.json to invoke it from repository root.

Produces: Assert-Equal, Assert-True, New-FixtureRoot, Invoke-KntFixture, and Invoke-TestCase helpers. Later router changes consume -RootOverride and return process exit codes.

- [ ] Write failing tests. Copy the real repository to a temporary directory excluding .git, replace only the fixture project tree, invoke .kinotch/scripts/knt.ps1 -RootOverride TEMP command, and delete the temporary directory in finally.
- [ ] Run:

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .kinotch/tests/run-tests.ps1
~~~

Expected: FAIL for missing RootOverride, schema validation, and profile/path diagnostics; it must not fail because of a test-runner syntax error.
- [ ] Add fixtures: valid manifest; invalid manifest missing profile; invalid action missing summary; invalid surface with unknown key; missing declared docs directory; command success; command failure exit 7; verify marker test then build; command cwd marker.
- [ ] Commit and push:

~~~powershell
git add .kinotch/tests project/project.json
git commit -m "test: define Base v0.2 self-test fixtures"
git push origin main
~~~

### Task 3: Schema validation and doctor/router behavior

Files:
- Create .kinotch/scripts/knt-validation.ps1.
- Modify .kinotch/scripts/knt.ps1, project/project.json, and fixture expectations.

Interfaces:
- Test-KntSchema -Data object -Schema object -Path string returns string errors and supports type, required, properties, additionalProperties, items, oneOf, enum, const, pattern, minLength, and uniqueItems.
- Get-KntJson -Path string parses UTF-8 JSON and throws a path-specific error.
- knt.ps1 -RootOverride path command uses the override for tests; normal invocation derives root from script location.

- [ ] Run the red Task 2 suite and record the first expected missing behavior.
- [ ] Implement recursive stable schema validation with paths such as project.name and actions[0].summary. Load the project, action, and surface schemas from the active root. Preserve parse failures as doctor failures with exit code 2.
- [ ] Integrate doctor checks: validate all three registries; require the selected profile file; fail direct profile/surface contradictions; warn on recommended module/surface differences; resolve manifest paths relative to project and command cwd relative to repository root; fail missing paths and cwds; keep empty commands unconfigured.
- [ ] Preserve unknown command exit 2, configured command exit propagation, direct verify behavior, test-then-build fallback order, and zero when no fallback is configured.
- [ ] Run:

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .kinotch/tests/run-tests.ps1
.\knt.cmd doctor
.\knt.cmd verify
~~~

Expected: fixtures pass, Base doctor passes, and verify runs the Base self-tests through the test command.
- [ ] Commit and push:

~~~powershell
git add .kinotch/scripts/knt-validation.ps1 .kinotch/scripts/knt.ps1 project/project.json .kinotch/tests
git commit -m "feat: validate Base manifests and registries"
git push origin main
~~~

### Task 4: Deterministic Base index refresh and protection

Files:
- Create .kinotch/scripts/update-base-index.ps1.
- Modify .kinotch/scripts/knt.ps1, .kinotch/base-files.json, and .kinotch/FILE_INVENTORY.txt.
- Test changed-base and unindexed-file cases in .kinotch/tests/run-tests.ps1.

Interfaces:
- Get-BaseProtectedPaths -Root path returns ordinal-sorted repository-relative fixed common files, shared CI, AGENTS.md, knt.cmd, and every .kinotch/** file except the index.
- Update-BaseIndex -Root path writes schema version 1, current BASE_VERSION, and sorted SHA-256 entries as UTF-8 JSON.

- [ ] Add red tests that modify copied .kinotch/README_BASE.md and expect base-check non-zero, then add a copied unindexed .kinotch file and expect failure until base-refresh.
- [ ] Run the suite. Expected: base-refresh is unknown and the old base-check does not detect an unindexed file.
- [ ] Implement ordinal deterministic ordering, repository-base restriction, strict missing/changed/unindexed comparisons, and exclusion of the index itself.
- [ ] Run:

~~~powershell
.\knt.cmd base-refresh
.\knt.cmd base-check
powershell -NoProfile -ExecutionPolicy Bypass -File .kinotch/tests/run-tests.ps1
~~~

Expected: base_version is 0.2.0 and all checks pass.
- [ ] Commit and push:

~~~powershell
git add .kinotch
git commit -m "feat: add deterministic Base index refresh"
git push origin main
~~~

### Task 5: Contract, profile, and policy documentation closeout

Files:
- Modify .kinotch/RUNTIME_INTEGRATION.md, .kinotch/README_BASE.md, .kinotch/AGENT_RULES.md, .kinotch/REPOSITORY_STANDARD.md, .kinotch/docs/BASE_ROADMAP.md, project/docs/SPEC.md, project/docs/CURRENT_STATE.md, and all profile JSON files.

Interfaces:
- Documentation states Base-defined contracts: Action Registry, Result, Error, Progress, Resource, Artifact.
- Documentation states Runtime Phase 1 candidates: ActionRequest, ActionContext, Cancellation, Config execution semantics.
- Documentation states profile runtime_modules are logical/planned until Runtime Phase 1.

- [ ] Add self-test assertions for ten SPEC acceptance criteria, no template placeholder in CURRENT_STATE, both Runtime contract status headings, and planned status in every profile.
- [ ] Run the suite and confirm it fails for the current template documents.
- [ ] Update SPEC purpose, read order, boundary, validation, Base-only use, and ten acceptance criteria. Update CURRENT_STATE with implemented, in-progress, known issues, constraints, next work, and verification. Add Base/Runtime and .ai-guidelines responsibility split without duplicating external policy text.
- [ ] Run:

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .kinotch/tests/run-tests.ps1
.\knt.cmd doctor
.\knt.cmd verify
~~~

Expected: self-tests, doctor, and verify return 0.
- [ ] Commit and push:

~~~powershell
git add .kinotch project
git commit -m "docs: finalize Base v0.2 contracts and state"
git push origin main
~~~

### Task 6: Final gate and release evidence

- [ ] Run:

~~~powershell
.\knt.cmd doctor
.\knt.cmd base-check
.\knt.cmd verify
.\knt.cmd smoke
git status --short --branch
git log -5 --oneline --decorate
git ls-remote origin refs/heads/main
~~~

Expected: all commands return 0, working tree is clean, and local HEAD equals remote main.
- [ ] If CURRENT_STATE or the index changed, commit with chore: record Base v0.2 verification and push; otherwise do not create an empty commit.

## Commit Sequence

1. feat: harden Base identity and boundaries
2. test: define Base v0.2 self-test fixtures
3. feat: validate Base manifests and registries
4. feat: add deterministic Base index refresh
5. docs: finalize Base v0.2 contracts and state
6. Optional final verification commit only when evidence changes a tracked file.
