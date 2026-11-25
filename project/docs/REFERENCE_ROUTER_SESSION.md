# 参照型Routerの統合実行（候補）

#66 B1/B2。信頼済みhostの session 実行入口を再利用する。UseSnapshot の有効期間内に中央の既存Routerを明示ReferenceModeで起動し、実commit、mode、cache再利用、command、native exit code、診断を返す。失敗を成功へ変換しない。版選択、Default判断、cache/cleanupの再実装は行わない。

通常Project commandと診断のみ。deploy/init/migrate/base-refresh/base-patchは別の権限・変更境界、reference-pathの返す一時pathはsession外へ持ち出さないためこの入口の対象外。将来の薄いhost callerは結果のexit_codeを終了値へ対応させる。

試験では有効な保護indexを持つA/B版のschemaを切り替え、同じconsumerでdoctorの失敗→成功・verify・offline旧版・cache reuse・stage cleanup・consumer無変更を確認する。合成承認のみ。本番の承認元/host保護/remote取得/配備は未受入。

追加引数は信頼済みhostがsession内の一時JSONにデータとして書き、固定child scriptが既存RouterのRemainingArgsへ明示bindする。RootOverride/BaseOverride等はhost固定値であり利用側引数で上書きしない。structured forward_argsのみ許可、legacy拒否は既存Routerに委譲する。payloadはsession内で消去する。

## 共通host入口と連続検証（B3接続候補）

`Invoke-KntBaseHostCommand` は信頼済みhostの既存 `Invoke-KntPublicReferenceSession` とRouter adapterを接続する。Baseの正規repo/IDを固定し、consumerが供給元・承認resolver・policy・host rootを選択する入口にしない。通常commandの返却と `-Verification`（doctor/setup/verifyの既存順序）を提供する。後者は一回だけ版を解決し、同一SHAで各処理を実行、最初の非成功で残りを実行せず各結果と終了値を返す。正式検証ではCURRENTのみ、通常commandは承認済みOFFLINEも可。実行結果は#1121の証拠に接続するための素材であり、真正性・鮮度・保証の同等性・CI省略を決めない。host配置/保護/承認元/production callerは未受入。既存workflowを変更しない。


## ローカルCLI・Bootstrap/移行共通入口候補

信頼済みhostにだけ `base-source/project/src/reference-cli.ps1` を配置する。host root直下の `reference-host-profile.ps1` は保護側が設置する唯一の設定入口であり、GitExecutable/Channel/PolicyRevision/ResolveApproved（scriptblock）と任意PinnedCommitを返す。consumerがprofile・供給元・承認元を指定できない。profile欠落時は非成功、未承認版の取得・実行へfallbackしない。通常CLIは `reference-cli.ps1 <consumer-root> <command> [arguments...]`、正式連続検証は `verification`。出力は診断、真正CI receiptではない。host設置・profileの真正性/アクセス保護・admissionは別受入。

`project/templates/reference/AGENTS.md` と `knt.cmd` は新規明示採用と既存移行で同じ中央ファイルを参照する。Windowsの薄い `knt.cmd` は信頼済みローカルshellが一度設定した絶対host executable/entryの環境変数を利用する（CIの信頼境界ではない）。host profile/loader/固定版をconsumerへ置かない。正式workflowは#1121の承認済み共通callerをBootstrapの既存SEED/verify保護契約に接続する。未受入workflowの名前やSHAを仮定して生成しない。既存minimal/replayを変えない。


## 新規Project seedの共通供給

`Invoke-KntReferenceSeedSession` は既存の承認済みsnapshot sessionを一回利用し、固定10pathの新規Project seedを返す。中央AGENTS/knt.cmdと既存Project docs/contract templatesを読み、明示manifest/defaults/specは保持、正式Verify内容は信頼済みhost（#1121 owner）からのみ供給。標準初期pathに限定し、独立stageで既存doctorの中央index/Schema/互換/ローカル必須物の検査を通す。Project commandは実行しない。CURRENT以外/不足素材/非互換/必要なhost asset不足は拒否、stageを消去する。seed結果はdevflow #1168/#1169が消費する形式であり、新規repoの書込・実運用provider配線・CI証拠の真正性は別責務。
