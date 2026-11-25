# 参照型Defaultの利用契約（B2候補）

Owner: #66。非稼働の代表接続。Base v0.5.27はsource候補でありrelease/Canary受入ではない。

`-ReferenceMode -RootOverride <consumer> -BaseOverride <admitted-base>/.kinotch reference-path config logging`

既存RouterとDefault Catalogの `reference_entry`（現在の所有テンプレートのproject/tools/*.ps1）を利用する。新規の個別ローダーや別Catalogを作らない。信頼済みhostが取得・承認したBaseのsnapshotを供給し、利用中にその版を変更しない。Routerは中央のBase indexと選択したpack/互換性を検証する。JSONのreferencesにid/state/pathを返す。複数packを一回で解決し、DISABLEDはpath=null、未選択・未知・不整合は非成功。pathはsnapshotの利用期間内だけ有効であり、永続設定に保存しない。

DEFAULTは中央の所有helperを参照し、OVERRIDEは同じ公開入口を要求した場合のみProject所有helperへ接続、DISABLEDは読み込まない。DEFAULTに旧materialized provenanceまたは同名local helperが残る場合は暗黙上書きせず明示移行を要求する。従来modeは既存のlocal materialization検証を維持する。ReferenceMode doctor/base-checkは中央Baseを検証し、対応済みDEFAULTを参照として診断する。既存の外部apply拒否を維持。

第一候補はcli/windows/api/agent/config/loggingのroot非依存helper。mcp/file-io/generated-integrity/pwaのroot依存、host必須生成物、CI・bootstrap・移行は後続。現行consumerへの自動接続は未実施。実運用承認源はB1/#1121で別受入する。
