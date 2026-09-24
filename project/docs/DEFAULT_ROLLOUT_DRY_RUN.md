# Default Pack rollout dry-run

Last inspected: 2026-09-24

This is the Phase 4A read-only classification of the locally available Git
repositories. At the time of this report no repository outside
`kinotch-repository-base` was modified, migrated, or given a KiNoTch Base copy.
`OVERRIDE` means an existing implementation or
policy is already authoritative; `DEFAULT` means a removable Default is a
candidate for a future explicit migration; `DISABLED` means the Project should
not provide the Default; `N/A` means the repository is not a suitable target or
was not available in the local checkout.

The scan checked repository identity, `.kinotch/`, package/Cargo/Python
markers, source/test directories, public/static assets, and GitHub workflows.
The current Catalog contains six Tool Defaults: `ci-test`,
`generated-integrity`, `file-io`, `pwa`, `config`, and `logging`; `knt verify`
remains an L1 command.
It was evidence for adoption planning, not an authorization to rewrite any
Project.

## Phase 4C operation state / Phase 5 baseline

This table is the current operational record after the Phase 4C reviews. The
`State` column describes repository adoption work only; it is not a Default
maturity or Portable Contract status. `N/A` means that the repository is not a
safe or locally available adoption target at this time.

| Repository | Current Base version | Detected Surface | Tool Defaults | State | Verification | Next action |
| --- | --- | --- | --- | --- | --- | --- |
| `jev-audit` | `0.3.8` | `cli`, `mcp` | `ci-test=OVERRIDE` | `ADOPTED` | doctor/base-check/verify; 52 unittest tests, 1 skipped | Phase 5 maintenance |
| `kinotch-api` | `0.3.8` | `api` | `ci-test=OVERRIDE`, `generated-integrity=OVERRIDE` | `ADOPTED` | doctor/base-check/verify; npm 207 passed, 1 skipped locally | Phase 5 maintenance; recheck hosted status when available |
| `lyric_reader_page` | `0.3.8` | `web-app` | `ci-test=OVERRIDE` | `ADOPTED` | doctor/base-check/verify; npm 129 tests | Phase 5 maintenance |
| `weather-widget` | `0.3.8` | `web-app` | `pwa=OVERRIDE` | `ADOPTED` | doctor/base-check/verify | Phase 5 maintenance |
| `memory-game` | `0.3.8` | `web-app` | none | `ADOPTED` | doctor/base-check/verify | Phase 5 maintenance |
| `Structured-Cell-Automaton` | `0.3.8` | `web-app` | none | `ADOPTED` | doctor/base-check/verify | Phase 5 maintenance |
| `2bit-cell-automaton` | `0.3.8` | `web-app` | none | `ADOPTED` | doctor/base-check/verify | Phase 5 maintenance |
| `colony-ai` | `0.3.8` | `cli` | none | `ADOPTED` | doctor/base-check/setup/verify; 20 unittest tests | Phase 5 maintenance |
| `refil-viewer` | `0.3.8` | `web-app` | none | `STAGED` | doctor/base-check pass; verify blocked by existing duplicate `pageIndex` in `src/App.vue` | Project bugfix, then test/build/verify |
| `standby-display` | — | `web-app` | `pwa=OVERRIDE`, `generated-integrity=OVERRIDE`; `ci-test` not inferred | `STAGED` | read-only shape probe; npm test 13 passed; existing PWA/build boundaries present | Decide root hygiene merge; then local Base adoption and full verification |
| `SynTrail-LM` | — | `windows`, `cli` | `file-io=OVERRIDE` | `STAGED` | read-only review; existing Cargo tests recorded as passing, but worktree is user-owned dirty | Clean owner boundary, then explicit adoption review |
| `dev_agent` | — | `agent`, `cli` | `ci-test=OVERRIDE` | `NOT_ADOPTED` | read-only shape probe; no repository-local `.kinotch/`, root hygiene conflict | Explicit Base adoption decision; preserve AgentBackend and gate policy |
| `IDS-Composit` | — | `web-app`, `library` | `ci-test=OVERRIDE`, `generated-integrity=OVERRIDE` | `NOT_ADOPTED` | read-only shape probe; existing Vite/calibration/generated gates; no repository-local `.kinotch/` | Explicit adoption decision; keep Pages and generated-data policy Project-owned |
| `srt2subtitle` | N/A | `web-app` | `ci-test=OVERRIDE` | `N/A` | GitHub-only tree inspection; no local checkout verification | Revisit when locally active |
| `Gomoku-5D` | N/A | `web-app` | `ci-test=OVERRIDE` | `N/A` | GitHub-only tree inspection | Revisit when locally active |
| `Micro-Chordbot` | N/A | `web-app` | `ci-test=OVERRIDE` | `N/A` | GitHub-only tree inspection | Revisit when locally active |
| `microtone-piano` | N/A | `web-app` | `pwa=OVERRIDE` | `N/A` | GitHub-only tree inspection | Revisit when locally active |
| `.ai-guidelines` | — | N/A | N/A | `N/A` | Policy source, not a KiNoTch Project target | Keep as policy source |
| `cloudflare-migration/clock-server` | — | N/A | N/A | `N/A` | Read-only local shape review | No adoption by structure alone |
| `cloudflare-migration/detemuhann-redirect` | — | N/A | N/A | `N/A` | Read-only local shape review | Keep redirect/deploy policy Project-owned |
| `cloudflare-migration/legacy-clock` | — | N/A | N/A | `N/A` | Read-only local shape review | Legacy service; revisit only with active work |
| `cloudflare-migration/rokuyo-proxy` | — | N/A | N/A | `N/A` | Read-only local shape review | Keep proxy/deploy boundary Project-owned |
| `cloudflare-migration/weather-proxy` | — | N/A | N/A | `N/A` | Read-only local shape review | Keep provider boundary Project-owned |
| `cora_engine` | — | N/A | N/A | `N/A` | No reliable standard marker in local root | Revisit when actively developed |
| `line-style-viewer` | — | `web-app` | none | `N/A` | Existing static viewer; no Base adoption | Revisit with active Project decision |
| `Mapience-prototype` | — | N/A | N/A | `N/A` | Too little local structure for safe inference | Do not force adoption |
| `obsidian-related-notes-view` | — | `library` | none | `N/A` | Existing host/plugin lifecycle is Project-owned | Revisit with active Project decision |
| `txt-auto-replace` | — | `browser-extension` | N/A | `N/A` | Browser-extension Surface is outside the current catalog | Do not misclassify as CLI/local-app |

## Phase 4 Canary validation

On 2026-09-23 the five first Canary repositories were rechecked with the
Base-owned shape probe using `-BaseOverride`. The probe was read-only and no
Canary received a Base copy or `migrate --apply` change. Existing Project
implementations remain authoritative and are classified as `OVERRIDE` where
the shape probe can identify an equivalent boundary.

| Canary | Shape probe result | Repository verification | Adoption decision |
| --- | --- | --- | --- |
| `standby-display` | `web-app`; `pwa=OVERRIDE` from `manifest.json` + `service-worker.js` | `npm test`: 13 passed | Keep PWA, asset build, and release behavior Project-owned; no Default files added. |
| `jev-audit` | `cli`, `mcp`; `ci-test=OVERRIDE` | `python -m unittest discover -s tests`: 52 tests, 1 skipped | Keep CLI/MCP and Runtime Pilot paths Project-owned; do not add a second setup/runtime layer. |
| `kinotch-api` | `api`; `ci-test=OVERRIDE`, `generated-integrity=OVERRIDE` | `npm test`: 207 passed, 1 skipped | Keep Worker, generated snapshot, error, and deploy boundaries Project-owned. |
| `SynTrail-LM` | `cli`; no Tool Default candidate | `cargo test`: 237 library tests + 185 integration tests passed | Keep native Windows, trainer, persistence, and file I/O Project-owned. Existing dirty user files were not touched. |
| `lyric_reader_page` | `web-app`; `ci-test=OVERRIDE` | `npm test`: 129 passed | Keep reader/writer and browser quality gates Project-owned. |

The shape probe now distinguishes an existing equivalent from a missing
convenience in dry-run output, for example `state OVERRIDE (existing
equivalent detected)`. A `DEFAULT` candidate is not applied automatically.
The Base structure is not copied into these repositories because they do not
yet have a KiNoTch Project Manifest and moving their existing Domain files
would violate the non-destructive adoption rule.

## Locally available repositories

| Repository | Detected shape | Surface candidates | Tool candidates | Recommended state | Reason / existing equivalent |
| --- | --- | --- | --- | --- | --- |
| `.ai-guidelines` | policy repository | N/A | N/A | N/A | Cross-repository policy source, not a KiNoTch Project target. |
| `2bit-cell-automaton` | Git repository, no standard marker detected | N/A | N/A | N/A | Inspect when actively developed; no safe automatic inference. |
| `cloudflare-migration/clock-server` | Node / source | N/A | N/A | N/A | Provider-specific service boundary. |
| `cloudflare-migration/detemuhann-redirect` | Node / source | N/A | N/A | N/A | Redirect and deploy policy remain Project-owned. |
| `cloudflare-migration/legacy-clock` | Node / source | N/A | N/A | N/A | Legacy service; no adoption by structure alone. |
| `cloudflare-migration/lyric_reader_page` | Node / tests / workflow | `web-app=OVERRIDE` | `ci-test=OVERRIDE`, `pwa=N/A` | OVERRIDE | Existing reader/writer quality gates and browser boundaries are authoritative. |
| `cloudflare-migration/rokuyo-proxy` | Node / source | N/A | N/A | N/A | Proxy-specific transport and deployment policy. |
| `cloudflare-migration/standby-display` | Node / web assets / tests / PWA | `web-app=OVERRIDE` | `ci-test=OVERRIDE`, `generated-integrity=OVERRIDE`, `pwa=OVERRIDE` | OVERRIDE | Existing `build-assets`, tests, PWA, and release gates already exist; no generic helper is added. |
| `cloudflare-migration/weather-proxy` | Node / source | N/A | N/A | N/A | Proxy-specific transport and deployment policy. |
| `colony-ai` | Python / tests | `cli=DEFAULT` | `N/A` | DEFAULT candidate | No active Tool Default is inferred without a repository-local Base decision. |
| `cora_engine` | Git repository, no standard marker detected | N/A | N/A | N/A | No reliable Surface or Tool inference from the local root. |
| `dev_agent` | Python / source / tests / workflow | `agent=OVERRIDE`, `cli=OVERRIDE` | `ci-test=OVERRIDE` | OVERRIDE | AgentBackend, recovery, provider, and gate policy are already Project-owned. |
| `IDS-Composit` | Node / source / tests / workflow | `web-app=OVERRIDE`, `library=OVERRIDE` | `ci-test=OVERRIDE`, `generated-integrity=OVERRIDE` | OVERRIDE | Vite, calibration, generated data, and Pages policy already have explicit gates. |
| `jev-audit` | Python / tests / workflow | `cli=OVERRIDE`, `mcp=OVERRIDE` | `ci-test=OVERRIDE` | OVERRIDE | Existing setup, CLI/MCP, tests, and optional Runtime Pilot paths are authoritative. |
| `kinotch-api` | Node / Hono / source / workflow | `api=OVERRIDE` | `ci-test=OVERRIDE`, `generated-integrity=OVERRIDE` | OVERRIDE | Worker bindings, error codes, generated snapshots, and deploy gates are Project-owned. |
| `line-style-viewer` | Static Web files (`index.html`, JS, CSS) | `web-app=OVERRIDE` | `N/A` | OVERRIDE | Existing static viewer is already the Project implementation. |
| `Mapience-prototype` | Git repository, no standard marker detected | N/A | N/A | N/A | Too little local structure for safe adoption. |
| `memory-game` | Static Web files (`index.html`, JS, CSS) | `web-app=OVERRIDE` | `N/A` | OVERRIDE | Existing browser game implementation is already the Project boundary. |
| `obsidian-related-notes-view` | Node / source | `library=OVERRIDE` | `N/A` | OVERRIDE | Host/plugin lifecycle is Project-specific. |
| `refil-viewer` | Node / web assets / source | `web-app=OVERRIDE` | `N/A` | OVERRIDE | Existing viewer toolchain is already the natural implementation boundary. |
| `Structured-Cell-Automaton` | Python / Streamlit / GUI scripts | `web-app=OVERRIDE` | `N/A` | OVERRIDE | Streamlit GUI and local data flow are Project-owned; it is not a library Surface. |
| `SynTrail-LM` | Rust / GUI / trainer / tests | `windows=OVERRIDE`, `cli=OVERRIDE` | `file-io=OVERRIDE` | OVERRIDE | Native GUI, trainer state, persistence, and file operations are already Domain-aware. |
| `txt-auto-replace` | Chrome Manifest V3 browser extension | `browser-extension=N/A` | `N/A` | N/A | Browser-extension is not a current Surface Profile; do not misclassify it as CLI/local-app. |
| `weather-widget` | Static Web/PWA (`manifest.webmanifest`, service worker) | `web-app=OVERRIDE` | `pwa=OVERRIDE` | OVERRIDE | Existing PWA files are already present; no replacement should be generated. |

## GitHub-only repositories now inspected

These repositories were checked read-only through their GitHub default-branch
tree because no local checkout was available. They remain unmodified.

| Repository | Detected shape | Surface candidates | Tool candidates | Recommended state | Reason / existing equivalent |
| --- | --- | --- | --- | --- | --- |
| `Gomoku-5D` | Vite / React / TypeScript / public assets / tests | `web-app=OVERRIDE` | `ci-test=OVERRIDE` | OVERRIDE | Existing Vite and game test/build scripts are Project-owned. |
| `Micro-Chordbot` | Browser-oriented Web/PWA assets / Pages workflows | `web-app=OVERRIDE` | `ci-test=OVERRIDE` | OVERRIDE | Existing browser assets and Pages deployment define release behavior. |
| `microtone-piano` | Static Web/PWA assets / Pages workflow / audio data | `web-app=OVERRIDE` | `pwa=OVERRIDE` | OVERRIDE | Existing manifest, icons, audio format, and Pages deployment are authoritative. |
| `srt2subtitle` | Python backend / Cloudflare frontend / Pages workflows | `web-app=OVERRIDE` | `ci-test=OVERRIDE` | OVERRIDE | Local transcription and Cloudflare/Pages boundaries are Project-owned. |

## Canary decision

The first canaries are not automatically migrated because each already has
Project-owned gates or provider policy. The safe next operation for an active
canary is a repository-local Base adoption review, starting with:

- `standby-display`: preserve existing `verify` command, CI, PWA, and generated-integrity as `OVERRIDE`.
- `jev-audit`: preserve CLI/MCP and optional Runtime behavior as `OVERRIDE`.
- `kinotch-api`: preserve API error, Worker binding, generated snapshot, and deploy boundaries as `OVERRIDE`.
- `SynTrail-LM`: preserve native Windows/file I/O/trainer behavior as `OVERRIDE`.
- `lyric_reader_page`: preserve reader/writer and mobile gates as `OVERRIDE`.

The Phase 4A report intentionally stopped before `knt migrate --apply`. Applying a
Default still requires an active repository-local Manifest, an explicit pack
selection, and a clean repository-specific test run. For the five Canaries
above, validation supports preserving existing behavior rather than adding
generated helpers. Phase 4C then recorded the remaining adoption decisions in
the operation-state table above; no bulk migration follows from that review.

## Phase 4B adoption status

The first eight clean Canary adoptions were completed after the v0.3.7 safety
hardening. Their common layer was subsequently synchronized to Base v0.3.8.
Existing Domain files were not moved, and all detected equivalent Surface /
Tool implementations were recorded as `OVERRIDE`.

| Repository | Latest Base sync commit | Local verification | Result |
| --- | --- | --- | --- |
| `jev-audit` | `2566e9b` | `doctor`, `base-check`, `verify`, 52 unittest tests | Base v0.3.8 synchronization; CLI/MCP/CI/generated boundaries preserved |
| `kinotch-api` | `204d15e` | `doctor`, `base-check`, `verify`, 207 passed / 1 skipped | Base v0.3.8 synchronization; API/MCP/CI/generated boundaries preserved |
| `lyric_reader_page` | `81e7ef5` | `doctor`, `base-check`, `verify`, 129 npm tests | Base v0.3.8 synchronization; web/reader/writer/browser boundaries preserved |
| `weather-widget` | `6a3eda1` | `doctor`, `base-check`, `verify` | Base v0.3.8 synchronization; existing Web/PWA boundaries preserved |
| `memory-game` | `6a6dd8f` | `doctor`, `base-check`, `verify` | Base v0.3.8 synchronization; existing static Web game boundary preserved |
| `Structured-Cell-Automaton` | `7a0d313` | `doctor`, `base-check`, `verify` | Base v0.3.8 synchronization; existing Streamlit GUI and Domain boundary preserved |
| `2bit-cell-automaton` | `5c2c688` | `doctor`, `base-check`, `verify` | Base v0.3.8 synchronization; existing static Web experiment boundary preserved |
| `colony-ai` | `7a2e5a6` | `doctor`, `base-check`, `setup`, `verify`, 20 unittest tests | Base v0.3.8 synchronization; existing Python CLI/Tkinter and Ollama boundaries preserved |

`refil-viewer` was prepared separately and most recently synchronized in
commit `d4b0c02`. Its repository-local Base and `web-app=OVERRIDE` state pass
`doctor` and `base-check`, but
`knt verify` correctly returns exit code 1 because the existing Vite source has
duplicate `pageIndex` declarations in `src/App.vue`. It remains staged rather
than a clean Canary adoption.

The Base v0.3.8 root hygiene, Shape Probe compatibility filter, and Project
command exit-code propagation fix were synchronized into the adopters after
their first local verification. The remaining Canaries (`standby-display` and
`SynTrail-LM`) remain staged for separate repository-local decisions;
`SynTrail-LM` currently has user-owned dirty files and is not eligible for
automatic adoption. `standby-display` is clean, but its existing
`.editorconfig`, `.gitattributes`, and `.gitignore` require an explicit merge
decision before Base-managed root files are introduced. `dev_agent` and
`IDS-Composit` are recorded as `NOT_ADOPTED` until their own Base introduction
is explicitly approved; GitHub-only candidates are `N/A` until a local active-
work decision exists.

## Phase 4C closeout

Phase 4C is complete as an adoption decision phase. Eight clean repositories
are adopted at Base v0.3.8. `refil-viewer` remains staged for its existing
Project-owned Vite error; `standby-display` remains staged for root hygiene
merge review; `SynTrail-LM` remains staged without touching its dirty worktree;
and `dev_agent`, `IDS-Composit`, and unavailable GitHub-only repositories are
not automatically migrated. Phase 5 now governs future adoption as part of
normal repository maintenance.

## Phase 5 Default adoption canary

On 2026-09-24 a dedicated repository, `kinotch-default-canary`, was created
with `knt init` and finalized against Base v0.5.2. It selected `cli`,
`ci-test`, `config`, and `logging` as `DEFAULT` packs and recorded source Base
version plus final materialized-file hashes in `project/defaults.json`.

The canary contains only a small Project-owned verification script. The
generated helpers remain unchanged. Its targeted gates passed:

- `knt doctor`
- `knt base-check`
- `knt verify`

The canary is committed at `355aaa3` and published as the private
`kinoko34077/kinotch-default-canary` repository. The Base Verify run
`36012972464` and generated Default Verify run `36012972686` both passed on
the Base v0.5.2 sync push. It is evidence
for new-repository initialization, not a claim that an existing repository has
been adopted. Existing repositories remain governed by their recorded
`OVERRIDE`, `STAGED`, `NOT_ADOPTED`, or `N/A` decisions.
