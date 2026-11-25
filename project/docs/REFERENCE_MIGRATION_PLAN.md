# 旧Base参照型移行の判定（B4候補）

#66。信頼済み旧Baseのexact commitとconsumerのexact commitを入力とする、Git treeのread-only plan。consumerが自己申告したindexや作業treeは削除の根拠にしない。

- 旧 .kinotch tree（index含む）のmode/SHAが完全一致した場合のみ退役候補。差異・追加・patch chainは保存し、移行を保留。候補は実際の削除許可ではない。
- AGENTS.md/knt.cmd/verify.ymlは旧正本と同じなら最小入口への置換候補。違えば保持して明示判断。既存root設定とProject固有ファイルは保持する。
- 適用段階ではexact consumer head、clean state、承認済み置換内容、既存チェック契約、Projectの実テスト、revertを確認する。現在は適用処理を実装しない。

代表実データ: memory-game 7c524d1e2ecdb2a15b69037b9e51bf1456ed56f5、旧Base 5e3d45661f71ca12cddb87e0760cb59760fbd55a (0.3.8)。保護97+indexの98 blob SHA/mode一致、.kinotch extraなし、consumer tree 39e56a8428632eeb17dd8f0c468a319e0fecc1b0。これはGitHub実treeの読取証拠であり、本関数の実repo実行・移行受入ではない。全repo適用は対象外。
