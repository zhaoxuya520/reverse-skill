# 2026-10-08 Flutter APK 靜態 Telemetry 欄位 + 通知演算法提取（Tesla 訂閱車輛 App）

## 场景分类
APK 逆向 / Flutter AOT 靜態字串表分析（非動態 dump）

## 目标概述
本地自有 XAPK（`{target_app}` 16.1.8，Tesla 訂閱車輛第三方 App）純靜態提取：完整 API 端點地圖、~290 個 telemetry 欄位目錄、63 個車輛指令端點、29 種通知類型與觸發演算法，產出繁體中文正式報告。

## Scope 摘要（脱敏）
- auth_basis: 使用者本地自有檔案（offline-sample preset），未連線、未執行、未抓包
- network_profile: offline（純本地二進位 + 本地化字串）
- asset_types: [android_xapk, flutter_aot_libapp.so, kotlin_shared_module, android_manifest]

## 角色
- lead_role: lead
- specialists: []

## 完整执行链路

1. 目標識別：XAPK 解包 → base APK（Flutter 殼 + Kotlin 共享模組）+ armeabi_v7a split（`libapp.so` 31.5MB Dart AOT）+ 17 語言 split
2. 雙路並行：(a) jadx `-Xmx10g` 反編譯 base APK → `com.{target_pkg}.shared.*` 完整 Gson 車輛實體 + Retrofit 介面；(b) 自製 Python 腳本從 `libapp.so` 抽 111,030 唯一字串 → 分類為點分路徑(201)、snake_case(1,083)、URL 路徑(224)、`command/*`(63)
3. reFlutter 評估後棄用（動態 dump 工具，需真機+Burp+自製 engine，與 offline 範圍不相容）
4. Dart AOT 物件表偏移聚類：`@{lib_offset}` 同一偏移 = 同一源檔案 → 以通知模型檔案偏移抽出 63 個物件名 → 29 個 `*Notification` 類 + 設定方法表
5. 本地化觸發字串（英文 241 條）逐條對應到 29 類通知 → 觸發條件表
6. 雙來源交叉驗證：Dart 字串表 × Kotlin Gson `@SerializedName` 欄位 → 欄位目錄逐欄位標 [D]/[K]/[D+K]
7. FCM payload 欄位 + AndroidManifest channel（`important`）+ 多國語言 `messages_*` 檔名 → 通知顯示管線
8. 報告：12 章 + 3 張 mermaid 圖 + E-001…E-014 證據鏈 + 信心等級（高/中/低）逐條標註

## Evidence 链摘要
| E-id | severity | status | source_type | 可复用命令模式 | 关联 Finding |
|------|----------|--------|-------------|----------------|--------------|
| E-001 | info | observed | command | `python tools/extract_strings.py libapp.so > strings.txt`（offline 字串表抽取） | F-001 |
| E-002 | info | observed | artifact | `jadx -Xmx10g --no-res base.apk`（Kotlin Gson 實體交叉驗證） | F-001 |
| E-003 | info | observed | command | `python -c "re.findall(rb'@(\d+)', ...)"` 偏移聚類 + 本地化字串對應 | F-002 |

## Finding / Path 摘要
- top_finding: Flutter AOT 快照的**字串常數完整存活**（JSON 鍵/端點/物件名），配合 Kotlin 共享模組（同 wire format 的第二實現）可純靜態建立 ~290 欄位的 API 契約目錄，無需動態 dump；演算法級結論（狀態過渡比較、保養到期公式）只能標中信心
- path_type: callflow
- path_one_liner: XAPK 解包 → libapp.so 字串表分類 + jadx Kotlin 實體 → 雙源交叉驗證 → 欄位/端點/指令/通知演算法目錄

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| jadx 首次 84% OOM | 預設堆不足，DEX 大（多 split） | `-Xmx10g` 重跑；少數類（BaseService）仍缺失 → 改由 Dart 字串表補證 | 0.5h |
| apktool base resources 解碼失敗 | framework 目錄在工作區外（sandbox） | 接受失敗；jadx resources + zh split 資源已足夠 | 0.2h |
| reFlutter 無法使用 | 動態 dump 工具：需改 libapp.so、真機執行、Burp、自製 Flutter engine | 棄用；改靜態字串表法（本案 Flutter 3.x 字串表無混淆） | 0.5h |
| pwsh 內嵌 python 單行（含引號）SyntaxError | Windows 引號轉義地獄 | 一律寫 `tools/*.py` 檔案再執行 | 0.1h |
| 手抄 63 指令清單重複/錯字 | 人工從 111k 字串表目視 | 改 `tools/gen_commands.py` 程式化生成 | 0.3h |
| 類級 `@offset` 正規表示例 0 命中 | Dart AOT 物件名偏移是**每個物件獨立**的 lib 偏移，同一源檔物件共享偏移 | 用偏移**聚類**（同偏移物件同檔案）代替類級註解思路 | 0.5h |
| `^alert$` 等 3 字串 grep 0 命中 | 抽取腳本最小長度過濾掉 2–4 字元字串 | 改用 python membership 測試驗證短字串存在性 | 0.1h |

## 工具链发现
- **Dart AOT 靜態字串表法**（本次核心）：`libapp.so` 常數池完整保留 JSON 鍵、URL、`Name@liboffset` 物件名、`package:app/...` 路徑；**執行個體欄位名不存活**（只在字串表以 JSON 鍵形式出現）→ 欄位目錄可建，但欄位→變數名對應不可建
- **物件名偏移聚類**：`Xxx@223116518` 同偏移物件 = 同 Dart 源檔案 → 可反推「哪些類在同一檔案」，用於定位通知模型/設定類
- **Kotlin 共享模組金礦**：桌布小工具/PhoneKey 用 Kotlin 重寫同一 wire format（`com.*.shared.entities.*` Gson + Retrofit），`@SerializedName` 註解完整可讀 → 第二獨立欄位來源
- jadx `-Xmx10g` 對 ~50MB XAPK 的 base APK 可用（exit 1 但主要類產出）；部分 defpackage 類仍缺
- reFlutter（PyPI `reflutter`）：僅適合有真機+Burp 的動態場景

## 关键代码/命令

```powershell
# XAPK 解包 + libapp.so 定位（zipfile 解壓，腳本見 tools/extract_strings.py 同目錄）
python tools/unpack_xapk.py target.xapk -d extracted
# base.apk 解 libapp.so 於 config.armeabi_v7a.apk/lib/...

# 字串表抽取（minlen=5, 去重複, 分類）
python tools/extract_strings.py libapp.so   # → strings/dotted_paths/snakecase/paths
jadx -Xmx10g --no-res base.apk -d jadx_out
```

```python
# 指令清單程式化生成（避免手抄）
cmds = sorted({s[len('command/'):] for s in strings if s.startswith('command/') and len(s) > 9})
```

## 对本包的改进建议
- apk-reverse skill 可增補「Flutter AOT 靜態字串表法」章節：字串表分類規則（點分路徑/snake_case/URL/command/物件名@偏移）+ 偏移聚類技巧 + 與 reFlutter 的適用邊界對照表
- 踩坑：pwsh 內嵌 python 引號問題應在 Windows 環境筆記中明確「一律寫 .py 檔」

## 可复用的模式/脚本片段
**Flutter AOT 純靜態 API 契約提取 SOP**：
1. XAPK → base APK（Kotlin）+ ABI split（libapp.so）
2. `libapp.so` → 字串表（minlen 5 起，短字串另用 membership 驗證）
3. 字串分類：`a.b.c` 點分路徑 = JSON 欄位樹；`/x/y` = 端點；`command/*` = 指令；`@NNN` 物件名偏移聚類 = 源檔案邊界
4. jadx base APK → 找 Kotlin 共享模組（Gson `@SerializedName` + Retrofit `@GET/@POST`）= 第二來源
5. 本地化字串（`strings.xml`/`messages_*`）= UI/觸發條件語意層
6. 逐欄位標雙源證據 [D]/[K]；演算法級結論一律降級中信心
7. 動態工具（reFlutter/Frida）僅在有真機+授權運行環境時啟用

## 进化动作
- [ ] 更新了子 skill 文档（apk-reverse：Flutter 靜態字串表法，建議合併）
- [x] 新增了 pitfalls 记录（本檔踩坑表）
- [x] 无需更新（路由/tool-index/bootstrap 本次均正常）

## 环境信息
- OS: Windows（PowerShell，sandbox workspace-write）
- 工具版本: jadx 1.5.6 (-Xmx10g)、apktool 2.9.0、Python 3.x、reflutter 0.9.8（僅評估）
- 目标平台/版本: Android XAPK，Flutter 3.x（Dart AOT, armeabi-v7a），targetSdk 36

## 脱敏要求
已執行：
- 目標 App 名/公司域名 → `{target_app}` / `{target_domain}`（tile API key、map token 等金鑰一律不寫入本檔，完整值僅存使用者案例目錄 `report/` §10）
- 完整端點清單/欄位表不貼入本檔（屬目標 API 契約細節，存使用者案例 `report/`）
- 無用戶名/電話/郵件；無內網 IP
- 提交前已對照 `anonymization.md` checklist 自掃

## 索引同步（提交前最后一步）
- 已新增「APK / Android 逆向」分節條目
- 已新增「Flutter AOT 靜態字串表提取」高頻成功模式分節
- 已新增「Flutter 車輛 API 伴生 App（XAPK + Kotlin 共享模組）」實體倒排
- 累計統計：真實 22→23，總 39→40，最近更新 2026-10-08

---
<!-- [进化统计] 本包累计完成项目: 23 | 本次新增模式: 1 (Flutter AOT 静态字符串表法) | 本次修复工具链问题: 0 -->
<!-- [社区贡献] 完成后询问用户是否 PR 到主仓库。流程见 CONTRIBUTE-BACK.md -->
