# ADR 0006 — Reference-based Repository Base (proposal)

Status: Proposed / B0 investigation (#66). This is not an accepted specification or a release authorization.

## Context and decision drivers

The initial context/target/roadmap at `b06e2db25b0567413fe73816bb06dcf7179a40e0` separates common and individual ownership; distribution was an initial mechanism, not the goal. The current accepted snapshot is 0.5.24 (`3c36e3f78fc39c4aa53d08d578a624e141bf18e1`). Current doctor, base-check, init/migrate and Default provenance assume local materialization. RootOverride/BaseOverride already route to external schemas and catalog but doctor skips the local Base integrity check for RootOverride; this is NOT production admission.

Observed examples: memory-game 0.3.8 (web-app OVERRIDE), kinotch-api 0.3.8 (api/mcp/ci-test/generated-integrity OVERRIDE), kinotch-default-canary 0.5.13 (cli/ci-test/config/logging DEFAULT with materialized hashes). Runtime embeds 0.5.13 and owns portable execution semantics. The recorded nine adopters, Runtime and Canary were subsequently inventoried in #66. Discovery beyond that recorded set is a separate rollout concern, not required to accept the reference mechanism.

## Alternatives

| Approach | Update without consumer commit | Reproduction and trust | Decision |
|---|---|---|---|
| Copy protected tree / patch | No | Per-consumer drift and synchronization | Legacy only |
| Git submodule / exact package pin alone | No | Strong snapshot identity, manual update | Optional fixed mode, not normal default |
| Execute floating main or raw URL | Yes | Unreviewed revisions and arbitrary origin risk | Reject |
| Reviewed compatibility channel resolving to immutable commit | Yes | Requires explicit authority, immutable resolution and verification | Proposed |
| New hosted API / package service | Possible | New operating and authentication burden | Not justified |

## Proposed responsibility and placement

- Base owns shared commands, schemas, Default catalog and implementations, rules, shared tests, and Base command/connection adapters; retain ADR0004 layer separation. Devflow #1121 owns cross-repository CI policy, evidence contracts and common decision/execution core. Base must not duplicate that core. Runtime owns portable runtime semantics, devflow owns cross-repository operation/bootstrap, .ai-guidelines owns its independent rules.
- Consumer owns manifest, selected capability states, local configuration, Domain, overrides and consumer tests. DEFAULT resolves central implementation; OVERRIDE uses only the consumer implementation; DISABLED never resolves or runs the capability. Reuse the existing catalog instead of a second selection mechanism.
- Keep only platform-required local entry/configuration: minimal launcher, AGENTS discovery pointer, workflow trigger/job entry, Git/editor configuration where required by host. Distinguish one-time skeleton generation and necessary generated/deployed assets from live shared implementations; generated assets require explicit reproducible generation and must not silently overwrite overrides. Audit each exception.
- Separate immutable Base root from writable consumer root in router and validation. Verify Base integrity against the admitted snapshot; verify consumer against manifest and selected capabilities. Do not weaken legacy hash/provenance checks. External Base operations may write consumer files only under a separately specified authorized consumer operation and path-containment checks; never mutate the shared cache. Keep existing legacy write denial until replacement is proven.

## Resolution contract candidate (B1)

A small trusted entry uses the fixed canonical public Base repository, not an arbitrary URL supplied by a consumer. A compatibility channel identifies an approved revision, not an unchecked moving main. An immutable release is one possible approval source; automatically admitted exact integration candidates under a once-authorized policy are also candidates. Resolve once at execution start to an exact Git commit and verify approval and integrity before executing ANY fetched code, including validators. Git identity alone or hashes provided by the same untrusted content do not establish approval. The later REF-GIT-001 design supersedes the generated-bundle candidate. Prefer existing GitHub review/protection infrastructure; the exact approval authority, immutable history proof, channel format and revocation/rollback policy are unresolved B0/B1 security design items. Do not enable a live moving channel until reviewed and authorized.

Cache immutable snapshots by revision outside tracked consumer files; atomic admission, concurrency safety and path/link containment are required. Avoid hooks, arbitrary remotes, submodule execution, credentials and mutable caches as trust roots. Offline use is explicit and limited to verified previously admitted snapshots; report SHA and offline/stale status. Fail closed for formal verification when required freshness/trust is unavailable; never silently fetch or execute another revision. Pinning/rollback must select an approved compatible revision, not arbitrary code. Record consumer HEAD, selected capabilities, Base SHA and evidence; doctor/setup/verify in one CI run share the same resolved revision.

## CI / bootstrap

Preserve required job/check context, issuer and permission boundary. Prefer a minimal caller retaining current triggers/check contract and a pinned trusted dispatcher resolving the admitted Base revision; compare reusable workflow context semantics before B3. Do not replace check evidence with unrelated success or expose privileged credentials to untrusted PR code. Base #66 owns safe dependency resolution, reference adapters and thin caller initialization only. Devflow #1121 owns common CI policy, decision core and evidence contract, usable directly by non-Base repositories. #1122 owns subsequent rollout and remains HOLD until common mechanism acceptance. Existing #63/#65 and draft #64 are separate; do not distribute legacy patch. Devflow minimal bootstrap does not imply Base adoption; integrate reference-mode seed only with the owning bootstrap mechanism and explicit selection in B4.

## Evidence and gates

B0: inventory current capability placement, helper path assumptions and host exceptions; compare approval alternatives; identify legacy compatibility constraints.
B1: prove immutable resolution, trusted admission, online/offline/pin/rollback, corrupt/unknown/unapproved rejection, no consumer mutation, three supported PowerShell hosts.
B2: exercise real DEFAULT/OVERRIDE/DISABLED routing, schema/rule discovery, no duplicated selection logic; preserve consumer-specific configuration and tests.
B3: integrate the thin reference/initialization adapter with devflow #1121's accepted shared CI core; prove check-context compatibility and equivalent evidence using that owner's contract. Do not implement a second CI policy/decision core.
B4: representative legacy adopter and new bootstrap; measure tracked shared files and prove overrides preserved; no fleet-wide migration.
B5: accepted specs/implementation/tests; central compatible change observed on next ordinary consumer execution without consumer Git tree change, plus rollback/offline/security negatives. Fleet migration has separate issues.

The initial probe in project/tests/reference-base-probe.ps1 isolates a synthetic overly strict Base schema from the current schema. It tests existing external reference mechanics and write denial, not network resolution, release approval, production Base integrity, or final acceptance. No actual consumer or protected Base path is modified.

## B0.2 配置・依存の分類（設計候補）

#66の記録済み9採用repo、Runtime、Canaryの実treeを確認した。全てAGENTS、knt.cmd、.kinotch、root Git/editor設定、verify.ymlを持つ。既存の固有workflowやOVERRIDEを共通物と誤認しない。Canaryのcli/config/logging helperのみ代表DEFAULT実体として扱う。

| 対象 | 参照型での配置・変更境界 |
|---|---|
| router / validator / containment / catalog / profiles / Base schemas / rules / self-tests | 中央Base。Base自身の検証はconsumer検証から分離 |
| cli / config / logging / agent / api / windows helper | 中央の選択されたhelperを読み込む。Project固有hookや状態はconsumer |
| mcp helper | 中央。現行Resolve-McpProjectPathがconsumer内.kinotchに依存するためBase/Project root分離をB2で検証 |
| file-io / generated-integrity check・update / pwa-check | 中央。現行PSScriptRootからのconsumer root推定を明示rootへ置換し、containmentを再利用 |
| generated-integrity.json / Project-specific contract configuration | Project dataと共通schemaを区別。Project dataはconsumer。共通定義を複製しない |
| PWA public manifest / worker / registration | 公開hostに必要な生成物のみconsumerに残せる。生成元はBase、Project差分は別入力。既存OVERRIDEは保持 |
| .github/workflows / AGENTS / knt launcher / .editorconfig / .gitattributes / .gitignore | host固定入口、ローカル設定として必要最小。全Base treeを置かない |
| Project skeleton / domain / tests / deploy workflows | Project所有。初期生成は一度限り、共通更新で再生成しない |

## B0.3 承認・取得方式（設計候補 / 大局再探索）

| 方式 | 判定 |
|---|---|
| main / mutable tag / owner Issue commentを直接実行 | 不採用。未審査revisionの排除にならない |
| 独自署名manifest | 鍵配布・回転・失効管理が必要。必須にしない |
| immutable release + 生成ZIP asset | 保留。Gitで管理済みソースの二重配布・展開・検査の独自実装が増える |
| immutable releaseで承認commitを固定 + native Git取得 | 承認経路の候補。Gitの既存object管理を再利用するが、更新毎の公開操作を要する可能性 |
| 一度承認した中央policyによる検証済み統合commitの自動選択 + native Git取得 | 通常更新の優先検討候補。devflow #1121の真正な証拠契約と実運用安全承認が前提 |

現行mainは143 blobs / 627132 bytes（うち.kinotch 104 blobs / 502271 bytes）、非通常file modeなし。ZIP生成物を追加する必要性は現時点で認められない。前試作のZIP検査は履歴に残すが、この候補から削除する。将来バイナリ配布等で必要性が具体化した時のみ再評価する。

GitHub公式: https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases ; https://cli.github.com/manual/gh_release_verify ; https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/verify-release-integrity 。GitHubの自動source archiveはasset署名検証対象外なので使用しない。gh upstream pkg/cmd/release/verify/verify.go と shared/fetch.go / attestation.go の実装はrelease tag refのobject digestと署名を検証し、tag名をpredicateで照合する。assetがない場合の表示分岐もある。実際のassetless release発行・署名検証は未実証、設定・公開は別Human gate。

### REF-SEL-001 — promotion選択

固定正本repoの信頼できるGitHub API応答から、互換epoch v1のtag `base-ref-v1-NNNNNNNN`（8桁、1以上）を選択。全ページ取得完了が前提。draftは対象外。通常は最大sequence、固定利用・明示rollbackは承認済みsequenceを指定する。自動利用は既知下限より後退しない。重複・不正tag・選択候補のmutable release・actor不一致・release ID不正は失敗し、古い候補への暗黙fallbackをしない。mutable latest/prereleaseは意味を持たせない。選択はlocatorであり実行承認ではない。選択処理はassetを要求しない。

### REF-GIT-001 — native Gitによる取得と参照（候補）

以下1–2はimmutable releaseを承認源とする場合の候補。代替の検証済み統合commitを承認源とする場合でも、3–5のGit取得・不変実行単位は共用する。

1. 承認者が独立Review、exact-head検証、互換試験、明示公開承認を経て不変releaseを発行。初版は軽量tagのみを対象とし、annotated tagを暗黙peelしない。
2. 固定repo identity/actor、release ID/tag、検証済みrelease attestationから得たobject digestを照合する。ghの出力schema、repository/issuer/predicate binding、必要version/認証を既存環境で実証。署名はReviewの実施自体を証明しない。
3. consumer外の隔離Git object storeに固定originからtagをfetch、FETCH_HEADの実object type=commitと完全SHA一致を検査。取得時のGit object検証を使用。検証前にcheckoutや取得コードを実行しない。
4. Gitの既存checkoutを用い、hooks/global/system/local config、filter、submodule、symlink、非通常mode、大小文字・host path、untracked/reparseを検証。既存Base indexとpath-containmentを再利用する。checkoutの改行変換は現行Base indexと整合するが、cache検証ではGit object/working-treeの同一性と未追跡コード混入を別途保証する。
5. 同一実行内は解決済みcommitを固定。consumerのrootとBaseのrootを分離して既存Routerへ渡す。cacheの可変HEADを複数実行で共有しない。immutable snapshot / atomic admission / concurrency / offline trust receiptの最小実装をB1で検証。offlineは以前に承認済みのcommitを明示指定、鮮度不足の正式gateはHOLD。新規資格情報、権限変更、独自server/package managerを必須にしない。

Gitのlocal fixtureでA→Bのschema修正、利用側非変更、Aへのoffline rollback、移動tagの不一致拒否を実証する。現時点のfixtureは公開release、署名、ネットワーク、production cache、Git環境隔離全体の証明ではない。取得・署名検証と実行をつなぐ実運用admissionは未実装。

B0の設計受入ではこのnative pathを優先し、必要性のないZIP検査の追加作業を停止する。B1では取得経路と承認源を分離して最小参照実行を先行する。失敗時のみ証拠付きで配布方式を再評価する。

## B0.4 横断責務・更新の自動性（2026-11-25 JST）

- 正本: devflow #1121 / #1122 / #1136 / #1140、Base #66 comment 7146243825。共通CI規則・判定・証拠はdevflow。Baseは安全な依存解決・参照接続・Base固有Routerと薄いcaller初期化を担当。Base未採用repoもdevflow共通CIに直接接続できることを維持する。共通CIの開発を本Issueで再実装しない。
- 既存devflow MCP local release manager (`tools/devflow_mcp_release_manager.py` / `docs/operations/DEVFLOW_MCP_LOCAL_RELEASE.md`, #1124) は固定origin、exact integrated SHAのCI確認、stage、digest、atomic marker、lock、rollbackを実装済み。ただしWindows Codex MCP専用の運用・Python依存であり、その全体をBaseへ複製しない。共通証拠判定は#1121のownerと接続し、必要な共通取得/検証責務の抽出は当該owner間で調整する。既存MCPの稼働設定を変更しない。
- 毎回のrelease作成・公開承認が新たな反復操作になるなら目的に反する。通常利用で自動的に選択可能な承認源（事前に承認された固定policyに基づくexact integration candidate）を優先比較する。#1121が整備するReview/CI証拠の真正性・有効性・鮮度・失効を利用する。単にmainのSHAが一致、commitが存在、checkがgreenというだけではadmissionを認めない。実装に必要な安定した非特権読み取り経路を検証する。Immutable Release案は安全な代替候補として残すが、独立した署名/承認機構の追加開発や新しいper-update手動制約は必要性を確認するまで行わない。
- 承認源と取得機構は独立。承認済み不変revisionを入力としてGit取得・既存Routerを利用する共通経路は、承認源の正式受入前もsynthetic fixtureで検証できる。fixtureのexpected SHAは合成の検証入力で実運用承認ではない。実際に外部コードを自動実行する信頼policy・権限・設定・公開は独立ReviewとHuman gateを維持。
- B3は#1121との接続契約と代表検証に限定。#1122全repo展開はHOLD。#63/#65の旧配布も再開しない。

## B1.1 独立snapshot供給（試作）

取得と承認、利用を分離する。既存Gitの保持refから、新規の実行単位repoへexact commitだけをnative local transportで浅く取得する。全履歴clone・hardlink・alternates・共有worktreeを不要とする。保持refの実SHA/type、通常file modeをcheckout前に確認し、失敗した新規領域のみ破棄する。正常な別領域・永続cacheは保持する。

`project/src/reference-snapshot.ps1` の `New-KntReferenceSnapshot` は信頼済みhostが確立したcache・commit・stage root・隔離Git呼出を入力とする非稼働試作。呼出側が真正な承認、固定origin、環境/config隔離、root保護、cacheの寿命、成功stageの寿命を所有する。これら未実証のまま実運用しない。任意consumer入力を信頼済み引数へ変換しない。特殊tree modeを拒否するが、全host path・cache完全性・同時更新安全性の受入は後続B1。

#1154の `devflow_mapped_read` は既存固定checkoutのimport pathを利用するため、同じsnapshot供給を利用できる候補。Base固有Routerとmapper固有packageを分離し、言語別の取得/版解決実装を増やさない。承認・証拠はdevflow #1121の正本に接続する。実Python接続・本番有効化は未実施。

## B1.2 版単位の取得・保持（非稼働試作）

共有shallow cacheへの並行fetchでGit自身のshallow lock競合を再現した（4件中1成功、3失敗）。共通cacheを正本repository単位のrootと不変commit単位のbare repositoryへ分ける。未知版は専用incoming directoryへexact SHAを浅く取得し、実SHA/type/bare/alternates不在を確認後、同一親内のdirectory moveで確定する。同一版の競合は先に成立した正しいcacheを再利用し、上書きしない。失敗したincomingのみ破棄。取得済み版はoriginに接続せず再利用。source unavailable/未知版/破損refは成功にしない。既存の独立snapshot供給関数を変更理由に沿って再利用する。

Linux合成Git実験は4異なる版＋同一版競合2件の6並行で4 publish/2 race-hit、incoming残存なし、offline再利用成功。異版間のobject重複は残るため実容量・保持寿命の測定後に必要な回収を設計する。実hostのPowerShell関数/fixtureはCIで確認する。今回の受入範囲は信頼済みローカルsource/rootからの取得と保持に限定し、ネットワーク・実運用承認・自動選択・cache root保護・全host pathの保証とは区別する。

## B1.3 利用単位の共通接続（非稼働試作）

`Invoke-KntReferenceSession` は信頼済みhostから注入された承認済み版決定を1回取得し、対象repo/channel/policyと明示pinの一致を確認する。その後はexact SHAを固定し、B1.2の保持とB1.1の独立snapshotを再利用する。利用adapterはstage・exact SHA・状態を受け、成功/失敗とも一時stageを片付ける。利用結果には実解決commit・policy・CURRENT/OFFLINE・cache再利用を残す。OFFLINEは既存の保持済み版のみを許す。拒否・不明・不一致・未保持版から暗黙fallbackしない。

承認の真正性・互換性・鮮度・失効・offline可否は信頼済み解決元の責務。合成providerは本番承認元ではない。devflow #1121の原典取得・共通判定を独立再実装せず、正式契約成立後に薄い接続を追加する。今回のfixtureは同一利用入口のA/B決定・実Router・明示offline/pin・拒否・例外時cleanupを検証する。ネットワーク・実運用入口・権限・公開・他repo適用なし。
