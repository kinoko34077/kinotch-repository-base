# 02 — Roadmap

Current position: Phase 3 Default Pack implementation. Phase 2A Portable
Contract validation remains independent and provisional; Default adoption does
not wait for Portable Contract maturity.

## Phase 0 — Repository Base v0.1系

目的: 個別差分と共通基盤の境界を実物として固定する。

含める:

- 共通 `AGENTS.md`
- `.kinotch/` 共通規約
- `project/` 個別領域
- Project Manifest
- Action / Result / Error / Progress / Resource / Surface Schema
- `knt` command router
- doctor / verify / base-check
- Current State / SPEC / ADRの最小骨格
- Base / Runtime構想のMeta資料

完了条件:

- 新規repoの開始点としてZIPをそのまま利用できる。
- 共通と個別の変更場所が迷わず判別できる。
- Baseファイルの意図しない変更を検出できる。

## Phase 1 — KiNoTch. Runtime Kernel v0.1

目的: 複数Surface / repoが共有する最小実装を切り出す。

初期候補:

- Action / ActionRequest / ActionContext
- ActionResult / ActionError
- Resource / Artifact
- Progress / Cancellation
- Config
- Filesystem
- Logging

注意:

- Domain処理は入れない。
- 言語横断では契約を優先し、巨大な共通libraryを無理に共有しない。

## Phase 2A — 代表repoでPortable Contractを検証

最低3系統で検証する。

1. CLI + MCP: `jev-audit`系
2. Windows GUI + CLI: `SynTrail-LM`系
3. API / Web: `kinotch-api` / `standby-display`系

追加候補:

- Agent: `dev_agent`
- Local GUI/Web: `srt2subtitle`
- Library/Web: `IDS-Composit`

目的は「移行すること」ではなく、**Base / Runtimeの意味を持つ抽象が実際に簡素化になるか検証すること**。

Phase 2Aでは、Default導入の可否をPortable Contract成熟度でブロックしない。

## Phase 2B — Default extraction

目的: Portable Contractの安定を待たず、低リスクで外せる共通便利機能を
Project単位で選択できるDefaultとして定義する。

- Default状態 `DEFAULT` / `OVERRIDE` / `DISABLED`
- CLI / Windows / MCP / APIのDefault候補整理
- 既存Framework・Project実装との二重化確認
- `knt init`の生成境界と非破壊条件
- Surface DefaultとTool Defaultを別軸で管理するDefault Catalog

DefaultはDomain処理、公開互換性、永続形式、provider policyを所有しない。

## Phase 3A — Default Catalog / state / selection

複数repoで厳密なPortable Contract証明を待たず、Default条件を満たすものを
Surface Default / Tool Defaultとして提供する。Projectからoverride / disable
できることを必須とする。Surface選択はRuntime module選択と独立させる。

### Surface Defaults

- `minimal`
- `web-app`
- `cli`
- `windows` (`windows-gui` profile alias)
- `mcp`
- `api`
- `agent`
- `library`

### Tool Defaults

- `verify`
- `ci-test`
- `generated-integrity`
- `file-io`
- `pwa`
- `pages`
- `secrets`
- `local-app`

Default identifier・互換Surface・説明の正本は
`.kinotch/defaults/catalog.json` とする。

完了:

- Surface / Tool Defaultの分離
- 8 Surface profileと`windows` alias
- Runtime module自動注入の廃止
- Catalog駆動`init` / `migrate`
- `DEFAULT` / `OVERRIDE` / `DISABLED` state管理

## Phase 3B — Actual Default behavior

現在位置。Catalogで選択したDefaultへ、Domainを拘束しない実装を与える。

- `verify`: common router、direct verifyまたはtest→build fallback
- `ci-test`: non-deploy GitHub Actions verify workflow
- `generated-integrity`: SHA-256 metadata、check、update helper
- `web-app` / `pwa`: manifest、pass-through service worker、registration helper、check
- `file-io`: format-independent open/save boundary and safe helper
- `secrets` / `local-app`: templateのsecret hygieneと共通command vocabulary

未実装・Project-owned:

- Pages deploy
- Domain-specific file format、GUI picker、D&D、provider retry
- Runtime module、ActionResult、Artifact domain object

### CLI

- common options
- JSON output
- stdout / stderr
- exit code
- dry-run

### Windows

- native menu
- File / Folder picker
- Save / Save As
- D&D
- Progress
- Cancel
- Error dialog
- Reveal output

### MCP

- Action → Tool mapping
- schema validation
- working-directory/resource resolution
- structured error

### API

- validation
- error envelope
- request ID
- auth hook
- rate-limit hook
- smoke / health

## Phase 4 — init / migrate and existing repository adoption

- `knt init --profile <surface> --default <tool-default>`
- 複数Surface / Tool Default選択による初期化
- `knt migrate` dry-runと明示的`--apply`
- generated artifact管理
- stale check
- より詳細なdoctor
- Base conformance report
- ManifestなしRepositoryのread-only shape probe

`knt init` はCatalogを参照して選択SurfaceとTool Defaultの構成、Project
Overlayを生成する。Surface選択からRuntime moduleを自動注入しない。
`knt migrate` は差分を表示し、明示選択されたものだけ適用する。Domain
fileは自動書換えしない。

## Phase 5 — 既存repoへの段階導入

全repoを一括書換えしない。

- 改修するrepoから順次適用
- project固有ロジックは無理に移動しない
- 複数repoで反復確認できた知識だけBase / Runtimeへ昇格
- 既存互換性を壊してまで形式統一しない
- まず全所有repoへdry-runし、`DEFAULT` / `OVERRIDE` / `DISABLED` / `N/A`
  を分類する
- CanaryはWeb / Verify、Generated Integrity、CLI / MCP、File I/O / Windows、
  APIの各系統から段階的に確認する

## Phase 6 — 安定化

必要性が実証された場合のみ進める。

- Base version migration policy
- Runtime version compatibility
- multi-language bindings
- generated docs / MCP / API descriptors
- project scaffolding高度化

Phase 6は必須到達点ではない。Base / Runtimeが十分単純なまま実用性を満たすなら、そこで止める。
