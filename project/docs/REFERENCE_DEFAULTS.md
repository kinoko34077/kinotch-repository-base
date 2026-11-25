# 参照型Defaultの利用契約（B2候補）

Owner: #66。source候補0.5.27、release/Canary受入ではない。

`-ReferenceMode -RootOverride <consumer> -BaseOverride <admitted-base>/.kinotch reference-path config generated-integrity:check mcp:contract`

既存RouterとDefault Catalogの `reference_entries`（role → 現在の所有テンプレートのproject/tools/またはproject/contracts/）を利用する。新規の個別ローダーや別Catalogを作らない。信頼済みhostが取得・承認したBase snapshotを供給し、利用中に版を変えない。Routerは中央Base indexと選択pack/互換性を検証する。複数のpack:roleを一回で解決し、role省略はdefault。JSONのreferencesにid/entry/state/pathを返す。DISABLEDはpath=null。未知・未選択・不整合は非成功。pathはsnapshotの利用期間内だけ有効。

DEFAULTは中央の所有helper/contractを参照し、OVERRIDEは同じ公開入口を要求した場合のみProject所有entryへ接続、DISABLEDは読み込まない。中央参照対象に旧materialized provenanceや同名local fileが残る場合は暗黙上書きせず明示移行を要求する。参照対象以外のtemplate（generated-integrity.json等のProject data、PWA公開物、host workflow）はlocalに残る。doctorはその存在と既存provenanceを引き続き検査し、中央参照対象だけlocal materializationを要求しない。従来modeは既存挙動を維持する。

file-io、generated-integrity check/update、PWA checkは明示RootOverride/BaseOverrideを共通contextに解決し、中央helperがProject rootのデータを処理する。MCPはResolve-McpProjectPathのBaseOverrideで中央containmentを利用する。Routerのgenerated-integrity/pwa-check/verifyはDEFAULTの中央entryを選択し、OVERRIDEは既存Project helper、DISABLEDは実行しない（明示check要求時は非成功）。書込はfile-io save/update等の明示操作でProject内に限る。ReferenceModeは旧base-patchを適用しない。既存init/migrate外部apply拒否を維持する。

ホスト必須CI caller・Project固有dataの生成/移行、B1承認元、B3/B4接続は後続。既存consumerへの自動適用は未実施。
