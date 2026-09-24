# GitHub Development Control

## 目的

本書は、KiNoTch.配下の複数RepositoryをGitHub上で横断管理するための共通運用規則を定義する。

対象は、GitHub Projects / Issues / Pull Requestsを用いた現在状態の可視化、監査、Work Order、実装、検証、レビュー、およびAgentの操作境界である。

本書は各RepositoryのDomain仕様や現在の実装状態を所有しない。それらは各Repositoryの正本を参照する。

## 1. 正本の分離

- 横断的な運用規則: 本書
- 横断的なlive state: GitHub Project `KiNoTch. Development Control`
- 個別作業のlive state: 各Issue / Pull Request
- 個別Repositoryの仕様・現在状態: 各Repositoryの正本
- Repository Base adoption state: Base側の既存運用資料

同じlive stateをBase文書へ手動複製しない。

## 2. GitHub Project

Project名:

`KiNoTch. Development Control`

Visibility:

`Private`

対象:

- ユーザー所有の開発Repository
- ユーザー所有の資料・仕様Repository

明示的な除外:

- `pc-files`
- `pc-files2`

上記2Repositoryはバックアップ用途のため横断開発管理対象外とする。

将来追加される開発・資料Repositoryは、個別列挙を更新しなくても原則として対象に含める。

## 3. Repository Control item

対象Repositoryは、open Issue / PRが存在しない場合でもProject上から消えないよう、Project内に1件のRepository Control itemを持つ。

Repository Control itemは作業Issueそのものではなく、Repository単位の現在状態を示す管理項目とする。

最低限、以下を追跡する。

- Repository State
- Repository
- Risk
- Audit SHA
- Next Action

Repository Control itemが存在すること自体は、そのRepositoryへの作業、Base adoption、Base同期、FULL auditの実施を意味しない。

## 4. Repository State

Repository自体の運用状態はWork Statusと分離する。

- `ACTIVE`: 通常の開発対象
- `PARKED`: 存在するが現在は意図的に凍結・保留
- `MAINTENANCE`: 新規開発を主目的とせず保守のみ行う
- `DEPRECATED`: 残しているが将来的な廃止を予定
- `CANCELLED`: 開発継続を行わないことを確定

## 5. Work Status

Issue / PR等の個別作業には以下を使用する。

- `NEEDS_AUDIT`
- `AUDITED`
- `WORK_ORDER_READY`
- `READY_FOR_IMPLEMENTATION`
- `IMPLEMENTING`
- `AWAITING_REVIEW`
- `BLOCKED`
- `NEEDS_REAUDIT`
- `PARKED`
- `DONE`

Repository StateとWork Statusの`PARKED`は意味の階層が異なる。

- Repository State `PARKED`: Repository全体を現在の作業対象から外す
- Work Status `PARKED`: 個別作業だけを保留する

## 6. Priority

- `P0`: 緊急。重大な障害、損失、セキュリティ等で即時対応が必要
- `P1`: 高。近い作業周期で優先して対応
- `P2`: 通常。通常の優先順位で対応
- `P3`: 低。急がず、必要性が生じた際に対応

Priorityは重要度・対応優先度を示し、Repository StateやWork Statusの代用にしない。

## 7. Risk

- `LOW`: 失敗しても影響が局所的で、容易に復元できる
- `MEDIUM`: 複数機能・設定・データへ影響し得る
- `HIGH`: データ損失、互換性破壊、公開系変更、広範囲な回帰等の可能性がある
- `CRITICAL`: 重大な破壊、セキュリティ、復旧困難性を伴う

Riskは作業の優先度とは独立して評価する。

## 8. Type

初期分類は以下とする。

- `FEATURE`: 新機能
- `BUG`: 不具合修正
- `SPEC`: 要件・仕様変更
- `AUDIT`: 監査
- `REFACTOR`: 外部挙動を原則変えない内部整理
- `MAINTENANCE`: 依存更新・保守
- `RESEARCH`: 実装前調査・比較検討
- `INFRA`: CI、開発環境、共通基盤
- `DOCS`: 文書のみ

分類が繰り返し不足する場合のみTypeを追加する。

## 9. Project fields

横断Projectの基本fieldは以下とする。

- `Status`: Work Status
- `Repository State`
- `Priority`
- `Type`
- `Repository`
- `Next Action`
- `Risk`
- `Audit SHA`

Repository Control itemでは`Repository State`を主に使用し、Work itemでは`Status`を主に使用する。

### Last Audit

`Last Audit`日付は独立した手入力fieldとして保持しない。

最後に監査したcommitを`Audit SHA`へ記録し、必要な場合はGitHubのcommit metadataから日時を取得する。

これにより、SHAと日付の二重更新を避ける。

## 10. Next Action

`Next Action`は自由記述とし、末尾へ検索可能な分類tagを1つ付ける。

形式:

`<具体的な次作業> [TAG]`

例:

- `PR #32をSTANDARD監査 [AUDIT]`
- `Windows環境でverify [VERIFY]`
- `ユーザー判断待ち [USER_DECISION]`

初期tag:

- `[AUDIT]`
- `[SPECIFY]`
- `[IMPLEMENT]`
- `[VERIFY]`
- `[REVIEW]`
- `[MERGE]`
- `[RELEASE]`
- `[USER_DECISION]`
- `[WAIT]`
- `[NONE]`

新しい分類が繰り返し必要になる場合のみtagを追加する。

## 11. Audit level

### QUICK

既知の論点、小さな差分、局所的な修正を対象とする狭い監査。

必要な関連資料と対象差分のみを確認する。

### STANDARD

通常の開発監査。

最低限、現在状態、関連仕様、変更コード、関連テスト、影響境界を確認する。

通常の「現行版確認」「監査」は、特に指定がなければSTANDARDを基準とする。

### FULL

Repository全体について、仕様、設計、実装、テスト、運用、主要境界を横断して確認する全面監査。

以下を原則とする。

- 明示的な必要性がある場合のみ行う
- 定期的に自動実行しない
- Repository Control itemが存在することをFULL auditの理由にしない

## 12. Audit provenance

監査結果には、監査対象の基準commitを`Audit SHA`として残す。

PR監査では原則として対象PRのhead SHAを使用する。

次回監査では、前回Audit SHAと現在対象との差分を優先し、FULL auditが不要な場合にRepository全体を毎回再読しない。

## 13. Finding escalation

監査で得たfindingはPriorityに応じて扱う。

- P0 / P1: GitHub Issueを自動作成する
- P2 / P3: 監査結果へまとめて報告する

P2 / P3でも、以下の場合はIssue化できる。

- 依存関係の追跡が必要
- BLOCKED理由として参照する必要がある
- 長期追跡が必要
- ユーザーがIssue化を要求した

## 14. Work Order

実装前に要求が十分に確定していない場合は、Issue内でWork Orderを形成する。

Work Orderでは最低限、以下を追跡する。

- Source
- Objective
- Scope
- Acceptance criteria
- Non-goals
- Verification
- Audit base
- Related specs / decisions

不足する要件判断がある場合、実装を推測で固定せずユーザー判断を取得する。

## 15. PR policy

この運用に従うRepository変更は、すべて専用branchからPull Requestを経由する。

通常運用ではdefault branchへ直接変更しない。

基本経路:

`Issue / Work Order -> branch -> implementation -> verification -> PR -> review -> merge`

## 16. Agent operation boundary

要件が十分に定義済みの場合、Agentは以下をユーザー確認なしで継続してよい。

- 現行版取得
- 関連正本の参照
- QUICK / STANDARD監査
- finding整理
- P0 / P1 Issue作成
- Work Order作成
- branch作成
- 実装
- 検証
- PR作成
- PR再監査

以下は実行前にユーザー確認を必要とする。

- merge
- release
- deploy
- publication
- Repository / branch / data等の破壊的削除
- その他、外部へ確定的に反映される操作または容易に復元できない操作

FULL auditは破壊操作ではないが、通常監査より範囲が大きいため、明示的な依頼または具体的な必要性がある場合にのみ行う。

## 17. GitHub Project views

最低限、次の2系統を分離して扱える構造とする。

### Repository Overview

全対象Repositoryを常時表示し、主に以下を見る。

- Repository State
- Risk
- Audit SHA
- Next Action

### Work Queue

Issue / PR単位で現在作業を見る。

- Status
- Priority
- Type
- Repository
- Risk
- Next Action

## 18. Repository Base Phase 5との関係

横断Projectへの登録とRepository Base adoptionは別概念とする。

Projectへ表示されていても、以下を自動的には行わない。

- Base adoption
- Base-managed fileの一括同期
- Default Pack導入
- Runtime統合
- 定期FULL audit

既存のPhase 5方針どおり、共通基盤の変更・同期は具体的なProject側の必要性が発生した場合に限る。

全Repositoryを可視化することは、全Repositoryを同一構造へ変更することを意味しない。

## 19. 初期自動化方針

初期導入では、Project構造と運用規則を先に安定させる。

Auto-add、Actions、追加automationは、実運用で繰り返し発生する手作業が確認された後に追加する。

将来の自動化は、本書の正本分離、PR policy、Agent operation boundaryを変更しない範囲で行う。
