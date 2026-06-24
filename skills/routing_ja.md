# リバースエンジニアリング・スキルルーティングマトリクス

ターゲット種別、ユーザーの意図、ツールチェーンに基づいて、タスクを最も適切なスキルモジュールへルーティングします。

## CRITICAL: ルーティング実行プロトコル

1. 実行する **前に** ルーティングを必ず完了する。「まず実行、後でルーティング」をしない。
2. スキルに入る前に、必ず 3 つの次元（ターゲット種別 + ユーザー意図 + ツールチェーン）すべてに一致させる。
3. ルートが一致しない → 新規スキルを提案する。無理に当てはめない。
4. モジュール横断タスク → 「Path Crossing」セクションに従ってスキルを組み合わせる。
5. ルーティング後、アクションを起こす前に対象スキルの SKILL.md を読む。

## ターゲット種別別

| ターゲット種別 | 推奨エントリー | 代替 |
|-------------|------------------|-------------|
| APK / Android アプリ | `apk-reverse/` — jadx デコンパイル + apktool 展開 | コアが .so にある場合 → `ida-reverse/` または `radare2/` |
| バイナリ exe/dll/so/elf | `ida-reverse/` — IDA Pro デコンパイル | `radare2/` — CLI 解析、または `reverse-engineering/tools.md` — GDB/Unicorn |
| JavaScript / Web フロントエンド | `js-reverse/` — 5 段階ワークフロー | anything-analyzer MCP のブラウザツール、または jshookmcp CDP/Hook |
| HTTP キャプチャ / ブラウザサンプリング / リクエストリプレイ | anything-analyzer MCP (23816) | `js-reverse/`、jshookmcp、または `competition-web-runtime/` |
| ファームウェア / IoT | `reverse-engineering/platforms.md` — binwalk/ARM/MIPS | `reverse-engineering/tools.md` — Ghidra ヘッドレス |
| WASM / Python バイトコード / .NET | `reverse-engineering/languages.md` | 該当言語のセクションを確認 |
| macOS / iOS | `reverse-engineering/platforms.md` — Mach-O/ObjC/Swift | iOS 固有は `mobile-reverse/` |
| ゲーム（Unity/Unreal） | `game-security/` — エンジンリバース、アンチチート、IL2CPP/Mono | `ida-reverse/` 深い解析 |
| メモリダンプ / PCAP | `reverse-engineering/platforms.md` | `reverse-engineering/patterns*.md` |
| マルウェア / ウイルス検体 | `reverse-engineering/` — YARA/サンドボックス/挙動解析 | `ida-reverse/` 深い解析 |
| 暗号 / 暗号化アルゴリズム | `reverse-engineering/patterns*.md` — 暗号パターン | `js-reverse/`（フロントエンド暗号の場合） |
| プロトコルリバース / カスタムプロトコル | `reverse-engineering/platforms.md` — ネットワークプロトコル | `js-reverse/`（WebSocket/HTTP の場合） |
| Go / Rust バイナリ | `reverse-engineering/languages-compiled.md` + `go-reverse.md` | `ida-reverse/` または `radare2/` |
| LLM / AI アプリケーション | `llm-security/` — OWASP LLM Top 10 + ASI Top 10 | プロンプトインジェクション、エージェントセキュリティ |
| API / REST / GraphQL | `api-security/` — BOLA/BFLA/JWT/OAuth | スキャンは `pentest-tools/` |
| サプライチェーン / SBOM / CI-CD | `supply-chain-security/` — Trivy/Syft/Gitleaks | — |
| iOS アプリ（IPA） | `mobile-reverse/` — class-dump/Hopper/Frida iOS | `reverse-engineering/platforms.md` |
| **CTF 競技（フルスタック）** | `../CTF-Sandbox-Orchestrator/ctf-sandbox-orchestrator/SKILL.md` — マスターエントリー | 証拠に基づき 40 以上のサブスキルへルーティング |
| Web ランタイム / API | `../CTF-Sandbox-Orchestrator/competition-web-runtime/SKILL.md` | — |
| クラウド / コンテナ / K8s | `../CTF-Sandbox-Orchestrator/competition-agent-cloud/SKILL.md` | — |
| Windows / AD / アイデンティティ | `../CTF-Sandbox-Orchestrator/competition-identity-windows/SKILL.md` | — |
| フォレンジック / PCAP / ステガノグラフィ | `../CTF-Sandbox-Orchestrator/competition-forensic-timeline/SKILL.md` | — |
| プロンプトインジェクション / エージェント | `../CTF-Sandbox-Orchestrator/competition-prompt-injection/SKILL.md` | — |
| モバイル（Android/iOS） | `../CTF-Sandbox-Orchestrator/competition-android-hooking/SKILL.md` | — |
| ファームウェア / マルウェア検体 | `../CTF-Sandbox-Orchestrator/competition-firmware-layout/SKILL.md` | — |

## ユーザー意図別

| ユーザーの発言 | ルーティング先 |
|-----------|----------|
| 「デコンパイル / IDA で解析」 | `ida-reverse/SKILL.md` — IDA MCP ワークフロー |
| 「ソース復元 / 逆アセンブル」 | `reverse-engineering/SKILL.md` + `ida-reverse/` |
| 「Frida フック / 動的インジェクション」 | `reverse-engineering/tools-dynamic.md` — Frida セクション |
| 「radare2 / r2 で解析」 | `radare2/SKILL.md` — CLI ワークフロー |
| 「フロントエンドの署名 / 暗号化パラメータを探す」 | `js-reverse/SKILL.md` — 観察→キャプチャ→再構築 |
| 「jshookmcp / JS フック / CDP デバッグ」 | `js-reverse/SKILL.md` — 同じ JS/Web チェーン |
| 「APK 展開 / 再パッケージ / smali 修正」 | `apk-reverse/SKILL.md` — decode→rebuild-sign-install |
| 「アンチデバッグ / 検出回避をバイパス」 | `reverse-engineering/anti-analysis.md` |
| 「これは何の難読化 / VM か」 | `reverse-engineering/patterns*.md` — パターンで照合 |
| 「Go/Rust/Swift のリバース」 | `reverse-engineering/languages-compiled.md` + `go-reverse.md` |
| 「カーネルドライバ / Rootkit / LKM」 | `reverse-engineering/kernel-driver-reverse.md` |
| 「Python バイトコード / pyc」 | `reverse-engineering/languages.md` — Python セクション |
| 「シンボリック実行 / angr」 | `reverse-engineering/tools-dynamic.md` — angr セクション |
| 「環境パッチ / Node で再現」 | `js-reverse/references/env-patching.md` |
| 「CTF チャレンジ / 競技のリバース」 | `reverse-engineering/patterns-ctf*.md` |
| 「レポート / ドキュメントを書く」 | `docs-generator/` — 技術ドキュメント |
| 「ライトアップを書く」 | `docs-generator/` — CTF ライトアップテンプレート |
| 「Web ページを開く / ブラウザ自動化 / フォーム入力」 | `browser-automation/SKILL.md` — Playwright |
| 「ページをクロール / スクリーンショット / 自動ログイン」 | `browser-automation/SKILL.md` |
| 「デスクトップ自動化 / Windows 自動化」 | `browser-automation/SKILL.md` — OpenReverse |
| 「ゲームリバース / アンチチート / ハック解析」 | `game-security/SKILL.md` |
| 「Unity / IL2CPP / Mono」 | `game-security/SKILL.md` — Unity ゲームリバース |
| 「Unreal Engine / UE リバース」 | `game-security/SKILL.md` — UE ゲームリバース |
| 「Cheat Engine / メモリスキャン」 | `game-security/SKILL.md` — メモリ解析 |
| 「シンボル移行 / バージョン間比較」 | `binary-diff/SKILL.md` — LLM 一括移行 |
| 「PDB 欠落 / 旧バージョンのシンボル」 | `binary-diff/SKILL.md` — バージョン間シンボル移行 |
| 「bindiff / 関数オフセットの移行」 | `binary-diff/SKILL.md` — バイナリ差分 |
| 「ポートスキャン / Nmap」 | `pentest-tools/SKILL.md` — 情報収集 |
| 「脆弱性スキャン / Nuclei」 | `pentest-tools/SKILL.md` — 脆弱性検出 |
| 「SQL インジェクション / SQLMap」 | `pentest-tools/SKILL.md` — Web ペンテスト |
| 「ディレクトリ総当たり / FFUF / Gobuster」 | `pentest-tools/SKILL.md` — Web ペンテスト |
| 「パスワードクラック / Hashcat」 | `pentest-tools/SKILL.md` — パスワードクラック |
| 「ペネトレーションテスト / アクティブスキャン」 | `pentest-tools/SKILL.md` — ペンテストツールチェーン |
| 「SRC ハンティング / Bug Bounty」 | `pentest-tools/src-hunter/SKILL.md` — 19 のプレイブック + H1 事例 |
| 「WAF バイパス」 | `pentest-tools/src-hunter/references/payloader/` — 263 のバイパス手順 |
| 「図 / フローチャート / アーキテクチャを描く」 | `diagram-generator/SKILL.md` |
| 「攻撃経路図 / シーケンス図」 | `diagram-generator/SKILL.md` — Mermaid/Graphviz/PlantUML |
| 「マルウェア / ウイルス解析 / 検体解析」 | `reverse-engineering/SKILL.md` + YARA/サンドボックス |
| 「ファームウェア / IoT / binwalk / ARM」 | `reverse-engineering/platforms-hardware.md` |
| 「暗号 / AES / RSA」 | `reverse-engineering/patterns*.md` — 暗号パターン認識 |
| 「プロトコルリバース / Protobuf / カスタムプロトコル」 | `reverse-engineering/platforms.md` |
| 「クラウドセキュリティ / コンテナエスケープ / K8s」 | `../CTF-Sandbox-Orchestrator/competition-agent-cloud/SKILL.md` |
| 「プロンプトインジェクション / AI セキュリティ」 | `llm-security/SKILL.md` — OWASP LLM + ASI Top 10 |
| 「内部ネットワーク / 横展開」 | `pentest-tools/SKILL.md` + `references/network-attack-defense.md` |
| 「権限昇格」 | `pentest-tools/references/network-attack-defense.md` — 昇格セクション |
| 「Mimikatz / 認証情報の抽出 / PtH」 | `pentest-tools/references/network-attack-defense.md` |
| 「Kerberos / ドメインペンテスト / AD」 | `pentest-tools/references/network-attack-defense.md` |
| 「C2 / 永続化 / 遠隔操作」 | `pentest-tools/references/network-attack-defense.md` |
| 「ブルーチーム / 検知 / 防御 / IR」 | `pentest-tools/references/network-attack-defense.md` |
| 「APK セキュリティテスト / モバイルセキュリティ」 | `apk-reverse/references/apk-security-checklist.md` — OWASP MASTG |
| 「SSTI / テンプレートインジェクション」 | `pentest-tools/SKILL.md` — SSTImap |
| 「XSS スキャン / クロスサイトスクリプティング」 | `pentest-tools/SKILL.md` — XSStrike |
| 「WordPress ペンテスト / WP 列挙」 | `pentest-tools/SKILL.md` — WPProbe |
| 「C2 フレームワーク / 敵対者シミュレーション」 | `pentest-tools/SKILL.md` — AdaptixC2 |
| 「WiFi 攻撃 / 無線ペンテスト」 | `pentest-tools/SKILL.md` — Fluxion + aircrack-ng |
| 「NTLM リレー / 認証強制」 | `pentest-tools/SKILL.md` — Coercer |
| 「NetExec / CrackMapExec / nxc」 | `pentest-tools/SKILL.md` — ネットワークサービス列挙 |
| 「AI 自動ペンテスト / MCP セキュリティ」 | `pentest-tools/SKILL.md` — HexStrike AI / MetasploitMCP |
| 「Swarm / スウォームペンテスト / 自律スキャン」 | `pentest-tools/SKILL.md` — Pentest Swarm AI |
| 「レッドチーム / HW / 攻撃演習」 | `attack-chain/SKILL.md` — 攻撃チェーン全体のオーケストレーション |
| 「初期侵入 / 境界突破」 | `attack-chain/SKILL.md` — 境界突破フェーズ |
| 「近接ペンテスト / BadUSB / WiFi フィッシング」 | `attack-chain/SKILL.md` — 近接セクション |
| 「EDR バイパス / 回避 / AV バイパス」 | `attack-chain/SKILL.md` — EDR/AV 回避セクション |
| 「フィッシング / ソーシャルエンジニアリング」 | `attack-chain/SKILL.md` — フィッシングセクション |
| 「サプライチェーン攻撃」 | `attack-chain/SKILL.md` — サプライチェーンセクション |
| 「痕跡消去 / アンチフォレンジック」 | `attack-chain/SKILL.md` — クリーンアップセクション |
| 「フルペンテスト / エンドツーエンド」 | `attack-chain/SKILL.md` — 全チェーンの計画 |
| 「外部からドメインコントローラまで」 | `attack-chain/SKILL.md` — フェーズ横断のパスオーケストレーション |
| 「攻撃面の評価 / パス計画」 | `attack-chain/SKILL.md` — パス計画の意思決定ツリー |
| 「シェルを取った、次は何 / ポストエクスプロイト」 | `attack-chain/SKILL.md` — 現在の足場からの計画 |
| 「BurpSuite / Burp プロキシ / インターセプト」 | `pentest-tools/SKILL.md` + `references/burpsuite-mcp-guide.md` |
| 「Burp MCP / プロキシ履歴の解析」 | `pentest-tools/references/burpsuite-mcp-guide.md` — 63 ツール |
| 「Intruder 総当たり / Repeater リプレイ」 | `pentest-tools/references/burpsuite-mcp-guide.md` |
| 「Collaborator / OOB テスト」 | `pentest-tools/references/burpsuite-mcp-guide.md` |
| 「API セキュリティ / GraphQL / JWT 攻撃」 | `api-security/SKILL.md` — REST/GraphQL/JWT/OAuth |
| 「サプライチェーンセキュリティ / SBOM / SCA」 | `supply-chain-security/SKILL.md` — Trivy/Syft/Gitleaks |
| 「iOS リバース / IPA / Mach-O」 | `mobile-reverse/SKILL.md` — class-dump/Hopper/Frida iOS |
| 「Objection / SSL Pinning バイパス」 | `mobile-reverse/SKILL.md` — 動的インストルメンテーション |
| 「YARA / マルウェア検知ルール」 | `malware-analysis/SKILL.md` — YARA/Sigma/IOC |
| 「N-day / パッチ差分 / CVE 再現」 | `binary-diff/SKILL.md` — ghidriff/Diaphora/DeepDiff |
| 「pwn / スタックオーバーフロー / ROP / ret2libc」 | `reverse-engineering/patterns-ctf*.md` + pwntools |
| 「エージェントが動かない / AI が怠ける / ステップを飛ばす」 | `llm-security/references/agent-obedience-engineering.md` |
| 「MSF が止まる / 孤立プロセス / MSF プロトコル」 | `pentest-tools/references/msf-protocol.md` |
| 「匿名化 / プレースホルダー / ライトアップの脱機微化」 | `field-journal/anonymization.md` |
| 「Hydra / オンライン総当たり」 | `pentest-tools/SKILL.md` — オンラインパスワード攻撃 |
| 「Metasploit / msfconsole / エクスプロイト」 | `pentest-tools/SKILL.md` — エクスプロイトフレームワーク |
| 「Wireshark / パケット解析 / PCAP」 | `pentest-tools/SKILL.md` + `reverse-engineering/platforms.md` |
| 「BurpSuite / Web プロキシ / インターセプト」 | `pentest-tools/SKILL.md` — Web プロキシ |
| 「ProxyCat / プロキシプール / IP ローテーション」 | `pentest-tools/SKILL.md` — プロキシ管理 |

## ツールチェーン別

| ツール | 関連モジュール |
|------|---------------|
| IDA Pro (idapro_*) | `ida-reverse/` — MCP HTTP サーバー + 72 ツール |
| radare2 (r2/rabin2/rasm2) | `radare2/` — CLI + recon.ps1 |
| jadx / apktool | `apk-reverse/` — decode.ps1 / manifest-summary.ps1 |
| Frida | `reverse-engineering/tools-dynamic.md` |
| GDB / GEF / pwndbg / rr | `reverse-engineering/tools.md` |
| Ghidra（ヘッドレス） | `reverse-engineering/tools.md` + Ghidra MCP |
| angr / Qiling / Unicorn | `reverse-engineering/tools-dynamic.md` |
| BinDiff / Diaphora | `reverse-engineering/tools-advanced.md` |
| anything-analyzer MCP | ポート 23816 の MCP サーバー（ブラウザ + HTTP キャプチャ + AI 解析） |
| jshookmcp | ブラウザ/CDP/Hook/Network/SourceMap/AST 向けの `js-reverse/` 拡張 MCP |
| agent-browser / Playwright | `browser-automation/` — ブラウザ自動化 |
| OpenReverse (UIA/CUA) | `browser-automation/` — Windows デスクトップ自動化 |
| Cheat Engine / x64dbg / ReClass | `game-security/` — ゲームメモリ解析 |
| IL2CPP Dumper / dnSpy | `game-security/` — Unity/Mono ゲームリバース |
| LLM シンボル移行 / BinDiff 代替 | `binary-diff/` — バージョン間の一括移行 |
| Nmap / Masscan | `pentest-tools/` — ポートスキャン、サービス識別 |
| Nuclei / ZAP / Nikto | `pentest-tools/` — 脆弱性スキャン |
| SQLMap / FFUF / Gobuster | `pentest-tools/` — Web ペンテスト（インジェクション/総当たり） |
| SSTImap | `pentest-tools/` — SSTI 自動検出 |
| XSStrike | `pentest-tools/` — 高度な XSS スキャン |
| Hashcat / John / Hydra | `pentest-tools/` — パスワードクラック |
| Metasploit / Impacket | `pentest-tools/` — エクスプロイトフレームワーク |
| BurpSuite | `pentest-tools/` — Web プロキシ、インターセプト、脆弱性スキャン |
| BurpSuite MCP | `pentest-tools/` — 63 ツールの AI 完全制御。`references/burpsuite-mcp-guide.md` を参照 |
| ProxyCat | `pentest-tools/` — プロキシプール管理 & IP ローテーション |
| Cobalt Strike / Sliver / Havoc | `attack-chain/` — C2 フレームワーク |
| pentestMCP (Docker) | `pentest-tools/` — 20 以上のツールをワンクリック MCP |
| Mermaid / Graphviz / PlantUML | `diagram-generator/` — 図の生成 |
| garak / PyRIT / promptfoo | `llm-security/` — LLM レッドチームテスト |
| Trivy / Syft / Gitleaks / OSV-Scanner | `supply-chain-security/` — サプライチェーンスキャン |
| Objection / Frida iOS / class-dump | `mobile-reverse/` — iOS 動的解析 |

実際のツールの利用可否、パス、バージョンは `tool-index.md` を確認してください。パスを決して推測しないこと。

---

## ルートが一致しない場合 — 対処

現在のタスクが上記のいずれの表にも一致しない場合、**既存スキルに無理に当てはめない** こと:

1. 既存スキルのエッジケースかどうかを確認する（カバー範囲を拡張できる）
2. 本当に新しい種別なら、ユーザーに能動的に新規スキルを提案する:
   - 提案するスキル名とカバー範囲
   - 必要なツールチェーン
   - 既存スキルとの関係
3. ユーザーが確認 → `CONTRIBUTING.md` に従って実行する
4. 作成後、このルーティングマトリクスを更新する

**AI はユーザーがギャップに気づくのを待つ必要はありません。ルーティングの失敗こそが、新規スキルを提案するシグナルです。**

## Path Crossing（モジュール横断シナリオ）

一部のタスクは複数のモジュールにまたがります。よくある横断:

```
APK リバースのパス:
  apk-reverse/decode.ps1 → Java レイヤーの解析
  ↓ コアが .so にある場合
  ida-reverse/ または radare2/ → .so の解析
  ↓ 動的検証が必要な場合
  apk-reverse/frida-run.ps1 → Frida フック

フロントエンド JS リバースのパス:
  js-reverse/観察 → 対象リクエストを特定
  ↓ より強力なブラウザ/CDP/Hook/Network 機能が必要
  jshookmcp → ランタイムのサンプリング、ブレークポイント、インターセプト、SourceMap/AST
  ↓ エントリ関数を確認後
  js-reverse/再構築 → Node でのローカル再現
  ↓ 環境パッチが必要
  js-reverse/references/env-patching.md

バイナリリバースのパス:
  radare2/recon.ps1 → クイック偵察
  ↓ 深い解析
  ida-reverse/ → IDA デコンパイル
  ↓ 動的検証
  reverse-engineering/tools-dynamic.md → Frida/GDB

CTF 競技のパス（CTF-Sandbox-Orchestrator 経由）:
  ctf-sandbox-orchestrator/SKILL.md → サンドボックスモデルを構築
  ↓ 主要な証拠でルーティング
  competition-web-runtime/ または competition-reverse-pwn/ または competition-identity-windows/
  ↓ 行き詰まり → マスターに戻る
  ctf-sandbox-orchestrator → 再ルーティング

Web ペンテスト + BurpSuite MCP のパス:
  browser-automation/ → Burp プロキシ経由で対象を自動ブラウズ
  ↓ トラフィックをキャプチャ
  burpsuite MCP proxy_history → AI が全リクエストを解析
  ↓ 疑わしいエンドポイントを発見
  burpsuite MCP intruder_attack → 自動列挙
  ↓ 脆弱性を確認
  docs-generator/ → ペンテストレポートを生成
```
