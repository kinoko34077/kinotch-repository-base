# KiNoTch. Repository Base — Common README

この文書はKiNoTch.標準リポジトリの共通取扱説明書である。個別READMEへ同じ説明を複製しない。

## 基本境界

```text
README.md      = GitHub上の個別プロジェクト紹介
project/**     = 個別仕様・実装・設定・テスト
.kinotch/**    = 共通基盤。通常の個別開発では編集しない
KiNoTch.Runtime = 複数repoで再利用する共通実装。個別repoへコピーしない
```

Base-wide Metaは `.kinotch/meta/` に置き、新規Repository用の生成元は `.kinotch/templates/project/` に置く。Base自身のProject情報は `project/**` に記録し、Templateと混同しない。

## Default-first

共通要素はHard Base、Surface / Tool Default、Portable Semantic Contract、Project Overlay / Domainの4層へ分類する。低リスクで安全に外せる標準便利機能はDefaultとして先に提供し、Domain意味・公開互換性・永続形式・権限境界を持つものだけRuntimeのPortable Contract候補として検証する。正本と判断規則は [Default-first標準化方針](meta/06_DEFAULT_FIRST_STANDARD.md) に置く。

ProjectのDefault状態は `DEFAULT`、`OVERRIDE`、`DISABLED` のいずれかで表現する。Defaultの一覧と互換Surfaceは [Default Catalog](defaults/catalog.json) を正本とする。`knt init --profile <surface> --default <tool-default>` はCatalogから選択したPackを生成するが、既存の `project/project.json` を上書きしない。Surface選択はRuntime moduleを自動追加しない。

## 共通コマンド

Windows cmd:

```bat
knt.cmd doctor
knt.cmd setup
knt.cmd dev
knt.cmd test
knt.cmd build
knt.cmd verify
knt.cmd init --profile web-app --default pwa
knt.cmd init --profile cli --profile mcp --default verify
knt.cmd migrate --profile cli --default verify
knt.cmd smoke
```

PowerShell:

```powershell
.\.kinotch\scripts\knt.ps1 doctor
```

各コマンドの実体は `project/project.json` の `commands` に定義する。Base側の入口は変更しない。

## doctor

`doctor` は以下を確認する。

- Base共通ファイルが変更されていないか
- `project/project.json` がProject Schemaに適合するか
- Action Registry / Surface RegistryがSchemaに適合するか
- 選択Profileが存在し、Profile / Surfaceに明らかな矛盾がないか
- Manifest pathsとcommand cwdが存在するか
- Default Catalogが正しく、Default stateが `DEFAULT` / `OVERRIDE` / `DISABLED` のいずれかであるか
- 定義済み共通コマンド

環境固有診断は、後からKiNoTch. Runtimeのdoctor moduleとして追加可能とする。

`base-refresh` は `repository-base` 自身でのみ使用するBase index再生成入口である。通常の個別Repositoryから共通ファイルを勝手に更新するためのコマンドではない。

## init / migrate

`knt init --profile <surface>` は `minimal`、`web-app`、`cli`、`windows-gui`（`windows` alias）、`mcp`、`api`、`agent`、`library` を複数選択し、TemplateからProject Overlayを生成する。`--default <tool-default>` で `verify`、`ci-test`、`generated-integrity`、`file-io`、`pwa`、`pages`、`secrets`、`local-app` 等のTool Defaultも選択できる。選択ProfileはSurface宣言だけを生成し、`runtime.modules` は空のまま保持する。既存の `project/project.json` または既存Projectファイルは上書きしない。

`knt migrate` は既存ProjectのSurface / Tool Default候補を表示するだけで、既定ではファイルを変更しない。`--apply` を明示した場合だけ `project/defaults.json` と必要なManifest pathを更新し、既存の `OVERRIDE` / `DISABLED` 状態は保持する。Domain fileは変更しない。

## Validatorの対応範囲

依存なしの `knt-validation.ps1` が実行するJSON Schema subsetは、`type`、`required`、`properties`、`additionalProperties`、`items`、`oneOf`、`enum`、`const`、`pattern`、`minLength`、`uniqueItems`である。`additionalProperties`へSchema Objectを指定した場合は未知propertyへそのSchemaを適用し、`oneOf`は候補へちょうど1つ一致した場合だけ成功する。

`$schema`、`$id`、`title`はSchema metadataとして扱う。Runtime契約定義の`result.schema.json`にある`$ref`は、現時点では明示的なsubset外であり、`knt doctor`の検証対象ではない。今後Schemaへ新しい実行keywordを追加する場合は、validator実装とSelf Testを追加するか、subset外として理由を文書化する。Self TestはBase Schema群に未対応keywordが混入していないかを監査する。

## verify

`project/project.json.commands.verify` があればそれを実行する。

未定義の場合は、定義済みの `test` と `build` を順に実行する。これにより技術スタックが違ってもAgent・人間から見える操作語彙を固定する。

## 個別コードの置場

原則:

```text
project/src/
├─ core/         # Domain / 純粋処理。Surfaceを知らない
├─ application/  # Action / use case
└─ adapters/     # GUI / CLI / MCP / API / OS / external service
```

小規模repoでは不要な階層を無理に増やさず、`project/src/`直下から開始してもよい。

## 状態の分類

状態・ファイルを必要に応じて以下へ分類する。

- persistent: 正本として保存する状態
- session: 実行セッション中だけ必要
- cache: 再生成可能
- temp: 一時処理用
- generated: 正本から生成され手編集しない
- artifact: 利用者へ渡す成果物

保存形式そのものは各projectで定義する。

## .ai-guidelinesとの責任分離

KiNoTch. BaseはRepository構造、Agent入口、実装workflowを所有する。`.ai-guidelines` はUI/UXおよびDomain横断の設計ポリシーを所有する。同じ規則を双方へ全文複製しない。

## 共通化の判断

個別repoで便利だった処理を即Runtimeへ入れない。以下を満たす場合に昇格候補とする。

1. 複数repoで同じ知識として必要
2. 同じ理由で変更される
3. 個別実装を残すより依存・矛盾を減らせる
4. Surface / Domain固有事情をRuntimeへ漏らさず切り出せる
