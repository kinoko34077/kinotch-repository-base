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

- Base owns shared commands, schemas, Default catalog and implementations, rules, shared tests and Base CI logic; retain ADR0004 layer separation. Runtime owns portable runtime semantics, devflow owns cross-repository operation/bootstrap, .ai-guidelines owns its independent rules.
- Consumer owns manifest, selected capability states, local configuration, Domain, overrides and consumer tests. DEFAULT resolves central implementation; OVERRIDE uses only the consumer implementation; DISABLED never resolves or runs the capability. Reuse the existing catalog instead of a second selection mechanism.
- Keep only platform-required local entry/configuration: minimal launcher, AGENTS discovery pointer, workflow trigger/job entry, Git/editor configuration where required by host. Distinguish one-time skeleton generation and necessary generated/deployed assets from live shared implementations; generated assets require explicit reproducible generation and must not silently overwrite overrides. Audit each exception.
- Separate immutable Base root from writable consumer root in router and validation. Verify Base integrity against the admitted snapshot; verify consumer against manifest and selected capabilities. Do not weaken legacy hash/provenance checks. External Base operations may write consumer files only under a separately specified authorized consumer operation and path-containment checks; never mutate the shared cache. Keep existing legacy write denial until replacement is proven.

## Resolution contract candidate (B1)

A small trusted entry uses the fixed canonical public Base repository, not an arbitrary URL supplied by a consumer. A compatibility channel (name illustrative: stable/v1) identifies an approved revision, not latest main. Resolve once at execution start to an exact Git commit and verify approval and integrity before executing ANY fetched code, including validators. Git identity alone or hashes provided by the same untrusted content do not establish approval. Prefer existing GitHub review/protection infrastructure; the exact approval authority, immutable history proof, channel format and revocation/rollback policy are unresolved B0/B1 security design items. Do not enable a live moving channel until reviewed and authorized.

Cache immutable snapshots by revision outside tracked consumer files; atomic admission, concurrency safety and path/link containment are required. Avoid hooks, arbitrary remotes, submodule execution, credentials and mutable caches as trust roots. Offline use is explicit and limited to verified previously admitted snapshots; report SHA and offline/stale status. Fail closed for formal verification when required freshness/trust is unavailable; never silently fetch or execute another revision. Pinning/rollback must select an approved compatible revision, not arbitrary code. Record consumer HEAD, selected capabilities, Base SHA and evidence; doctor/setup/verify in one CI run share the same resolved revision.

## CI / bootstrap

Preserve required job/check context, issuer and permission boundary. Prefer a minimal caller retaining current triggers/check contract and a pinned trusted dispatcher resolving the admitted Base revision; compare reusable workflow context semantics before B3. Do not replace check evidence with unrelated success or expose privileged credentials to untrusted PR code. Base-specific CI references are #66; general CI consolidation and rollout are devflow #1121/#1122. Existing #63/#65 and draft #64 are separate; do not distribute legacy patch. Devflow minimal bootstrap does not imply Base adoption; integrate reference-mode seed only with the owning bootstrap mechanism and explicit selection in B4.

## Evidence and gates

B0: inventory current capability placement, helper path assumptions and host exceptions; compare approval alternatives; identify legacy compatibility constraints.
B1: prove immutable resolution, trusted admission, online/offline/pin/rollback, corrupt/unknown/unapproved rejection, no consumer mutation, three supported PowerShell hosts.
B2: exercise real DEFAULT/OVERRIDE/DISABLED routing, schema/rule discovery, no duplicated selection logic; preserve consumer-specific configuration and tests.
B3: prove central CI logic, check-context compatibility and equivalent evidence; avoid duplicate independent guarantees.
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

## B0.3 承認・配布方式比較（設計候補）

| 方式 | 判定 |
|---|---|
| main / mutable tag / owner Issue commentを直接実行 | 不採用。GitHub actorの一致や自己申告hashは未審査コードの排除にならない |
| 独自署名付きmanifest | 独立した鍵の配布・回転・失効管理が必要。現時点で既存鍵の利用可能性は未確認。必須にしない |
| GitHub immutable release + digest付き生成bundle | 第一候補。既存プラットフォームの承認・固定配布機構を使用。設定・公開の承認は別途必要 |

GitHub公式仕様:
- https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository
- https://docs.github.com/en/rest/releases/releases
- https://docs.github.com/en/rest/releases/assets

Immutable releaseのtagとassetは固定されるが、release notes/title/latest/prereleaseは変更可能なので承認の意味や順序を持たせない。現行repositoryにはreleaseがなく、immutability設定のGETも連携で未対応。よって本案は設定済み・公開許可済みとはみなさない。

### REF-SEL-001 — promotion選択候補

固定正本repoの信頼できるGitHub API応答から、互換epoch v1の厳密なtag `base-ref-v1-NNNNNNNN`（8桁、1以上）を選択する。数字はコード版でなく中央昇格の順序。全ページ取得が完了していない場合は選択不可。draftは対象外。通常は最大sequence、固定利用・明示rollbackは承認済みsequenceを指定する。自動利用は既知の最低sequenceより後退しない。重複・不正tag・選択候補のmutable release・actor不一致・bundle metadata欠落/不正は失敗し、古い候補への暗黙fallbackをしない。mutable latest/prerelease flagは参照しない。

承認された公開releaseを生成する操作は、独立Review、exact-head検証、bundleとtag commitの一致、互換試験、明示公開承認を前提とする。実行時はtagの実commit（target_commitish文字列は使わない）、release/asset ID、sha256 digestを固定し、bundleの取得・検証と安全展開を行う。生成bundleは正本ではなく、審査済みcommitから再現可能な配布物。初回起動の信頼根は審査済みlauncherと固定GitHub origin、repo identity、承認されたpublisher policy。取得元やactorをconsumer設定で変更させない。GitHub APIの完全性/TLS検証・tag解決・bundle/manifest一致・cacheの検証はB1の未実装境界。

Offlineは以前に承認・検証した同一bundleのみ明示選択できる。失効確認不能を明示し、正式gateはonline freshnessを満たさない場合HOLD。最新releaseの削除やAPI応答欠落を初回clientだけで完全検出できるとは主張しない。既知sequence下限は自動後退を抑制するが、失効機構・信頼されたローカル状態・cache同時更新は別B1検証。publisher権限が侵害された場合の独立した署名検証は本方式単独では提供しない。必要性が確認されれば再評価する。

今回の `project/src/reference-channel-selection.ps1` は選択規則のみの純粋な試作。synthetic recordsで正常・不正・重複・後退・固定・取得不完全をテストする。通信、cache、展開、コード実行、承認/公開操作は一切行わない。正式loaderには未接続。

## B1.1 配布物の検証（非稼働試作）

GitHub Immutable Releaseはrelease tag / commit SHA / release assetを結び付ける署名付きattestationを自動生成する。独自署名の実装ではなく既存の `gh release verify <tag> -R github.com/kinoko34077/kinotch-repository-base` と `gh release verify-asset <tag> <file> -R github.com/kinoko34077/kinotch-repository-base` を優先候補とする。公式: https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases 、 https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/verify-release-integrity 、 https://cli.github.com/manual/gh_release_verify-asset 。GitHubの自動生成source archiveはasset attestation検証対象外なので、審査済みcommitから生成した明示assetを対象とする。既存ghの利用可否・必要バージョン・公開repoの認証要否・出力schemaは実環境で確認後に確定し、新規credentialや権限を勝手に作らない。署名付きrelease証明は公開物の出所を検証するがReview実施やpublisherアカウント非侵害を証明しない。

REF-BUNDLE-001: 取得済みassetのbyte SHA-256（改行正規化なし）と外部から得たsizeを照合後、同一read streamからZIPを検査する。bundleはrootの `reference-bundle.json`（schema_version=1, source_commit, release_tag）、既存Base indexの固定root files、.kinotch/以下のみを持つfile-only archiveとする。現行.kinotchは104 blob・502271 bytes。試作上限は圧縮16 MiB、展開総量64 MiB、2048 entries、metadata 4096 bytes（全て将来の互換契約候補）。file-only portable path、重複/大小文字衝突、file/parent衝突、Windows device名、link/reparse属性、範囲外root、不足入口、tag/commit不一致を拒否する。実際の展開では既存Assert-KntSafePathを使う。ZIP metadataのみでは展開後サイズ・完全なBase index整合を証明しないため、展開時の実byte上限・全保護index検証・stagingの競合防止・cache入場・再検証は後続B1。現在のoffline試作はread-onlyで、展開/実行/ネットワーク/公開を行わない。

REF-SEL-001のasset sizeもpositive integerかつ上限内であることを確認する。digestとsizeはmetadata取得の結果であり、署名検証の代わりではない。
