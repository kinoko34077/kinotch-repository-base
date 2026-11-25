# AGENTS.md

このリポジトリは参照型 KiNoTch. Repository Base を明示採用する。

- 個別仕様の入口は `README.md`、`project/project.json`、`project/docs/INDEX.md`、`project/docs/CURRENT_STATE.md`。
- 横断開発原則は [devflow AGENTS.md](https://github.com/kinoko34077/devflow/blob/main/AGENTS.md) とそこから参照する正本に従う。
- Baseの共通規則・Schema・Default実装は [Repository Base](https://github.com/kinoko34077/kinotch-repository-base) が所有する。利用時に信頼済みhostが解決した固定版を参照し、個別repoに複製しない。
- Project固有の実装・設定・データ・OVERRIDEは個別repoが所有する。共通機能の修正は中央ownerへ。
- ローカルの通常操作は信頼済みhostの共通入口（Windowsでは `knt.cmd doctor` 等）。host未設定時は失敗し、未承認のコードを取得・実行しない。正式CIは独立した承認済み共通callerを利用する。

共通入口を利用しても、既存のReview・権限・公開・不可逆操作の承認条件を変更しない。
