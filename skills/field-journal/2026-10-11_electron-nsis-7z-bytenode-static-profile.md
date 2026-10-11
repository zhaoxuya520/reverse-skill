# 2026-10-11 Electron 厚客户端「NSIS + 7z + Bytenode」全链路静态画像

## 场景分类

厚客户端安全 / Electron / 安装器解包 / Bytenode / 信任边界与 Electron 安全基线

## 目标概述

对一个 Windows x64 Electron 桌面应用（商业闭源心智图软件）完成**纯静态**全链路画像：从 NSIS 安装器、内嵌 7z 载荷、Electron 运行时指纹、Bytenode 主进程、webpack 渲染层，到 Electron fuses / `@electron/remote` / Node 集成 / CSP / asar 完整性构成的信任边界评估。全程只读、未执行样本代码。

## 完整执行链路

1. 路由分诊命中 `R32 thick-client`（Electron 属桌面厚客户端），`case-init --preset offline-sample` 建立离线样本 scope。
2. 对安装器做 PE 侦察：32 位 stub、节区熵、overlay 起点与熵值、Authenticode 目录、VersionInfo、指示字符串（区分真信号与压缩数据里的统计噪声）。
3. 从 overlay 首字节识别 NSIS 签名块（`EF BE AD DE` + `NullsoftInst`），再用 7-Zip 以签名扫描方式在 overlay 内定位内嵌 7z 归档。
4. 只读展开 7z，得到平铺的 Electron 应用布局（`{app}.exe` + `resources/app.asar` + `*.dll` / `*.pak` / `locales`）。
5. 从主程序字符串提取运行时指纹：`Electron/22.3.1`、`Chrome/108.0.5359.215`、`node.js/v16.17.1`，以及版本资源里的 `SquirrelAwareVersion`。
6. 解析 `app.asar`：本样本头部为 **16 字节前导**（非标准 12 字节），改用「字节级括号配平定位 JSON 终点」的稳健解析法，得到 6,623 条目 / 201.9 MiB。
7. 识别 `main/main.js` 为 bytenode 标准加载器 + `main.bytecode`（V8 code cache，魔数 `0xC0DE05A9`），判定主进程保护方式与强度。
8. 从 `main.js.LICENSE.txt` 反推渲染层栈（Vue 2.7.14 / Pinia / Vuex / `@sentry/node`），并统计 61 个窗口 HTML 与 46 个对话框。
9. 对 `{app}.exe` 定位 Electron fuse 哨兵串，按 wire 格式（`[version][count][fuses...]`）解析 7 个 fuse 的开闭状态。
10. 交叉验证信任边界：渲染层 `require("fs"/"crypto"/"electron")`、`REMOTE_BROWSER_*` 通道、窗口 HTML 无 CSP、asar 头部 `integrity` 与 fuse 关闭的矛盾、`sign-in-preload.js` 的通配 `postMessage`。
11. 产出报告 + 2 张图 + 15 条 Evidence + 7 条 Finding + 2 条 Path，并通过 `review_case.py --verify-hashes --strict` 校验（PASS）。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|---|---|---|---|
| asar 解析首个版本失败（UTF-8 解码错误） | 本样本 asar 头部有 16 字节前导（标准为 12），按固定偏移取 jsonLen 取错 | 先找 `{"files"`，再用**字节级括号配平**扫描定位 JSON 终点，dataOffset 由 `json_start+json_len` 对齐推出 | 中 |
| 7-Zip 报 `-tnsis` 不支持 | 所用 7-Zip 为精简构建（无 7z.dll / NSIS 编解码器） | 不指定类型，让其按签名扫描；在 overlay 内直接命中 7z 归档，结构同样清晰 | 低 |
| 指示字符串出现大量假阳性 | 158 MiB 高熵压缩数据中 2~3 字节串会按概率随机出现 | 用**期望值估算**剔除噪声（如 `V8` 命中 2559 次 ≈ 1/65536 × 166M，判为噪声；`jsc` 11 次同理） | 低 |
| fuse 解析首次读错 | 误把 wire version 当 count | 正确格式为哨兵串后 `[wire version][fuse count][fuse bytes]`；本例 `01 07 31 30 31 31 30 30 30` = version 1 / count 7 | 低 |
| `case-init -Sample` 相对路径解析到当前工作目录 | 脚本以调用方 CWD 解析相对路径，而非 `-ProjectRoot` | 传绝对路径 | 低 |
| PowerShell 工具不回显 stdout | 宿主行为 | 脚本输出重定向到文件再读取 | 低 |
| `review_case.py --strict` 首轮 84 个 error | 脚本 schema 比 `ops/evidence-finding-path.md` 更严：Evidence 需 `severity`/`status`，Finding 字段需 `- key: value` 纯格式，`artifact_path` 须相对 case root 且存在 | 按脚本实际 schema 对齐（而非只按文档），二次运行 PASS | 中 |

## 工具链发现

- **asar 头部并非恒定布局**：遇到解析失败时应改用「定位 JSON 起点 + 括号配平」而非固定偏移，这是最稳的通用做法。
- **7-Zip 精简构建**（无 7z.dll）不能按类型打开 NSIS，但**按签名扫描**仍可定位内嵌 7z；安装器「NSIS stub + 7z 载荷」是常见组合。
- **Electron fuse 解析**只需哨兵串 `dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX` + `[version][count][fuses]`，无需反编译，是评估 Electron 加固水平最廉价的手段。
- **`main.js.LICENSE.txt`** 是 webpack 产出的许可证汇总，可**零成本反推渲染层依赖与版本**（Vue/Pinia/Vuex/Sentry），比在 minified chunk 里猜快得多。
- **高熵区域字符串需做统计去噪**：短模式（2~3 字节）在压缩数据中的命中次数接近 `2^-bits × filesize` 时，应判为噪声而非证据。
- 统计噪声与真信号的分界，直接决定报告的「误报率」——这是本次最值得固化的一条纪律。

## 关键代码/命令

```bash
# 安装器侦察（自研）
python recon_pe.py "{app}-for-Windows-x64bit-{version}.exe" recon/

# 只读解包（NSIS + 内嵌 7z）
7z l -slt  "{app}-...exe" > 7z_listing.txt
7z x -y -oextract "{app}-...exe"

# asar 解包（非标准头部，括号配平定位）
python asar_extract.py extract/resources/app.asar extract/resources/app_asar

# 字节码字符串（低阈值 4 才抓得到 ipcMain 等短标识符）
python strings.py extract/resources/app_asar/main/main.bytecode 4 > main_strings.txt

# Electron fuse 解析
python -c "d=open('{app}.exe','rb').read(); i=d.find(b'dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX'); print(d[i+32:i+48].hex())"

# 签名四态
powershell -c "Get-AuthenticodeSignature '<file>' | Format-List *"

# case 证据图校验（严格）
python skills/case-review/scripts/review_case.py work/<case> --verify-hashes --strict
```

## 对本包的改进建议

1. **`thick-client` skill 增补 Electron 专用子清单**：asar 头部非标准布局的处理、fuse 解析方法、`*.LICENSE.txt` 反推依赖、Node 集成/`@electron/remote`/CSP 的判定证据形态。
2. **`case-review` 文档与脚本 schema 对齐**：`ops/evidence-finding-path.md` 未要求 Evidence 的 `severity`/`status`，但 `review_case.py` 强制；建议在文档中补上这两个必填字段与「Finding 字段须为 `- key: value` 纯文本」的说明，减少首轮 84 个 error 的返工。
3. **`case-init` 相对路径语义**：`-Sample` 建议相对 `-ProjectRoot` 解析，或在文档中显式提示需绝对路径。
4. **新增「字符串统计去噪」通用规则**：建议写入 `reverse-engineering/` 或 `ops/analysis-blindspot-cookbook.md`，避免把压缩数据里的随机短串当证据。

## 可复用的模式/脚本片段

1. **asar 稳健解析**：定位 `{"files"` → 字节级括号配平（含字符串/转义状态机）→ `dataOffset = align4(json_start + json_len)`。
2. **fuse 三字节组解析**：`[version][count][fuse bytes]`，一次读到 Electron 加固全景。
3. **许可证文件反推依赖栈**：`*.LICENSE.txt` / `main.js.LICENSE.txt` 是 webpack 的免费情报源。
4. **字符串噪声门限**：短模式命中数 ≈ `2^(-8×len) × filesize` 时判为压缩噪声。
5. **信任边界四问**：Node 集成？remote 模块？CSP？fuse 是否加固？（四问即可定位 Electron 客户端的主要边界弱点）
6. **Evidence→Finding→Path 严格化**：Finding 保持 `candidate`（唯一证据/缺动态验证）而非强行 `validated`，是让 `--strict` 通过且结论诚实的正确姿势。

## 进化动作

- [x] 新增了 pitfalls 记录
- [x] 更新了经验索引
- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档

## 环境信息

- OS: Windows 11 x64
- 工具版本: 7-Zip 18.05（精简构建）、Python 3.13、pefile 2024.8.26
- 目标平台/版本: Windows x64 / Electron 22.3.1（Chromium 108 / Node 16.17.1）
- 分析模式: 纯静态（offline sample，未执行样本代码）

## 脱敏要求

本文仅保留通用版本号、结构特征、方法与数量级。样本名、厂商名、发布者、真实域名、案件目录、哈希、配置密钥与用户标识均已替换或省略；未附带样本文件。完整报告保留在用户本地 case 目录。
