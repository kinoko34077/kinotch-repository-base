# Surface Default Kit Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the existing CLI, Windows, MCP, and API Surface Defaults into thin, reusable kits while preserving Project ownership of Domain behavior and keeping Runtime contracts unchanged.

**Architecture:** Keep one source of truth under `.kinotch/templates/defaults/<surface>/`. `knt init` continues to materialize selected Surface templates into `project/`; no new fine-grained catalog entries are introduced. Executable helpers expose small, dependency-free boundaries, while existing frameworks and Project callbacks remain responsible for dispatch and Domain behavior.

**Tech Stack:** PowerShell 5.1/7-compatible helper scripts, JSON boundary descriptors, the existing PowerShell router and self-test harness, no new third-party dependencies.

**Spec:** User-provided “KiNoTch. Surface Default Kit 拡張・当初共通化構想再統合 指示書”.

## Global Constraints

- Shared implementation is not automatically a Portable Contract; do not modify Runtime contracts or Runtime version 0.1.0.
- Do not add fine-grained catalog entries such as `file-picker`, `json-output`, `request-id`, or `progress-dialog`.
- Keep only `DEFAULT`, `OVERRIDE`, and `DISABLED` as Default states.
- Preserve existing Framework dispatch; do not add a second Action/MCP/API registry.
- Keep Domain algorithms, formats, public policies, persistent state, and provider behavior in the Project layer.
- Use OS/language standard facilities and avoid new dependencies.
- Surface helpers must be removable, overrideable, and safe to materialize without overwriting existing files.
- Maintain Windows PowerShell 5.1 compatibility; do not use `$IsWindows`.
- Existing Project implementations may remain `OVERRIDE` and may still reuse individual common helpers.
- Do not migrate or edit external repositories in this change.

## Review Focus

- Common CLI flags must not consume or reinterpret Project-specific arguments; test that unknown/domain arguments remain untouched.
- Quiet/verbose and stdout/stderr behavior must be deterministic; test that diagnostics do not leak into normal output.
- Windows helpers must return cancel/normalized paths without requiring a GUI in self-tests; test invalid and empty drop input.
- MCP/API helpers must describe or invoke existing dispatch/hooks without creating a second registry or fixing Project-owned policies.
- Materialization must preserve existing files and avoid dependency injection; test generated paths, idempotence, and existing override behavior.

---

### Task 1: Expand the CLI Surface Kit

**Files:**
- Modify: `.kinotch/templates/defaults/cli/tools/cli-default.ps1`
- Modify: `.kinotch/tests/run-tests.ps1` near the existing Surface Default tests
- Modify: `project/docs/CURRENT_STATE.md` with the new CLI Kit state

**Interfaces:**
- Consumes: a string array of command-line tokens and optional Project-provided output values.
- Produces: `Get-CliCommonOptions([string[]]$Arguments)` returning a PSCustomObject with boolean `Help`, `Version`, `Json`, `Quiet`, `Verbose`, `DryRun`, `Yes`, and `RemainingArgs`; `Write-CliOutput`, `Write-CliDiagnostic`, `Write-CliJson`, `Write-CliResult`, `Write-CliError`, `Show-CliHelp`, and `Exit-Cli`.

- [x] **Step 1: Write failing materialized-helper tests**

Add a self-test that initializes a `cli` Project, dot-sources `project/tools/cli-default.ps1`, and asserts:

```powershell
$options = Get-CliCommonOptions @('--json', '--quiet', '--verbose', '--dry-run', '--yes', '--domain-value')
Assert-True $options.Json 'CLI --json was not parsed'
Assert-True $options.Quiet 'CLI --quiet was not parsed'
Assert-True $options.Verbose 'CLI --verbose was not parsed'
Assert-True $options.DryRun 'CLI --dry-run was not parsed'
Assert-True $options.Yes 'CLI --yes was not parsed'
Assert-Equal '--domain-value' $options.RemainingArgs[0] 'Project argument was consumed by the Default'
```

Capture `Write-CliOutput -Quiet`, `Write-CliDiagnostic -VerboseOutput`, `Write-CliJson`, and `Write-CliResult` through separate PowerShell invocations and assert that ordinary output is stdout, diagnostics are stderr, quiet emits no ordinary line, and JSON is parseable. Add a subprocess check for `Exit-Cli -Code 7`.

- [x] **Step 2: Run the focused self-test and verify it fails**

Run: `pwsh -NoProfile -ExecutionPolicy Bypass -File .kinotch/tests/run-tests.ps1`

Expected: the new CLI Kit test fails because `Get-CliCommonOptions`, `Write-CliOutput`, `Write-CliDiagnostic`, and `Write-CliResult` do not yet exist.

- [x] **Step 3: Implement the smallest CLI Kit**

Keep the existing functions and add only common plumbing. Parse only the seven exact common tokens; append every other token to `RemainingArgs` in original order. Use `[Console]::Out` and `[Console]::Error` directly. `Write-CliResult` must accept a value and a `-Json` switch; it may call `Write-CliJson` or write a single text value, but it must not know Domain fields. `Write-CliDiagnostic` must return without output unless `-VerboseOutput` is set. `Show-CliHelp` remains generic and documents the flags without adding Project arguments.

- [x] **Step 4: Run the self-test and the generated CLI helper checks**

Run the full self-test, then materialize `cli` in a temporary fixture and invoke each helper path. Expected: all CLI assertions pass and no existing Base test regresses.

- [x] **Step 5: Commit the CLI slice**

```powershell
git add .kinotch/templates/defaults/cli/tools/cli-default.ps1 .kinotch/tests/run-tests.ps1 project/docs/CURRENT_STATE.md
git commit -m "feat: expand CLI Surface Default Kit"
git push origin main
```

### Task 2: Expand the Windows Surface Kit

**Files:**
- Modify: `.kinotch/templates/defaults/windows/tools/windows-shell.ps1`
- Modify: `.kinotch/tests/run-tests.ps1`
- Modify: `project/docs/CURRENT_STATE.md`

**Interfaces:**
- Consumes: file/folder paths, dropped path arrays, optional callbacks, and progress/cancel state.
- Produces: `Resolve-WindowsShellPath`, `Convert-WindowsDropItems`, `Select-WindowsPath`, `Save-WindowsPath`, `New-WindowsProgressState`, `Update-WindowsProgressState`, `Complete-WindowsProgressState`, `Fail-WindowsProgressState`, `New-WindowsCancelSource`, `Request-WindowsCancel`, `Test-WindowsCancelRequested`, plus the existing Explorer/clipboard functions.

- [x] **Step 1: Write failing non-GUI Windows helper tests**

Read the materialized Windows helper and test the following without opening a dialog:

```powershell
Assert-Equal $existing (Resolve-WindowsShellPath -Path $existing) 'existing path normalization'
Assert-Equal 2 @(Convert-WindowsDropItems -Paths @($file1, '', $file2)).Count 'drop parsing'
Assert-True ($null -eq (Convert-WindowsDropItems -Paths @('', '  '))) 'empty drop should be cancelled'
$cancel = New-WindowsCancelSource
Assert-True (-not (Test-WindowsCancelRequested $cancel)) 'new cancel source is already requested'
Request-WindowsCancel -Source $cancel
Assert-True (Test-WindowsCancelRequested $cancel) 'cancel request was not observed'
```

Also assert that progress state transitions are `started`, `progress`, `completed`, and `failed`, and that the source still uses `$env:OS -eq "Windows_NT"`.

- [x] **Step 2: Run the self-test and verify it fails**

Expected: missing Windows Kit functions cause the new test to fail before any GUI code is exercised.

- [x] **Step 3: Implement portable boundary helpers and lazy native dialogs**

Use `Resolve-Path -LiteralPath` for existing paths and return a normalized string. `Convert-WindowsDropItems` must preserve order, remove blank values, and return an empty array for no usable input. Use a mutable PSCustomObject for cancel/progress state. `Select-WindowsPath` and `Save-WindowsPath` may use `System.Windows.Forms` only when explicitly invoked on Windows; return `$null` on user cancellation and keep all reading, writing, encoding, overwrite policy, and Domain validation outside the helper.

- [x] **Step 4: Run tests and verify no GUI dependency is loaded on non-GUI paths**

Run the full self-test and direct helper tests. Expected: path/drop/state assertions pass on the current host; native dialog functions remain lazy and do not run during Base self-test.

- [x] **Step 5: Commit the Windows slice**

```powershell
git add .kinotch/templates/defaults/windows/tools/windows-shell.ps1 .kinotch/tests/run-tests.ps1 project/docs/CURRENT_STATE.md
git commit -m "feat: expand Windows Surface Default Kit"
git push origin main
```

### Task 3: Expand the MCP Surface Kit Without a Second Registry

**Files:**
- Modify: `.kinotch/templates/defaults/mcp/contracts/mcp-tools.json`
- Modify: `.kinotch/tests/run-tests.ps1`
- Modify: `project/docs/CURRENT_STATE.md`

**Interfaces:**
- Consumes: host/framework dispatcher metadata and Project-owned schemas/callbacks.
- Produces: a language-neutral `kinotch-mcp-default-boundary` descriptor containing naming, input schema, working-directory, resource-path, diagnostics, error conversion, capabilities, and dispatch ownership.

- [x] **Step 1: Write failing descriptor assertions**

Extend the existing MCP test to require:

```powershell
Assert-True ($descriptor.tool_name_pattern -eq '^[a-z][a-z0-9_.-]*$') 'MCP naming boundary changed'
Assert-True $descriptor.input_schema_validation 'MCP input validation hook missing'
Assert-True $descriptor.resource_path_resolution 'MCP resource path resolution missing'
Assert-True $descriptor.error_conversion 'MCP error conversion boundary missing'
Assert-True $descriptor.dispatch.use_existing_framework 'MCP descriptor requests a second dispatcher'
```

- [x] **Step 2: Run the self-test and verify it fails**

Expected: current descriptor lacks the new boundary fields.

- [x] **Step 3: Extend the JSON descriptor only**

Add boolean/description fields for validation, working-directory normalization, resource path resolution, structured diagnostics, generic error conversion, version/capability reporting, and explicit `use_existing_framework: true`. Do not add a tool registry or Domain operation names.

- [x] **Step 4: Run schema/doctor/self-tests**

Expected: the materialized JSON remains valid, `doctor` still passes for an initialized MCP Project, and no Runtime dependency is added.

- [x] **Step 5: Commit the MCP slice**

```powershell
git add .kinotch/templates/defaults/mcp/contracts/mcp-tools.json .kinotch/tests/run-tests.ps1 project/docs/CURRENT_STATE.md
git commit -m "feat: expand MCP Surface Default boundary"
git push origin main
```

### Task 4: Expand the API Surface Kit With Replaceable Hooks

**Files:**
- Create: `.kinotch/templates/defaults/api/tools/api-default.ps1`
- Modify: `.kinotch/templates/defaults/api/contracts/api-error-envelope.json`
- Modify: `.kinotch/scripts/knt.ps1` only if doctor needs to recognize the new helper
- Modify: `.kinotch/tests/run-tests.ps1`
- Modify: `project/docs/CURRENT_STATE.md`

**Interfaces:**
- Consumes: optional Project scriptblocks for validation, authentication, rate limiting, logging, and CORS.
- Produces: `New-ApiRequestContext`, `New-ApiHealthResponse`, `New-ApiErrorEnvelope`, and `Invoke-ApiHook` in the materialized helper. These functions return plain objects and do not decide HTTP status, auth mechanism, rate values, provider retry, or Cloudflare policy.

- [ ] **Step 1: Write failing API helper and descriptor tests**

Initialize an `api` Project and assert that `project/tools/api-default.ps1` exists. Dot-source it and assert:

```powershell
$context = New-ApiRequestContext -RequestId 'req-1' -CorrelationId 'corr-1'
Assert-Equal 'req-1' $context.requestId 'request ID'
Assert-Equal 'corr-1' $context.correlationId 'correlation ID'
$health = New-ApiHealthResponse -Name 'sample'
Assert-Equal 'ok' $health.status 'health status'
$error = New-ApiErrorEnvelope -Code 'invalid_input' -Message 'bad input' -Details @{ field = 'value' } -RequestId 'req-1'
Assert-Equal 'invalid_input' $error.error 'error code'
Assert-Equal 'req-1' $error.requestId 'error request ID'
```

Test `Invoke-ApiHook` with a supplied scriptblock and with no hook; the latter must return the input unchanged. Keep the envelope schema permissive and do not require `details`.

- [ ] **Step 2: Run the self-test and verify it fails**

Expected: the API helper file is missing and the new assertions fail.

- [ ] **Step 3: Implement the hook-oriented API helper**

Use plain PSCustomObjects/hashtables. `New-ApiRequestContext` generates a GUID only when no request ID is supplied; it does not validate or rewrite Project IDs. `New-ApiHealthResponse` returns a small data object. `New-ApiErrorEnvelope` preserves the caller’s code/message/details/requestId. `Invoke-ApiHook` accepts `-Hook`, `-Value`, and `-Name`, calls the hook when present, and otherwise returns `Value`. Add the template file to doctor’s selected API implementation list.

- [ ] **Step 4: Run tests and inspect the materialized API files**

Expected: API helper tests, schema tests, doctor, and existing Base tests pass; no HTTP server or Runtime package is introduced.

- [ ] **Step 5: Commit the API slice**

```powershell
git add .kinotch/templates/defaults/api .kinotch/scripts/knt.ps1 .kinotch/tests/run-tests.ps1 project/docs/CURRENT_STATE.md
git commit -m "feat: expand API Surface Default Kit"
git push origin main
```

### Task 5: Documentation, Version Gate, and Release Verification

**Files:**
- Modify: `.kinotch/README_BASE.md` with concise Surface Kit responsibilities and exclusions
- Modify: `.kinotch/meta/07_PHASE5_OPERATIONS.md` or the existing Phase 5 document with the new feature slice
- Modify: `project/docs/CURRENT_STATE.md`
- Modify: `.kinotch/BASE_VERSION` only if implementation scope is confirmed as a functional Base release
- Regenerate: `.kinotch/base-files.json` and `.kinotch/FILE_INVENTORY.txt` through `base-refresh`
- Test: `.kinotch/tests/run-tests.ps1`

**Interfaces:**
- Consumes: completed CLI, Windows, MCP, and API template kits.
- Produces: a self-describing Base v0.4.0 release only when all four kits and their tests are complete; otherwise preserves v0.3.9 and records the partial feature slice accurately.

- [ ] **Step 1: Add documentation assertions**

Add a self-test that confirms the Base docs state that Surface Kits provide Domain-neutral helpers, existing frameworks may remain OVERRIDE, and Runtime contracts are not expanded by this feature. Keep the assertion small and phrase-based.

- [ ] **Step 2: Run the full verification gate before versioning**

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .kinotch/tests/run-tests.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .kinotch/scripts/knt.ps1 doctor
pwsh -NoProfile -ExecutionPolicy Bypass -File .kinotch/scripts/knt.ps1 base-check
pwsh -NoProfile -ExecutionPolicy Bypass -File .kinotch/scripts/knt.ps1 verify
```

Expected: all tests and commands pass. If the complete feature slice is shipped, update `.kinotch/BASE_VERSION` and matching documentation to `0.4.0`; otherwise keep `0.3.9` and document the exact completed subset.

- [ ] **Step 3: Refresh the protected Base index**

Run: `pwsh -NoProfile -ExecutionPolicy Bypass -File .kinotch/scripts/knt.ps1 base-refresh`

Expected: `base-files.json` and `FILE_INVENTORY.txt` are regenerated deterministically and `base-check` passes.

- [ ] **Step 4: Inspect Git state and commit the release slice**

Run:

```powershell
git status --short --branch
git log -5 --oneline --decorate
git diff --check
```

Then commit and push the documentation/version/index changes with `chore: release Surface Default Kit feature slice` and verify local `HEAD` equals `origin/main`.

- [ ] **Step 5: Record the final boundary**

Update `CURRENT_STATE` to state which kits are implemented, that existing repo adoption remains out of scope, Runtime remains 0.1.0, and the next operation is canary use in a selected Project—not bulk migration.
