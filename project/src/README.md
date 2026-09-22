# Source

個別実装を置く。

規模が必要な場合の推奨境界:

```text
core/         Domain規則・純粋処理
application/  Action / use case
adapters/     CLI / GUI / API / MCP / external service / OS
```

小規模repoでは階層化そのものを目的にせず、この直下から開始してよい。
