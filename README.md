# KiNoTch. Repository Base

KiNoTch. Repository Base は、KiNoTch.形式のRepositoryを新しく作り、読み、検証するための共通基盤です。

## このRepositoryの役割

- 個別Repositoryの読取順序とAgent入口を標準化する
- 共通のmanifest、profile、surface、schema、command routerを提供する
- 個別仕様と共通基盤を物理的に分離する
- Base自身の変更と検証を再現可能にする
- KiNoTch. Runtimeへ接続するための宣言境界を定義する

## ディレクトリ境界

- README.md: このBase Repository自身のGitHub向け入口
- project/: Base自身の仕様、設定、契約、自己テスト
- .kinotch/: 個別Repositoryへ配布する共通Base、schema、profile、tooling
- KiNoTch. Runtime: 別Repositoryで実装する共有Runtime。ここへコピーしない

通常の個別Repositoryでは README.md と project/** を編集し、.kinotch/** や共通Agent規則は編集しません。Base自身を開発する場合のみ共通層を変更します。

## 新規Repositoryでの使い方

新規RepositoryへBaseを適用する場合は、.kinotch/templates/project/ を生成元としてREADME、project.json、docs、contractsを作成します。個別の目的、入力、出力、Domain Core、必要Surface、必要Runtime moduleだけを project/** に定義します。

共通入口は次のとおりです。

~~~powershell
.\knt.cmd doctor
.\knt.cmd setup
.\knt.cmd dev
.\knt.cmd test
.\knt.cmd verify
~~~

## Runtimeとの関係

BaseはProject Manifest、Profile、Repository構造、Surface宣言、Runtime version/module参照を所有します。Action実行、Cancellation、Resource利用などのExecution Contractと実装は、Base v0.xでは論理宣言に留め、KiNoTch. Runtime側で検証します。

## 詳細資料

- [BaseのProject定義](project/project.json)
- [仕様](project/docs/SPEC.md)
- [現在状態](project/docs/CURRENT_STATE.md)
- [仕様索引](project/docs/INDEX.md)
- [共通Baseの説明](.kinotch/README_BASE.md)
- [Base Meta](.kinotch/meta/README.md)
- [Base v0.2設計ADR](project/docs/adr/0001-base-v02-hardening.md)
