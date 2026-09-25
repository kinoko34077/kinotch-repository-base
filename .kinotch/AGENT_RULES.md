# Common Agent Rules

## Read Economy

毎回全ファイルを読まない。`AGENTS.md` の読取順序から開始し、現在問に必要な資料だけ取得する。

横断管理対象のGitHub作業では、`AGENTS.md`の指示どおり対象Repositoryのdevflow Control Issueを先に確認する。ローカルだけで完結し横断Current Stateが結果へ影響しない作業では不要な横断読取を増やさない。

## Source of Truth

- 横断管理ルール / 横断Current State: devflow
- 個別定義: `project/project.json`
- 個別仕様: `project/docs/`
- 現在状態: `project/docs/CURRENT_STATE.md`
- repository-local task/finding: local Issue / Work Order
- diff/verification: local PR / CI / tests
- Action: `project/contracts/actions.json`
- Surface差分: `project/contracts/surfaces.json`
- Base Meta: `.kinotch/meta/`
- 新規Repository用Template: `.kinotch/templates/project/`

実装コードが仕様と衝突した場合、勝手にコードを正本化しない。

Base-wide MetaとTemplateは共通層に置く。個別Projectの情報を `.kinotch/` へ書かない。

## Cross-repository GitHub workflow

横断管理の正本はdevflowに置く。本Baseでは状態語彙・Issue lifecycle・Project設定を第二の正本として再定義しない。

参照順:

1. devflow root `AGENTS.md`
2. 対象 `[REPO] <repository>` Control Issue
3. 本Repositoryの`AGENTS.md`以降のlocal read order
4. 必要に応じてdevflow `docs/operations/AGENT_OPERATING_MANUAL.md`
5. Issue判断が必要ならdevflow `docs/operations/REPOSITORY_ISSUE_MANUAL.md`
6. 横断仕様自体を扱う時だけdevflow `docs/spec/CROSS_REPOSITORY_DEVELOPMENT_CONTROL.md` / `.devflow/WORKFLOW.yaml`

運用名は`devflow`。GitHub rename完了前のidentityは`kinoko34077/devflow-test`、rename後は`kinoko34077/devflow`。

Baseとの接続境界は`.kinotch/meta/08_GITHUB_DEVELOPMENT_CONTROL.md`を参照する。

GitHub Projectは表示層であり、横断Current Stateの正本ではない。横断Current Stateはdevflow Repository Control / Work Order、詳細技術状態は各repo自身を参照する。

通常のGitHub変更はdefault branchへ直接書かず、専用branchからPull Requestを作成する。

要件が十分に定義されている場合、現行版取得、監査、必要なrepo-local Issue / Work Order、branch、実装、検証、PR、再監査までは継続してよい。

既にユーザーから包括的に許可され、現在の検証証拠があり、致命的問題の可能性が低く、security/destructive boundaryがなく、revert PRで安全に戻せるLOW/MEDIUM変更は追加確認なしでmergeしてよい。

release、deploy、publication、破壊的削除、shared history rewrite、security-sensitive permission / credential / session変更、その他復元困難な確定操作は実行前にユーザー確認を得る。

監査ではAudit SHAを残す。P0/P1 findingは原則としてowning repositoryでIssue化し、P2/P3は監査/PRへの集約を既定とする。

## Modification Boundary

個別案件の作業では `README.md` / `project/**` / repository-local Issue・branch・PRを変更対象とする。Base / Runtimeそのものを変更するタスクでない限り共通層を触らない。

## Implementation

- Domain CoreにSurface固有I/Oを埋め込まない。
- UI状態をDomain正本にしない。
- 同じ変換・判定・定数を複数Surfaceへ複製しない。
- 生成物を手編集しない。
- fallbackは元データを破壊しない方向を優先する。
- destructive operationには復元可能性・確認・dry-runのいずれかを検討する。

## Verification

完了宣言の前に、利用可能なら `knt verify` を実行する。外部接続やUIを変更した場合は対応するsmoke/実利用経路も確認する。

local taskの結果でdevflow ControlのAudit SHA / Work Status / Active Work / Next Action / canonical entry points / readinessが変わった場合だけ、検証後にControlを更新する。
