# GitHub Development Control — Repository Base Integration

## 目的

本書は、KiNoTch. Repository Base と横断GitHub開発管理基盤devflowの**接続境界だけ**を定義する。

横断的な状態語彙、Repository Control、Work Order、repo-local Issue lifecycle、Audit level、Finding escalation、GitHub Project field、同期方式、Agent操作境界の正本は本Repositoryでは所有しない。

横断正本:

- Operational repository name: `devflow`
- Current GitHub identity until rename: `kinoko34077/devflow-test`
- Target GitHub identity after rename: `kinoko34077/devflow`
- Agent start: `AGENTS.md`
- Canonical specification: `docs/spec/CROSS_REPOSITORY_DEVELOPMENT_CONTROL.md`
- Agent operations: `docs/operations/AGENT_OPERATING_MANUAL.md`
- Repository-local Issue operations: `docs/operations/REPOSITORY_ISSUE_MANUAL.md`
- Project synchronization operations: `docs/project/PROJECT_SYNC.md`
- Machine-readable workflow: `.devflow/WORKFLOW.yaml`
- Current cross-repository state: devflow Repository Control Issue / cross-repository Work Order
- Derived display: GitHub Project `KiNoTch. Development Control`

本書とdevflow正本が衝突する場合、devflow正本を優先する。

## 1. Authority boundary

```text
individual repository canonical state
  -> devflow canonical cross-repository summary
  -> Project synchronizer
  -> GitHub Project display
```

各RepositoryのDomain仕様・実装・詳細Current State・repo-local Issue/PRは各Repository自身が所有する。

devflowは横断要約、Audit SHA、状態、Priority/Risk、Active Work、Next Action、canonical entry pointsを保持する。詳細仕様・実装ログを複製しない。

GitHub Projectは表示・俯瞰層であり、Project値からRepositoryやdevflow Issueへ逆同期して正本化しない。

## 2. Base-adopted repositoryのAgent開始順

managed repository上でGitHub開発作業を始めるAgentは:

1. devflow root `AGENTS.md`を読む;
2. 対象のopen `[REPO] <repository>` Control Issueを読む;
3. Control IssueのAudit SHA / Active Work / Next Action / canonical entry pointsを確認する;
4. 対象repoへ戻り、そのlocal `AGENTS.md`を読む;
5. `project/project.json` → `project/docs/INDEX.md` → `project/docs/CURRENT_STATE.md` → active local Issue/PR → task-relevant materialの順へ進む。

これによりdevflowは「どこを見るか」、Baseは「repo内でどう読むか」を所有し、同じ役割を二重化しない。

横断Current Stateが結果へ影響しない明確なlocal-only作業では、不要なdevflow読取を強制しない。

## 3. Repository Baseとの分離

横断管理対象に登録されることとRepository Base adoptionは別概念である。

Repository Control IssueやProject Itemが存在しても、以下を自動的には意味しない。

- Base adoption
- Base-managed fileの同期
- Default Pack導入
- Runtime統合
- Repository構造の統一
- 定期FULL audit

Base adoption stateは必要な場合のみ既存Phase 5規則の:

`ADOPTED / STAGED / NOT_ADOPTED / N/A`

で扱う。

`.kinotch/`がないmanaged Repositoryは、それだけで未完了扱いしない。既存正本・構造を尊重する。

## 4. Repository onboarding

初回onboardingではBase adoptionより先に:

1. default branchの具体的なAudit SHAまたはno-SHA理由;
2. repository固有のspec / Current State / test / build / runtime入口;
3. Work Status / Repository State / Priority / Risk / Next Action;
4. active local Issue/PR;
5. PR-only運用の技術・process状態;
6. Base adoptionが既にあるか、具体的に必要か;

を確認し、devflow Controlへ入口を記録する。

Base構造を持たないrepoへ、onboardingだけを理由にBaseを導入しない。

## 5. Issue / Work Order boundary

repo-local実装・調査・finding・仕様変更はowning repositoryのIssue / Work Order / PRを使う。

devflow cross-repository Work Orderは、複数repoを一つのoperationとして調整する場合またはcontrol-plane自体を変更する場合に使う。

Base採用repoでもlocal Issue templateをdevflowと完全一致させる必要はない。必要なdurable情報はdevflowの`REPOSITORY_ISSUE_MANUAL.md`に従う。

Base自身に関する共通層変更は`kinotch-repository-base`のlocal Issue/PRとして扱い、必要ならdevflow parent Work Orderから参照する。

## 6. Project field compatibility

Project field mappingはdevflow正本から取得し、本書へ網羅的に複製しない。

主要対応だけは接続確認用として:

- devflow `Work Status` -> Project built-in `Status`
- devflow `Type` -> Project custom `Work Type`
- devflow `Repository` -> Project custom `Managed Repository`

GitHub Projectは正本ではない。

## 7. Audit / Base-specific conditions

QUICK / STANDARD / FULL、Finding escalation、Work Order必須項目、Audit SHA、merge boundaryはdevflow正本に従う。

Base固有の追加条件:

- Base-managed fileとProject-owned fileの境界を確認する;
- `DEFAULT / OVERRIDE / DISABLED`を既存実装へ強制上書きしない;
- Base変更候補はPhase 5 return conditionを満たす場合にのみBaseへ昇格する;
- 個別repoの問題をBase共通問題として推測で一般化しない。

FULL auditは定期実行しない。

## 8. Modification / safety boundary

通常変更はdedicated branch + Pull Requestを経由する。

要件が定義済みなら、Agentは現行取得、関連正本確認、QUICK/STANDARD audit、必要なlocal Issue、branch、実装、検証、PR、再監査まで継続してよい。

現在のユーザー許可範囲で、検証済み・低致命性・security/destructive boundaryなし・revert PR可能なLOW/MEDIUM変更は追加確認なしでmergeしてよい。

以下は実行前のユーザー確認を必要とする:

- release
- deploy
- publication
- destructive delete
- shared history rewrite
- security-sensitive permission / credential / session change
- その他復元困難な操作

merge後の問題はshared `main`を書き換えずdedicated rollback branch + revert PRで戻す。

## 9. Verification handoff

Private Projectを直接確認できない場合の通常確認経路:

1. `[SYSTEM] GitHub Project Sync Health`
2. 対象Repository Control Issue
3. active cross-repository Work Order / repo-local Issue / PR
4. 必要なActions run/log

Project構造変更、APIで検証不能なUI条件、machine/UI不一致、`CODEX_REQUIRED`、repository identity migration、明示要求ではProject-capable pathへ直接確認をhandoffする。

## 10. devflow renameとの関係

`devflow-test` → `devflow` renameはdevflow側Work Orderで管理する。

Base側ではrename完了前に旧GitHub identityを事実として保持しつつ、運用名を`devflow`へ統一する。rename完了後、current-identity参照を`kinoko34077/devflow`へ更新する。

Baseからrepository rename、Project Auto-add、Project sync、secret/permission設定の完了を推定しない。devflow側のpost-rename verification evidenceを参照する。

## 11. Phase 5との関係

`.kinotch/meta/07_PHASE5_OPERATIONS.md`の方針を維持する。

横断的な可視化・監査・Issue/PR運用を全managed Repositoryへ適用することは、全RepositoryをBase-managed構造へ変更することではない。

Baseは共通化の必要性が具体的に成立したときだけ同期・更新する。
