# KiNoTch. Runtime Integration v0.1

Base v0.1はRuntime実装そのものを内包しない。ここでは接続契約だけを固定する。

## 最小Contract

Runtimeへ昇格する共通実装は、必要に応じて以下の意味を共有する。

- Action
- ActionRequest
- ActionContext
- ActionResult
- ActionError
- ProgressEvent
- Cancellation
- Resource
- Artifact
- Config

JSON Schemaは `.kinotch/schemas/` を参照する。

## Module候補

```text
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
```

すべてを一括依存しない。`project/project.json` で必要Moduleだけ宣言する。

## 依存境界

```text
Surface Adapter → Application → Domain Core
       │
       └──── Runtime Contract / Platform Service
```

Domain CoreからGUI / MCP / HTTP / PowerShell等へ直接依存しない。

## Runtimeへ入れないもの

- 各repoのDomain処理
- 個別アルゴリズム
- 個別データモデル
- 個別deploy policy
- 将来用途だけの万能抽象化
