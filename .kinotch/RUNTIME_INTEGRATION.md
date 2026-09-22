# KiNoTch. Runtime Integration v0.2

Base v0.2はRuntime実装そのものを内包しない。ここではRepository Baseと将来のRuntimeの責任境界、接続宣言、Contractの検証状態を固定する。

## Base v0.2で定義済み

以下はBaseにSchemaまたはRegistryとして存在し、Repository構造と宣言の検証に利用する。

- Action Registry
- Action Result
- Action Error
- Progress Event
- Resource
- Artifact
- Project Manifest
- Profile
- Surface declaration

これらのSchemaは .kinotch/schemas/ を参照する。Schemaは構文の正本であり、Runtimeの実行実装を意味しない。

## Runtime Phase 1候補

以下はRuntime実装とPilotで意味・所有権を検証してから確定する。

- ActionRequest
- ActionContext
- Cancellation
- Config execution semantics
- filesystem / logging / platform service bindings

候補はBase v0.xでは存在するpackageや実装を意味しない。

## 現在のRuntime Contract正本

`kinotch-runtime` v0.1が作成済みとなった現在、Execution Contractの正本は
以下である。

```text
kinotch-runtime/project/contracts/execution/
```

Base側の以下は、Repository Baseの検証互換コピーとして扱う。

```text
.kinotch/schemas/
```

関係は次で固定する。

```text
Runtime canonical source
        ↓ explicit, reviewed synchronization when needed
Base compatibility schema
```

BaseとRuntimeでExecution Schemaを独立編集してはならない。同期が必要に
なった場合も、Runtime正本の変更とBase互換コピーの更新を別責務として
レビュー・検証する。自動同期toolは、Contractの変更頻度と第2Pilotの
結果を確認するまで追加しない。

## 所有権

Repository Baseが所有するもの:

- Project Manifest
- Profile
- Repository structure
- Surface declaration
- Runtime version reference
- Runtime module declaration
- Base validation and common command vocabulary

KiNoTch. Runtimeが所有するもの:

- Action execution
- Result / Error / Progress execution semantics
- Resource / Artifact runtime behavior
- Cancellation
- Config execution behavior
- Language-specific bindings

Runtimeの正本ContractはRuntime Repositoryへ移行済みである。Baseは必要な
version参照、Repository構造検証、および明示的な互換Schema同期だけを担う。

Contractの成熟度（implemented / unit-tested / pilot-exercised /
multi-repo-validated / stable）はRuntime側のContract Matrixで管理し、
Baseは一括してstableとみなさない。

## Module候補

~~~text
kernel
config
errors
progress
resources
filesystem
logging
cli
windows
mcp
api
agent
tooling.doctor
tooling.verify
tooling.generated
tooling.bootstrap
~~~

すべてを一括依存しない。 project/project.json の runtime.modules は必要Moduleの論理宣言であり、Base v0.xでは実在packageを強制しない。

## 依存境界

~~~text
Surface Adapter -> Application -> Domain Core
       |
       +---- Runtime Contract / Platform Service
~~~

Domain CoreからGUI / MCP / HTTP / PowerShell等へ直接依存しない。

## Runtimeへ入れないもの

- 各repoのDomain処理
- 個別アルゴリズム
- 個別データモデル
- 個別deploy policy
- 将来用途だけの万能抽象化

## .ai-guidelinesとの関係

BaseはRepository / Agent / implementation workflowを所有する。.ai-guidelines はUI/UXとDomain横断設計ポリシーを所有する。両者は責任を参照し、同一規則を全文複製しない。
