# AGENTS.md

このリポジトリは KiNoTch. Repository Base に準拠する。

## 0. 横断管理下での開始

このRepositoryがKiNoTch.のdevflow管理対象であり、GitHub上の開発・監査・Issue/PR運用・handoffを行う場合は、**ローカル資料より先に対象Repositoryのdevflow Control Issueを確認する**。

1. devflow root `AGENTS.md`を読む。
2. devflowのopen Issue `[REPO] <このrepository名>`を読む。
3. その`Audit SHA`、`Active Work`、`Next Action`、`Canonical Entry Points`を確認する。
4. その後、本Repository内では以下の「最初に読むもの」へ進む。

運用名は`devflow`。GitHub rename完了前はrepository identity `kinoko34077/devflow-test`、rename後は`kinoko34077/devflow`を使用する。

横断状態の正本をこのRepositoryへ複製しない。devflow Controlは横断要約、本Repositoryは詳細技術正本を所有する。

ローカルファイルだけを扱う明確な非GitHub作業で、横断Current Stateが結果へ影響しない場合は、不要なdevflow参照を強制しない。

## 1. 最初に読むもの

1. `README.md`
2. `project/project.json`
3. `project/docs/INDEX.md`
4. `project/docs/CURRENT_STATE.md`
5. active repo-local Issue / Work Order / PR（存在する場合）
6. 現在タスクに関係する `project/docs/`・コード・テスト

Base / Runtimeそのものの変更、共通化判断、既存repo移行を扱う場合のみ `.kinotch/meta/README.md` と関連Metaを追加で読む。

共通規則が必要な場合のみ `.kinotch/` を読む。毎回全共通資料やMetaを読み直さない。

## 2. 変更境界

通常の個別開発で編集してよいもの:

- `README.md`
- `project/**`
- repository-local Issue / branch / PR

原則として個別案件のためだけには編集しないもの:

- `AGENTS.md`
- `.kinotch/**`
- `knt.cmd`
- `.editorconfig`
- `.gitattributes`
- 共通CI
- KiNoTch. Runtime 本体

共通層の修正が必要に見える場合は、個別repoへ場当たり的に修正を入れず、Base / Runtime側へ昇格すべき変更か判定する。

## 3. 正本

- 横断Current State: devflowの対象Repository Control Issue
- 横断Work Order / 運用規則: devflow
- 個別プロジェクトの機械可読入口: `project/project.json`
- 個別仕様: `project/docs/`
- 現在状態: `project/docs/CURRENT_STATE.md`
- 個別実装タスク/finding: repository-local Issue / Work Order
- 変更差分・検証: repository-local Pull Request / CI / tests
- Action契約: `project/contracts/actions.json`
- Surface差分: `project/contracts/surfaces.json`
- 共通Repository規則: `.kinotch/REPOSITORY_STANDARD.md`
- 共通Agent規則: `.kinotch/AGENT_RULES.md`
- Runtime接続規則: `.kinotch/RUNTIME_INTEGRATION.md`

READMEはGitHub上の人間向け入口であり、詳細仕様の正本として重複記述しない。

## 4. 作業原則

- 要求・仕様・設計・実装・テストを混同しない。
- 同じ知識を複数箇所へ複製しない。
- Core処理をGUI / CLI / MCP / API固有コードへ埋め込まない。
- 変更前に関連仕様・既存テスト・影響範囲を確認する。
- 生成物は手編集しない。正本を変更し再生成する。
- 外部依存失敗と内部ロジック失敗を区別する。
- 共通化は同じ知識・同じ変更理由に対してのみ行う。
- 将来使う可能性だけを理由に抽象層を増やさない。
- repo-local taskの詳細をdevflow Controlへ複製しない。

## 5. GitHub Issue / PR運用

repo-local Issue / Work Orderの作成・更新・close条件はdevflowの`docs/operations/REPOSITORY_ISSUE_MANUAL.md`を正本とする。

通常変更はdefault branchへ直接書かず、専用branch + Pull Requestを使用する。

local task完了後、devflow ControlのAudit SHA / Work Status / Active Work / Next Action等が変わった場合だけControlを更新する。

## 6. 共通コマンド

```text
knt doctor
knt setup
knt dev
knt test
knt build
knt verify
knt smoke
knt base-check
```

Windows cmdでは `knt.cmd <command>`、PowerShellでは `.kinotch/scripts/knt.ps1 <command>` を使用する。

## 7. 完了条件

最低限、変更対象に応じて以下を確認する。

- 関連仕様との整合
- 対象テスト
- 既存機能の回帰
- `knt verify`
- 必要なら `knt smoke`
- `project/docs/CURRENT_STATE.md` の更新
- 仕様そのものが変わった場合のみ正本文書の更新
- cross-repository summaryが変わった場合のみdevflow Control更新
