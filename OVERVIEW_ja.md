# サイバーセキュリティスキルルーター 概要

> コードエージェント向けのワークフロールーター兼ツールオーケストレーションシステム: タスクを分類し、適切なスキルを選び、実際のツールを呼び出して実行する。

このリポジトリを初めて見る場合は、ここから始めてください。`README.md` / `README_zh.md` は AI エージェント向けのブートストラップエントリーであり、指示が密で、実行優先、エージェントが自分自身を設定するために最適化されています。この概要は、人間の読者、オープンソースのユーザー、協力者向けです。

## これは何か?

サイバーセキュリティスキルルーターは、Claude Code、Codex CLI、Cursor、Cline、Windsurf、Kiro などのコードエージェント向けの **スキルルーター + ツールオーケストレーション** システムです。

エージェントが APK、バイナリ、フロントエンドの JavaScript、HTTP トラフィック、CTF チャレンジ、ファームウェア、セキュリティテストのタスクを、再現可能なワークフローで扱えるよう支援します:

1. ターゲットとユーザーの意図を分類する
2. 適切なスキルと方法論へルーティングする
3. ローカルツール、MCP サーバー、スクリプトのエントリーポイントを確認する
4. 実際のツールを呼び出して解析を実行する
5. レポートを生成し、再利用可能な経験をフィールドジャーナルに書き戻す

要するに:

> これは単一ツールのインストーラーではありません。AI エージェントに、推測を減らしより構造化された形でセキュリティおよびリバースエンジニアリングのタスクを実行させるための、ワークフローのオペレーティングシステムです。

## なぜ存在するのか?

汎用のコードエージェントは、セキュリティやリバースエンジニアリングのワークフローでしばしば苦労します:

- jadx、apktool、Frida、IDA、radare2、BurpSuite のどれを使うべきか分からない
- APK、ELF、JS、PCAP、CTF のタスクは、それぞれ異なるプレイブックを必要とする
- ツール、MCP サーバー、ローカルスクリプトがマシン間に散在している
- 経験が再利用されないため、同じミスが繰り返される
- エージェントは多くを説明する一方で、実際の実行パスに決して入らないことがある

このプロジェクトは、その混沌を明確な実行チェーンに変えます:

```text
ユーザーのタスク
  ↓
RULES.md
  ↓
スキルルーター
  ↓
シナリオ固有のスキル
  ↓
ツール / MCP / スクリプト
  ↓
レポート + フィールドジャーナル
```

## 中核機能

| 機能 | 説明 |
|---|---|
| スキルルーター | ターゲット種別、ユーザー意図、ツールチェーン要件でタスクをルーティングする。 |
| ツールオーケストレーション | jadx、apktool、Frida、radare2、IDA、BurpSuite、ブラウザ、スクリプトを連携する。 |
| MCP 統合 | BurpSuite、IDA、ブラウザ解析などの実行面をエージェントに公開する。 |
| ブートストラップスクリプト | ローカルツールの状態を検出し、自動または手動のセットアップを誘導する。 |
| フィールドジャーナル | タスク後に再利用可能な教訓、コマンド、落とし穴、パターンを保存する。 |
| レポート生成 | 解析レポート、図、攻撃経路、CTF ライトアップを生成する。 |

## プラットフォームサポート

| プラットフォーム | 状態 | エントリー |
|---|---|---|
| Windows | 主要パスを完全サポート | `README.md`、PowerShell スクリプト |
| Kali Linux | 専用サポート | `kali/README-kali.md` |
| Ubuntu / Debian Linux | 汎用サポート | `docs/platforms/linux.md`、`skills/scripts/bootstrap-reverse.sh`、`skills/scripts/refresh-tool-index.sh` |
| macOS | 汎用サポート | `docs/platforms/macos.md`、`skills/scripts/bootstrap-reverse.sh`、`skills/scripts/refresh-tool-index.sh` |

完全なプラットフォームマトリクスは [PLATFORMS.md](PLATFORMS.md) を参照してください。通常の Linux および macOS のユーザーは、次のコマンドでブートストラップの機能（capability）一覧を表示できます:

```bash
bash skills/scripts/bootstrap-reverse.sh --list
```

インデックスの更新のみを行う場合は、次を実行します:

```bash
bash skills/scripts/refresh-tool-index.sh
```

## サポートするエージェントクライアント

- Claude Code
- Codex CLI
- Cursor
- Cline
- Windsurf
- Kiro
- プロジェクトルール、システムプロンプト、MCP、外部ツールをサポートするその他のコードエージェント

このリポジトリは単一のクライアントに縛られていません。中核となる資産は、`RULES.md`、`skills/SKILL.md`、`skills/routing.md`、ツールインデックス、サブスキル、MCP/スクリプトのエントリーポイントです。

## サポートするシナリオ

| シナリオ | 主なエントリー |
|---|---|
| APK / Android 解析 | `skills/apk-reverse/`、`skills/mobile-reverse/` |
| バイナリリバースエンジニアリング | `skills/ida-reverse/`、`skills/radare2/`、`skills/reverse-engineering/` |
| フロントエンド JS の署名 / パラメータ解析 | `skills/js-reverse/` |
| HTTP トラフィック / リクエストリプレイ | BurpSuite MCP、anything-analyzer、ブラウザ自動化 |
| CTF / セキュリティ競技 | `CTF-Sandbox-Orchestrator/` |
| ファームウェア / IoT 解析 | `skills/firmware-pentest/` |
| パッチ差分 / N-day 解析 | `skills/patch-diff-exploit/` |
| セキュリティテストのツールチェーン | `skills/pentest-tools/` |
| LLM / エージェントのセキュリティ | `skills/llm-security/` |
| レポートと図 | `skills/docs-generator/`、`skills/diagram-generator/` |

## ワークフローの例

ユーザーのリクエスト:

```text
この APK の署名検証ロジックを解析して。
```

期待されるエージェントの振る舞い:

1. タスクを APK / Android / 署名検証と特定する
2. `apk-reverse` へルーティングし、必要に応じて Frida やネイティブ `.so` 解析へ切り替える
3. jadx、apktool、adb、Frida が利用可能かを確認する
4. APK を展開し、Manifest、Java コード、ネイティブライブラリを検査する
5. 静的解析で十分か、動的フックが必要かを判断する
6. 検証箇所、コールチェーン、バイパスのアイデア、検証手順を報告する
7. レポートを生成し、再利用可能な教訓をフィールドジャーナルに書き込む

## リポジトリ構成

```text
.
├── README.md                    # AI エージェントのブートストラップエントリー（英語）
├── README_zh.md                 # AI エージェントのブートストラップエントリー（中国語）
├── OVERVIEW.md                  # 人間向けの概要（英語）
├── OVERVIEW_zh.md               # 人間向けの概要（中国語）
├── RULES.md                     # グローバルなルーティングと実行のルール
├── ARCHITECTURE.md              # アーキテクチャのメモ
├── skills/                      # メインのスキルディレクトリ
│   ├── SKILL.md                 # コントローラーのエントリー
│   ├── routing.md               # ルーティングマトリクス
│   ├── field-journal/           # 経験ジャーナル
│   ├── apk-reverse/
│   ├── js-reverse/
│   ├── reverse-engineering/
│   ├── ida-reverse/
│   ├── radare2/
│   └── ...
├── CTF-Sandbox-Orchestrator/    # CTF シナリオのサブスキル
├── burp-mcp-full/               # BurpSuite MCP 制御モジュール
└── kali/                        # Kali ヘルパースクリプト
```

## クイックスタート

### 人間向け

1. この概要を読んでプロジェクトを理解する
2. `README.md` または `README_zh.md` を読み、エージェントにブートストラップフローを実行させる
3. クライアント向けに MCP、プロジェクトルール、システム指示を設定する
4. 実際のタスクでルーティングを検証する

### AI エージェント向け

あなたが AI エージェントなら、この概要で立ち止まらないでください。実行パスに入ってください:

1. `README.md` または `README_zh.md` を読む
2. セクション 0 を実行する
3. `RULES.md` を読む
4. `skills/SKILL.md` と `skills/routing.md` をロードする
5. まずルーティング、それから実行する

## プロンプトパックとの違いは?

プロンプトパックは通常、モデルにアドバイスを与えます。このプロジェクトは実行可能な構造を重視します:

- 明確なエントリー: `RULES.md`、`SKILL.md`、`routing.md`
- シナリオルーティング: 異なるターゲットは異なるスキルに入る
- 実行面: MCP、スクリプト、ローカルツールチェーン
- 経験のフィードバック: 完了したタスクが再利用可能な知識を更新する
- 移行サポート: 新しいマシンでツールインデックスを再スキャンし、ワークフローを復元する

エージェントが推測を減らし、ステップを飛ばさず、より確実に実行できるよう設計されています。

## セキュリティと責任ある利用

このプロジェクトは、認可されたセキュリティ研究、リバースエンジニアリング、CTF、教育用ラボ、内部のセキュリティテスト、防御的な検証を目的としています。対象システムを解析またはテストする許可があることを確認してください。

ブートストラップ README のルールは、認可された環境において確認ループの繰り返しやワークフローの停滞を減らすことを意図しています。それらは、認可のないアクセス、破壊的な操作、実際のターゲットへの攻撃を推奨するものではありません。

## プロジェクトの位置づけ

このプロジェクトを簡潔に説明する方法:

> 私は、リバースエンジニアリング、セキュリティテスト、CTF のタスクを、ルーティング可能・実行可能・再利用可能なワークフローに変える、コードエージェント向けのスキルルーターを設計してオープンソース化しました。ローカルツール向けの MCP/スクリプト統合を備えています。

キーワード: AI エージェント、スキルルーター、ツールオーケストレーション、MCP、ワークフロー自動化、セキュリティ解析、フィールドジャーナル。

## 関連ドキュメント

- [README.md](README.md): 英語の AI ブートストラップエントリー
- [README_zh.md](README_zh.md): 中国語の AI ブートストラップエントリー
- [PLATFORMS.md](PLATFORMS.md): プラットフォームサポートマトリクス
- [docs/platforms/linux.md](docs/platforms/linux.md): 汎用 Linux のセットアップ
- [docs/platforms/macos.md](docs/platforms/macos.md): macOS のセットアップ
- [RULES.md](RULES.md): グローバルな実行ルール
- [ARCHITECTURE.md](ARCHITECTURE.md): アーキテクチャのメモ
- [skills/routing.md](skills/routing.md): ルーティングマトリクス
- [burp-mcp-full/README.md](burp-mcp-full/README.md): BurpSuite MCP モジュール

## ライセンス

MIT ライセンス。[LICENSE](LICENSE) を参照してください。
