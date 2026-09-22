# Default Pack rollout dry-run

Last inspected: 2026-09-23

This is a read-only classification of the locally available Git repositories.
No repository outside `kinotch-repository-base` was modified, migrated, or
given a KiNoTch Base copy. `OVERRIDE` means an existing implementation or
policy is already authoritative; `DEFAULT` means a removable Default is a
candidate for a future explicit migration; `DISABLED` means the Project should
not provide the Default; `N/A` means the repository is not a suitable target or
was not available in the local checkout.

The scan checked repository identity, `.kinotch/`, package/Cargo/Python
markers, source/test directories, public/static assets, and GitHub workflows.
It was evidence for adoption planning, not an authorization to rewrite any
Project.

## Locally available repositories

| Repository | Detected shape | Surface candidates | Tool candidates | Recommended state | Reason / existing equivalent |
| --- | --- | --- | --- | --- | --- |
| `.ai-guidelines` | policy repository | N/A | N/A | N/A | Cross-repository policy source, not a KiNoTch Project target. |
| `2bit-cell-automaton` | Git repository, no standard marker detected | N/A | N/A | N/A | Inspect when actively developed; no safe automatic inference. |
| `cloudflare-migration/clock-server` | Node / source | N/A | N/A | N/A | Provider-specific service boundary. |
| `cloudflare-migration/detemuhann-redirect` | Node / source | N/A | N/A | N/A | Redirect and deploy policy remain Project-owned. |
| `cloudflare-migration/legacy-clock` | Node / source | N/A | N/A | N/A | Legacy service; no adoption by structure alone. |
| `cloudflare-migration/lyric_reader_page` | Node / tests / workflow | `web-app=OVERRIDE` | `verify=OVERRIDE`, `pwa=N/A` | OVERRIDE | Existing reader/writer quality gates and browser boundaries are authoritative. |
| `cloudflare-migration/rokuyo-proxy` | Node / source | N/A | N/A | N/A | Proxy-specific transport and deployment policy. |
| `cloudflare-migration/standby-display` | Node / web assets / tests / workflow | `web-app=OVERRIDE` | `verify=OVERRIDE`, `ci-test=OVERRIDE`, `generated-integrity=OVERRIDE`, `pwa=OVERRIDE` | OVERRIDE | Existing build-assets, tests, PWA, and release gates already exist. |
| `cloudflare-migration/weather-proxy` | Node / source | N/A | N/A | N/A | Proxy-specific transport and deployment policy. |
| `colony-ai` | Python / tests | `cli=DEFAULT` | `local-app=DEFAULT`, `verify=N/A` | DEFAULT candidate | Repeated setup/run/diagnose shape is a safe local-tool candidate; no Base entry exists yet. |
| `cora_engine` | Git repository, no standard marker detected | N/A | N/A | N/A | No reliable Surface or Tool inference from the local root. |
| `dev_agent` | Python / source / tests / workflow | `agent=OVERRIDE`, `cli=OVERRIDE` | `local-app=OVERRIDE`, `ci-test=OVERRIDE` | OVERRIDE | AgentBackend, recovery, provider, and gate policy are already Project-owned. |
| `IDS-Composit` | Node / source / tests / workflow | `web-app=OVERRIDE`, `library=OVERRIDE` | `verify=OVERRIDE`, `ci-test=OVERRIDE`, `generated-integrity=OVERRIDE`, `pages=OVERRIDE` | OVERRIDE | Vite, calibration, generated data, and Pages policy already have explicit gates. |
| `jev-audit` | Python / tests / workflow | `cli=OVERRIDE`, `mcp=OVERRIDE` | `verify=OVERRIDE`, `ci-test=OVERRIDE` | OVERRIDE | Existing CLI/MCP and optional Runtime Pilot paths are authoritative. |
| `kinotch-api` | Node / Hono / source / workflow | `api=OVERRIDE` | `verify=OVERRIDE`, `ci-test=OVERRIDE`, `generated-integrity=OVERRIDE` | OVERRIDE | Worker bindings, error codes, generated snapshots, and deploy gates are Project-owned. |
| `line-style-viewer` | Git repository, no standard marker detected | `web-app=DEFAULT` | `verify=N/A` | DEFAULT candidate | Likely web-oriented, but exact commands require an active Project review. |
| `Mapience-prototype` | Git repository, no standard marker detected | N/A | N/A | N/A | Too little local structure for safe adoption. |
| `memory-game` | Git repository, no standard marker detected | `web-app=DEFAULT` | `verify=N/A` | DEFAULT candidate | Web candidate by repository purpose, pending active Project verification. |
| `obsidian-related-notes-view` | Node / source | `library=OVERRIDE` | `verify=N/A` | OVERRIDE | Host/plugin lifecycle is Project-specific. |
| `refil-viewer` | Node / web assets / source | `web-app=OVERRIDE` | `verify=OVERRIDE` | OVERRIDE | Existing viewer toolchain is already the natural implementation boundary. |
| `Structured-Cell-Automaton` | Python | `library=OVERRIDE` | `local-app=OVERRIDE` | OVERRIDE | Existing Python/domain structure should remain authoritative. |
| `SynTrail-LM` | Rust / GUI / trainer / tests | `windows=OVERRIDE`, `cli=OVERRIDE` | `file-io=OVERRIDE` | OVERRIDE | Native GUI, trainer state, persistence, and file operations are already Domain-aware. |
| `txt-auto-replace` | Git repository, no standard marker detected | `cli=DEFAULT` | `local-app=DEFAULT` | DEFAULT candidate | Small local utility candidate; inspect commands before any apply. |
| `weather-widget` | Git repository, no standard marker detected | `web-app=DEFAULT` | `verify=N/A` | DEFAULT candidate | Web candidate by repository purpose, pending active Project verification. |

## Referenced but not present in the local checkout

The following names from the rollout instruction were not found under the
local `Documents/Programs` repository scan, so they remain `N/A` and were not
modified: `Gomoku-5D`, `Micro-Chordbot`, `microtone-piano`, and `srt2subtitle`.

## Canary decision

The first canaries are not automatically migrated because each already has
Project-owned gates or provider policy. The safe next operation for an active
canary is a repository-local Base adoption review, starting with:

- `standby-display`: preserve existing `verify`, CI, PWA, and generated-integrity as `OVERRIDE`.
- `jev-audit`: preserve CLI/MCP and optional Runtime behavior as `OVERRIDE`.
- `kinotch-api`: preserve API error, Worker binding, generated snapshot, and deploy boundaries as `OVERRIDE`.
- `SynTrail-LM`: preserve native Windows/file I/O/trainer behavior as `OVERRIDE`.
- `lyric_reader_page`: preserve reader/writer and mobile gates as `OVERRIDE`.

This report intentionally stops before `knt migrate --apply`. Applying a Default
requires an active repository decision and a clean, repository-specific test
run.
