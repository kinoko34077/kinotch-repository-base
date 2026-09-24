# KiNoTch. Repository Base v0.5.0 実装計画

## Goal

v0.4.0 の Repository Base を、Manifest/command 境界、Default の更新追跡、既存 Surface Kit の整合性、新しい MCP/Agent/Config/Logging Default、文書正本、CI 検証まで含む v0.5.0 として安全に固定する。Runtime の実行意味と package version 0.1.0 は変更しない。

## Working rules

- 変更は安全性・境界を先に行い、各スライスで focused test → full self-test → doctor/base-check/verify を実行する。
- Default の永続状態は `DEFAULT` / `OVERRIDE` / `DISABLED` の3値だけにする。
- 既存 Project の Domain、既存 Framework、Runtime Contract は移動・強制変更しない。
- 各スライス完了時に独立コミットし、検証後に `origin/main` へ push する。

## Tasks

### Task 1 — 安全境界と状態モデル

- RED: Manifest `paths.*`、command `cwd`、minimal/Surface compatibility、Base runtime modules、profile status、catalog IDs の回帰テストを追加。
- GREEN: 既存 path-containment helper に集約した resolver を doctor と command 実行直前へ接続し、compatibility key を init/migrate/doctor で共有する。Base manifest の runtime modules を空配列にし、profile の `status` を除去する。
- VERIFY: focused tests、full self-test、doctor、base-check、verify。
- Commit: `fix: enforce Manifest path boundaries and compatibility keys`

### Task 2 — Default provenance と template-driven doctor

- RED: provenance schema、materialized file hash、modified Default protection、safe upgrade、legacy warning、PWA init/migrate parity のテストを追加。
- GREEN: plan/apply/finalize を共通化し、実生成物から provenance を保存する。doctor は template tree と provenance を用いて実装を検査し、Default-specific switch を廃止する。
- VERIFY: Task 1 の全検証 + provenance/PWA focused tests。
- Commit: `fix: track Default materialization provenance`

### Task 3 — 既存 Kit の境界整合

- RED: CLI `--` terminator、API details の任意JSON値、named hook、file/path boundary の回帰テストを追加。
- GREEN: CLI parser、API schema/helper/hook、既存 generated-integrity/file-io helper の境界を修正する。
- VERIFY: full self-test、doctor、base-check、verify。
- Commit: `fix: align Surface Default contracts`

### Task 4 — CI 検証と新規 MCP/Agent Kit

- RED: MCP executable helper、Agent helper、Windows helper/PowerShell 5.1 focused checks、CI matrix presence のテストを追加。
- GREEN: host-owned boundary を守る薄い MCP/Agent helper を template に追加し、Windows CI matrix を Ubuntu/pwsh、Windows/pwsh、Windows PowerShell 5.1 に拡張する。
- VERIFY: self-test、doctor、base-check、verify、workflow static checks。
- Commit: `feat: add MCP and Agent Surface helpers`

### Task 5 — Config/Logging Tool Default

- RED: catalog exact six IDs、Config precedence/non-mutation/redaction、Logging UTC/stderr/sink/redactor のテストを追加。
- GREEN: catalog/schema/template/doctor provenance path を共通機構へ接続し、Config/Logging helper を追加する。
- VERIFY: full self-test、doctor、base-check、verify。
- Commit: `feat: add config and logging Defaults`

### Task 6 — 正本統合と Base v0.5.0 release

- 更新対象: CURRENT_STATE、SPEC、INDEX、Default-first meta、Target/Roadmap/Extraction/Validation、Runtime Integration、Base Roadmap、README_BASE、ADR 0004。
- Base version、base-files index、file inventory を再生成し、v0.5.0 の自己説明と実装状態を一致させる。
- Canary は read-only shape/doctor 検証に限定し、既存 repo を自動 adopt しない。
- VERIFY: full self-test、doctor、base-check、verify、git diff --check、CI workflow 定義確認。
- Commit: `chore: release Repository Base v0.5.0`

### Task 7 — Runtime embedded Base 同期

- Runtime の `.kinotch/` と Base-managed root files のみ現行 v0.5.0 へ同期する。Runtime package/version 0.1.0、Execution Contract、Portable Contract maturity は変更しない。
- Runtime Current State に embedded Base 0.5.0 と package 0.1.0 を記録する。
- Runtime の doctor/base-check/verify/unittest、working tree、remote を確認する。
- Commit: `chore: sync Repository Base v0.5.0 into Runtime`

## Completion gate

- Base self-test 全件 PASS、doctor/base-check/verify = 0。
- Manifest paths/cwd の repository 境界、Default provenance、safe upgrade、dynamic doctor、compatibility、CLI/API、MCP/Agent/Config/Logging、profile cleanup を回帰確認。
- Ubuntu pwsh、Windows pwsh、Windows PowerShell 5.1 の CI 定義が存在する。
- Base v0.5.0、Runtime embedded Base v0.5.0、Runtime package 0.1.0。
- 各リポジトリの working tree clean、local HEAD = remote main。
