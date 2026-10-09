# 2026-10-08 Flutter AOT 靜態字串表法 SOP（libapp.so 常數池 + liboffset 聚類重建類結構/狀態機/數據通道）

## 场景分类
APK 逆向 / 二進位分析（方法論 SOP 條目：可重用流程，不綁定特定目標；實例見 `2026-10-08_apk-flutter-static-telemetry-notification-re.md`）

## 目标概述
對 Flutter 3.x（Dart AOT）App 做純靜態分析：由 `libapp.so` 常數池重建 API 契約（欄位/端點/指令）與功能內部結構（物件模型、狀態機、數據取得通道），全程無動態 dump。

## Scope 摘要（脱敏）
- auth_basis: 使用者本地自有檔案（offline-sample），未連線、未執行、未抓包
- network_profile: offline
- asset_types: [android_xapk, flutter_aot_libapp.so, kotlin_shared_module, android_strings_xml]

## 角色
- lead_role: lead
- specialists: []

## 完整执行链路

1. XAPK 解包 → base APK（Flutter 殼 + Kotlin 共享模組）+ ABI split（`libapp.so`）+ 語言 split
2. `libapp.so` 字串表抽取：Python 腳本，minlen=5、去重複；2–4 字元短字串改 membership 驗證（抽取器會過濾）
3. 字串五分類：`a.b.c` 點分路徑（JSON 欄位樹）、`/x/y` URL 路徑（端點）、`command/*`（指令）、`Name@NNN`（Dart 物件名）、`package:app/...`（源檔案路徑）；另注意 camelCase（本地化 key / 模型 getter 詞彙）
4. **liboffset 聚類**：`Xxx@222279931` 的偏移是「每個物件」的 lib 偏移，**同一源檔案的物件共享同一偏移** → grep 單個偏移即可列舉該檔案全部物件（實例：一個螢幕 State 檔案 17 個方法、一個主頁檔案 70+ tile 物件）
5. 物件名規則解讀：`get:xxx`/`set:xxx` = 模型 getter/setter（camelCase 名 = API 欄位詞彙）；`_xxx@NNN` = 私有方法（檔案級）；`Xxx.`（型名 + 句點）= 除錯表示 → 類/列舉存在性證據
6. 本地化字串交叉：`values/strings.xml`（en）+ `values-xx/strings.xml` 的 key（camelCase）↔ Dart `get:key` getter ↔ UI 狀態字串 → 語義層與狀態機
7. 功能內部重建：物件模型（類名 + getter 集合）、狀態機（狀態字串 ↔ 列舉類映射，標中信心）、數據取得通道（REST 端點 + WSS 端點 + 車端/設備端配置）
8. 雙源交叉驗證：Dart 字串表 × Kotlin 共享模組（Gson `@SerializedName` + Retrofit，桌布小工具常重寫同一 wire format）→ 欄位逐條標 [D]/[K]/[D+K]
9. 信心分級：類名/欄位名/端點/本地化 key = 高；狀態映射/流程順序/協議用途 = 中；枚舉值/訊息格式/取樣率/公式 = 低（一律明示）

## 关键规则（踩坑后硬規則）

- **字串常數存活、執行個體欄位名不存活**：常數池保留 JSON 鍵/URL/物件名/型名；Dart 執行個體欄位名只在 JSON 鍵形式出現 → 欄位目錄可建，欄位→變數名對應不可建
- **字串表是 byte-sorted**：行號相鄰 ≠ 語義相關，**永遠只用 pattern + 物件名規則，不用行鄰接推斷語義**
- **liboffset 是物件級、不是類級**：類級 `@offset` 註解思路 0 命中；改「同偏移 = 同檔案」聚類
- **短字串（2–4 字元）被 minlen 過濾**：`^alert$` 之類 grep 0 命中是假象，用 Python membership 測試原始字串表
- **Windows CRLF**：`^word$` 錨定 grep 可能 0 命中，改無錨 pattern
- **動態工具邊界**：reFlutter/Frida 僅在有真機 + 授權運行環境時啟用；offline 範圍直接走靜態法（本案 Flutter 3.x 字串表無混淆，完全可行）

## Evidence 链摘要（脱敏）

| E-id | severity | status | source_type | 可复用命令模式 | 关联 Finding |
|------|----------|--------|-------------|----------------|--------------|
| E-001 | info | validated | command | `python tools/extract_strings.py libapp.so`（minlen=5 + 五分類） | F-001 |
| E-002 | info | validated | command | `grep "Name@NNN" strings.txt`（liboffset 聚類列舉同檔案物件） | F-002 |
| E-003 | info | validated | command | `grep "get:xxx\|XxxStatus\." strings.txt`（getter/型名除錯表示） | F-001 |

> 離線 case：repro_command 均為本地檔案操作，notes 標 offline 豁免。

## Finding / Path 摘要
- top_finding: Flutter AOT App 以「字串表 + Kotlin 共享模組」雙源可純靜態重建 API 契約與功能內部結構（物件模型/狀態機/數據通道）；上限：列舉值、WSS 訊息格式、取樣率與公式無直接證據 → 標低信心
- path_type: solve
- path_one_liner: 字串表五分類 → liboffset 聚類 → 物件名規則解讀 → 本地化交叉 → 雙源驗證 → 物件模型/狀態機/取得通道重建

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| 類級 `@offset` 正規表示例 0 命中 | 偏移是每物件獨立的 lib 偏移 | 改偏移**聚類**（同偏移 = 同檔案） | 0.5h |
| `^word$` grep 0 命中 | CRLF 錨定 + 抽取 minlen 過濾短字串 | 無錨 pattern + membership 驗證 | 0.1h |
| pwsh 內嵌 python 單行 SyntaxError | Windows 引號轉義 | 一律寫 `tools/*.py` 檔案再執行 | 0.1h |
| 誤把行鄰接當語義相關 | 字串表 byte-sorted | 只用 pattern + 物件名規則 | — |
| 手抄長清單重複/錯字 | 目視 111k 行字串表 | 程式化生成（set + sorted） | 0.3h |

## 工具链发现
- Python 字串抽取 + 五分類腳本（minlen=5；點分/snake/URL/command/物件名）— 本案 111,030 唯一字串
- jadx `-Xmx10g`：~50MB XAPK 的 base APK 可用（exit 1 但主要類產出）；defpackage 缺類 → Dart 字串表補證
- apktool 取 `values/strings.xml` 與語言 split；部分 resources 解碼失敗可接受（jadx resources 足夠）
- reFlutter（`reflutter`）：純動態 dump 工具，與 offline 範圍不相容，棄用

## 关键代码/命令

```
# 字串表抽取（minlen=5、去重複、五分類）
python tools/extract_strings.py libapp.so

# liboffset 聚類：列舉同一 Dart 源檔案的全部物件
grep "Name@NNN" strings.txt

# 物件名規則：模型 getter / 型名除錯表示（列舉、類存在性）
grep "get:xxx" strings.txt
grep "XxxStatus\." strings.txt

# 本地化交叉：en key 與各語言
grep 'name="xxx"' values/strings.xml

# 長清單程式化生成（避免手抄）
python tools/gen_list.py   # set + sorted 輸出
```

## 对本包的改进建议
- apk-reverse skill 增補「Flutter AOT 靜態字串表法」章節：五分類規則 + liboffset 聚類 + 物件名規則 + 與 reFlutter 適用邊界對照表
- Windows 環境筆記明確「pwsh 內嵌 python 一律寫 .py 檔」

## 可复用的模式/脚本片段

**Flutter AOT 純靜態 API 契約 + 功能內部結構提取 SOP（8 步）**：
1. XAPK → base APK（Kotlin）+ ABI split（libapp.so）
2. libapp.so → 字串表（minlen=5；短字串另用 membership 驗證）
3. 字串五分類：點分路徑=JSON 欄位樹 / URL=端點 / `command/*`=指令 / `Name@NNN`=物件名 / `package:app/...`=源檔案
4. liboffset 聚類（同偏移=同檔案）+ 物件名規則（`get:`/`_x@NNN`/`Xxx.`）→ 源檔案級結構
5. jadx base APK → Kotlin 共享模組（Gson + Retrofit）= 第二獨立欄位來源
6. 本地化字串（`strings.xml`/`messages_*`）= UI/觸發/狀態語義層
7. 重建：物件模型、狀態機（中信心）、數據取得通道（REST/WSS/設備端）
8. 逐欄位 [D]/[K]/[D+K] 標記 + 信心分級；動態工具僅在有真機+授權時啟用

## 进化动作
- [ ] 更新了子 skill 文档（apk-reverse：Flutter 靜態字串表法，建議合併）
- [x] 新增了 pitfalls 记录（本檔踩坑表）
- [x] 无需更新（路由/tool-index/bootstrap 本次均正常）

## 环境信息
- OS: Windows（PowerShell 7，sandbox）
- 工具版本: jadx 1.5.6、apktool 2.9.0、Python 3.x、git 2.54
- 目标平台/版本: Android XAPK，Flutter 3.x（Dart AOT，armeabi-v7a）

## 脱敏要求
已執行：
- 目標 App 名/公司域名 → `{target_app}` / `{target_domain}`；端點清單、欄位表、WSS 地址一律不貼入（屬目標 API 契約細節，存使用者案例 `report/`）
- 無 Token/Cookie/PII/內網 IP；無可執行代碼（僅命令模式）
- 提交前對照 `anonymization.md` checklist 自掃

## 索引同步（提交前最后一步）
- 「APK / Android 逆向」分節新增本條目
- 「Flutter AOT 靜態字串表提取（無動態 dump）」高頻成功模式分節追加
- 「Flutter AOT App（libapp.so 常數池）」實體倒排追加
- 累計統計：真實 +1，總 +1

---
<!-- [进化统计] 本包累计完成项目: 24 | 本次新增模式: 1 (Flutter AOT 静态字符串表法 SOP) | 本次修复工具链问题: 0 -->
<!-- [社区贡献] 完成后询问用户是否 PR 到主仓库。流程见 CONTRIBUTE-BACK.md -->
