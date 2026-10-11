# 2026-10-11 Electron 厚客户端「客户端厚壳 + 服务端可选增强」许可证授权模块静态逆向

## 场景分类

厚客户端安全 / Electron / 许可证授权模块逆向 / 客户端侧密码学验签 / 机器指纹与设备绑定 / 离线降级路径 / 脱敏审计

## 目标概述

对同一个商业闭源 Electron 桌面应用（Windows x64 心智图软件，与同日的「NSIS + 7z + Bytenode 静态画像」为同一目标、**第三阶段**）**研究其激活/授权机制**，产出**静态架构与安全评估**：许可证密钥格式与验签算法、激活数据流与状态机、机器指纹与设备绑定、本地持久化、客户端信任边界。全程只读、未执行样本代码、未对厂商服务发起任何请求、**未产出 keygen / 许可证伪造 / 签名伪造 / 激活绕过 / 设备标识伪造**。

> 与第二阶段的关系：认证面是「信任远程页面 + 客户端薄壳」，**授权面恰好相反——是「客户端厚壳 + 服务端可选增强」**。同一目标内两种截然相反的信任模型，是本条最值得复用的认知。

## Scope 摘要（脱敏）

- auth_basis: own_system（owner-operated local file，`preset=offline-sample`）
- network_profile: offline
- asset_types: [windows-x64-electron-installer, asar-bundle, v8-bytecode]

## 角色

- lead_role: lead
- specialists: []

## 完整执行链路

1. **先声明边界**：只做授权面的静态架构与安全评估；不产出绕过/伪造/keygen，不对厂商线上服务发起请求，不持有可用许可证样本。**公钥**（非秘密）可完整保留以便复现算法；**私钥**不持有、不尝试获取。
2. 主题化扫描授权代码面：写 `activation_sweep.py`，8 个主题正则（`license_endpoint` / `license_error_code` / `license_state` / `machine_fingerprint` / `crypto_verify` / `license_storage` / `feature_gate` / `license_ui_store`）**同时扫 asar JS 与 `main.bytecode` 的可打印字符串表**（双面扫描是关键，见踩坑 1）。
3. 扫描结果直接指向核心：`crypto_verify` 主题命中 `verifyLicense` / `createVerify` / `RSA-SHA256` / `-----BEGIN PUBLIC KEY-----` → **授权判定含客户端 RSA 签名校验**，不是纯服务端裁定。
4. 用 `webpack_mod.py` 抽出两个关键模块：`82647` = **许可证验签模块**；`87141` = **activation store**（状态机 + 本地判定 + 订阅解密）。
5. **解码混淆常量**：所有 RSA 公钥均由 `String.fromCharCode(...)` 构造 → 写小脚本批量解码。**这一步是拿到算法全貌的前提**（不解码就只剩 `MIGfMA0` 之类的 grep 零命中）。
6. 还原完整验签算法（见「可复用技术要点 1」）：225 字符固定长度、12 字符头部、205 字符 base32 = **1024-bit RSA 签名**、负载 = `key[0:20] + email.toLowerCase() + verifierSuffix`。
7. **用 DER 长度判位长，别靠猜**：`MIGfMA0…` 头部 0x9f=159 → RSA **1024**；`MIICIjAN…` 头部 0x0208=520 → RSA **4096**。同一个目标里两把不同位长的公钥**用途不同**，混淆会导致结论错位。
8. 读 `dialog-license.js` 的 `activate()` → **发现本阶段最高价值的结构性弱点**（见「可复用技术要点 2」）：服务端调用只在返回 **403/404** 时终止；**其余任何失败**（离线/超时/5xx/证书错误/代理拦截）都会落入「用用户输入的 key+email 本地构造 + 纯本地验签」的降级分支。
9. 分析 activation store 的三段式本地判定：黑名单精确匹配 → 头部解析 + 主版本门 → RSA-SHA256 验签；并**辨明 `E_MACHINE_ID_UNMATCHED` 的真实语义是「取不到设备信息」而非「指纹不匹配」**（因为指纹不进入签名负载）→ 机器绑定的唯一强制点在服务端 403。
10. 分析机器指纹模块（`main.bytecode` @0x001e60d2–0x001e6808 字符串簇）：`setDeviceName`（主机名去 `\.local$`）、机器 UUID → `setDeviceId`、**`FORCE_HARDWARE_FINGERPRINT`**（全大写常量，疑似环境变量覆盖开关）、`setHardwareFingerprint` + `sha256`。
11. 发现两个硬编码 GUID `03000200-0400-0500-0006-000700080009` / `00020003-0004-0005-0006-00070008000` → **查公开资料交叉核对**：前者是「多款主板出厂刷入的重复 SMBIOS UUID」（oshi issue #2417、QNAP FAQ 均有记载）→ 指纹唯一性前提对这类设备不成立。
12. **运行时只读审计**（复用 `state_audit.py`，强制脱敏）：`activation.json` 明文 JSON，字段 `mld`/`lbl`/`machineStatus`/`isDidRemindWillExpire`；`app.json` 的 `appDeviceId` 为 **26 字符 ULID 形态**且落盘，而 `hardwareFingerprint` **不落盘**（仅运行时）→ 辨明「设备身份双轨制」。
13. 分析另外三条授权路径：订阅（服务端私钥加密 blob → 客户端 `publicDecrypt` 用内嵌公钥解）、应用商店内购（**收据原样上报服务端核验，不本地验签**，属更稳健设计）、试用（状态由服务端驱动，本地只有 `EVALUATING`/`NONE` 两态、无计数器）。
14. **归因纪律**：本阶段涉及的授权符号经核对**只出现在 `main/main.bytecode`**，可安全归因于应用代码（与第二阶段必须排除 Electron 内置串的做法相反，此处的排除结论是「未命中 Electron 二进制」）。
15. 产出报告 + 12 条 Evidence + 11 条 Finding + 3 条 Path；`review_case.py --verify-hashes --strict` → PASS（0 error / 0 warning）。

## Evidence 链摘要（脱敏）

| E-id | severity | status | source_type | 可复用命令模式 | 关联 Finding |
|---|---|---|---|---|---|
| E-029 | info | observed | file | 8 主题正则扫 asar JS + bytecode 字符串表 | F-021 |
| E-030 | medium | observed | file | `webpack_mod.py` 抽 82647 + fromCharCode 解码 | F-021, F-025, F-028 |
| E-031 | medium | observed | file | bytecode 字符串簇 + PEM 位长判定 | F-021, F-028, F-029 |
| E-032 | info | observed | file | 头部解析函数逐字段还原 | F-027 |
| E-033 | medium | observed | file | 抽 87141 读 store 状态机与判定函数 | F-021, F-026, F-027 |
| E-034 | high | observed | file | `dialog-license.js` `activate()` 控制流 | F-020, F-024 |
| E-035 | medium | observed | file | `state_audit.py` 只读脱敏审计 | F-023, F-024, F-026 |
| E-036 | medium | observed | file | bytecode 指纹模块字符串簇 + 外部资料核对 | F-022, F-023 |
| E-037 | info | observed | file | 设备端点/字段/错误码提取 | none |
| E-038 | low | observed | file | 试用对话框 IPC 与端点提取 | F-030 |
| E-039 | info | observed | file | 内购/订阅端点契约提取 | none |
| E-040 | medium | observed | file | fromCharCode 解码第三把公钥 + publicDecrypt | F-021 |

## 可复用技术要点

### 1. 客户端许可证验签的「格式指纹」——一眼识别同类实现

同时出现下列特征时，基本可判定为**客户端离线验签型许可证**：

- 常量对 `(魔数, 固定总长, 头部长, 头部后额外字节数)`，例如 `("X", 225, 12, 8)`
- 归一化函数做「去 `---BEGIN/END LICENSE KEY---` 包裹 + 转大写 + 剔除非 `[A-Z0-9]`」
- 头部按固定偏移切字段并做 **base36 解码**（版本/年限）
- 尾部按 **base32 解码**（注意字母表：Crockford 变体剔除 `I/L/O/U`）
- 负载 = `key[头部+额外 : ] + email.toLowerCase() + verifierSuffix`，再用
  `crypto.createVerify("RSA-SHA256").verify(publicKey, sig)`
- **`verifierSuffix` 是硬编码在客户端的域分隔盐**：它不能用于伪造签名（伪造需私钥），
  故可安全记录；它的存在说明签发侧按「类型」做了域分隔
- **校验尾部长度能自证算法**：`(总长 - 头部 - 额外) × 5 / 8` 应等于公钥模长字节数
  （本例 205×5/8 = 128 = RSA-1024）

**副产品**：`publicDecrypt`（用公钥「解密」私钥加密的数据）不提供机密性，只提供
**完整性/来源绑定**——客户端无法伪造权益内容，但内容不是秘密。看到它别误判为「加密保护」。

### 2. 授权降级路径是最高价值检查点——「哪些错误码才被认真对待」

检查激活/授权函数时，**不要只看成功路径**，重点看 `catch` 分支对错误码的**白名单**：

```
catch(i){
  if (BLOCKLIST.includes(i.code)) return void(serverStatus = i.code);  // 只有这两个被认真对待
  payload = { key: userInput.key, email: userInput.email };            // 其余一切 → 本地构造
}
```

若「非预期错误」落入本地判定分支，则：授权判定在**离线场景下仍然成立**，
信任锚完全落在客户端密码学常量上，服务端退化为**可选增强**；
且该分支通常**不携带任何服务端字段**（因此机器绑定等语义一并丢失）。
→ 报告时务必区分**设计意图**（离线可用是产品需求）与**实现后果**（授权门退化为纯客户端检查、
降级条件是非预期错误而非显式离线探测）。

### 3. 「机器绑定」的强制点必须定位清楚，别被错误码名字骗

- 本地判定里出现 `E_MACHINE_ID_UNMATCHED` **不等于**「指纹与许可证不匹配」；
  本例的真实语义是「取不到设备信息」，判定条件仅为 `!hardwareFingerprint`（**非空检查**）。
- 真正的绑定判定在**服务端**返回的 `E_KEY_BIND_TO_ANOTHER_MACHINE(403)`。
- 验证方法：检查**指纹是否进入签名负载**。若不在负载里，本地就无从校验绑定。

### 4. 设备身份可能「双轨」：本地 ULID ≠ 硬件指纹

- `appDeviceId`（26 字符、Crockford base32、**落盘**）→ 服务端 `device_id`，本地生成
- `hardwareFingerprint`（sha256 摘要、**不落盘**、仅运行时）→ 另一个用途
- 判定技巧：拿 `state_audit` 的**键名清单**去比对——若某标识在落盘文件里**找不到**，
  说明它是可随时重算的派生量。

### 5. 硬编码 GUID 要查公开资料，别自行推测语义

本例两个 GUID 之一 `03000200-0400-0500-0006-000700080009` 是**多款主板出厂刷入的重复
SMBIOS UUID**（oshi issue #2417 明确称其为 *"a known default UID for several motherboards"*；
QNAP FAQ 亦以该值举例）。**不查资料会误判为「设备唯一标识」**。
查证后仍要区分：事实（该值被硬编码）为 observed；**用途**（黑名单规避 vs 兜底取值）
只能标 candidate —— 因为 V8 字节码不可反编译。

### 6. 多把内嵌公钥必须逐一分域，不能合并叙述

本例 4 把公钥分工：1024×2 = license key 验签（按 verifier 变体）、1024×1 = 订阅数据解密、
4096×1 = 主进程另一数据域。**判位长靠 DER 头部长度**，**判用途靠相邻字符串**
（`publicDecrypt` / `RSA_PKCS1_PADDING` / `verifyLicense`）。
把不同用途的公钥混为一谈会直接导致结论错位。

### 7. 双实现 = 漂移风险，值得单独成条

同一套算法在渲染层与主进程各存一份时，**逐项对照两侧的常量与函数名**：
若常量完全一致但一侧多出兜底日志（本例主进程多出 `Parse License Error:` 等），
说明两副本已开始分叉 → 可产出「UI 显示的授权态可能与主进程判定不一致」的 Finding。

### 8. 调试日志里的凭据面

验签函数常带 `License:` / `Email:` / `Public Key:` / `Signature:` / `Base:` 之类的全量日志点。
**这条在授权面同样成立**（不只在认证面），值得固定检查。

## 陷阱与纠正

1. **只看 asar JS 会漏掉整个授权面。** 授权逻辑主体在 `main.bytecode`（Bytenode）。
   扫描器必须**双面扫**（asar JS + bytecode 字符串表），否则会得到「命中文件数=1」的假象。
   本例修正后命中文件数=2（`main.bytecode` + `renderer/common.js`）——**命中数少不是覆盖不足，
   而是架构使然**（其余 61 个窗口 chunk 只消费 store 状态）。
2. **不解码 `String.fromCharCode` 就断言「公钥不存在」。**
   `grep "MIGfMA0"` 在 asar 内**零命中**，但公钥确实在——只是被逐码位构造。
   同理：`main.bytecode` 里唯一的 PEM 字面量是**另一把**（4096-bit），
   1024-bit 的两把在主进程同样被 fromCharCode 隐藏。
3. **别把「命中同名串」当成归因。** 第二阶段必须排除 Electron 内置串；
   本阶段反向核对（授权符号在 Electron 二进制中未命中）才能归因给应用代码。
   **两个方向都要做**，方向搞反会把 Electron 内部行为写成应用缺陷。
4. **`status: observed` 不在 case-review 的 Finding 允许集内。**
   `report/*.md` 里的 Finding `status` 只允许
   `candidate | validated | false_positive | accepted_risk | superseded`。
   写 `observed` 会直接报错。想在语义上表达「静态可确定的代码事实」，
   应写 `candidate` 并在 `residual_risk` 里说明证据同源、不满足「≥2 条独立证据」的 validated 门槛。
5. **`- 变体 A:` 这类 notes 子项会被字段解析器当成新字段而截断。**
   `review_case.py` 的 `field_value` 以 `^\s*-\s+([A-Za-z0-9_]+):` 作为块结束标志。
   在 `notes` / `raw_excerpt` 块里写 `- B: xxx` 会让后续内容被丢弃。
   规避：改成 `- 变体 B → xxx`（或任何不以「ASCII 词 + 半角冒号」开头的写法）。
6. **痕迹证据的载体要选对。** 引用 `notes/mods/*.decoded.txt`（解码后）比引用原始
   `*.js.txt` 更可读；但 `content_hash` 必须是对**被引用文件本身**的 SHA-256，
   否则 `--verify-hashes` 直接失败。改文件后必须重算哈希。

## 复用清单

- [ ] 主题化双面扫描器（asar JS + bytecode 字符串表），每主题限流 + 去重 + 噪声行排除
- [ ] `webpack_mod.py`：按模块 ID + 花括号配平抽取单模块（含引号/转义状态机）
- [ ] fromCharCode 批量解码小脚本（公钥/凭据通用）
- [ ] **DER 头部长度 → RSA 位长**对照（`MIGf`=1024 / `MIICIj`=4096）
- [ ] 授权函数检查清单：成功路径 + **catch 的错误码白名单** + 降级分支的判定输入边界
- [ ] 「指纹是否进入签名负载」→ 判定机器绑定在本地还是服务端
- [ ] 落盘键名清单 vs 运行时标识 → 识别「不落盘的派生量」
- [ ] 硬编码 GUID/UUID 的公开资料交叉核对（避免误判唯一性）
- [ ] `state_audit.py` 只读 + 强制脱敏（只出键名/类型/长度/哈希前缀）
- [ ] `review_case.py --strict --verify-hashes`；注意 Finding `status` 允许集与 notes 字段截断陷阱

## 边界与伦理（本条的可复用纪律）

1. **性质**：静态架构与安全评估；描述「判定发生在哪里、依据什么、在什么条件下降级」，
   **不**描述「如何使其通过」。
2. **未产出**：不包含、不指向、不暗示 keygen / 许可证伪造 / 签名伪造 / 激活绕过 /
   设备标识伪造，或任何用于规避授权的实现、伪代码、参数。
3. **未执行**：不对厂商线上服务发起请求；不执行样本代码；不做断网/重放/篡改对照实验；
   不持有、不使用任何可用许可证样本。
4. **密钥**：内嵌 **RSA 公钥**属公开信息，可完整保留以便复现算法；**私钥**不持有、不尝试获取。
   `verifierSuffix` 为客户端内嵌域分隔盐，**不能**用于伪造签名，故可保留。
5. **脱敏**：第三方凭据只登记存在性/格式/混淆手法/SHA-256 指纹；用户数据
   （`region` / `appDeviceId` / `rawSubscriptionData` 等）只登记键名/类型/长度/哈希前缀，
   **原值不出现在任何交付物中**。
