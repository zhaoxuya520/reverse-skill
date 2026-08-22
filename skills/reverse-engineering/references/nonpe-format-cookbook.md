# 非 PE / 多格式 Agent 响应菜谱 U–AV（Issue #65）

> 与 PE 反调试菜谱 A–T（../anti-analysis.md）并列：按**文件类型**给出「触发 → 动作一行 → Evidence」。  
> **不是**第二套主流程。Triage 识别类型后跳转到对应 skill + 本表。  
> 默认 **授权隔离 lab / 已授权样本与设备**。格机、BYOVD、反射注入等写**检测与取证**，不写未授权破坏/利用教程。  
> 绕过或还原失败也 MUST 记 Evidence；禁止静默当「无害」。

## 0. 路由速查

| 类型线索 | 主 skill | 本表章节 |
|----------|----------|----------|
| .bat / .cmd / 批处理 | malware-analysis | §1 |
| .ps1 / PowerShell | malware-analysis | §2 |
| Office 宏 / VBA / .docm/.xlsm | malware-analysis | §3 |
| Web/前端 JS 混淆、JSVMP | js-reverse | §4 |
| .sys / 内核驱动 | reverse-engineering/kernel-driver-reverse.md + cre | §5 |
| .dll 侧重点 | malware-analysis / re-agent-workflow | §6（与 A–T 去重） |
| APK / Magisk / 隐藏图标 | apk-reverse | §7–§8 |

Triage 文件类型为脚本/宏/JS/APK/DLL/SYS 时：完成本类型 **P0 锚点 Evidence** 后再深挖；PE 反调试仍走 A–T。

## 1. BAT/CMD（U V W）

| ID | 触发 | 动作（摘要） | Evidence | 优先 |
|----|------|--------------|----------|------|
| **U** | 大量 SET 单字符变量 + %a%%b% 拼接，或 ^ 续行拆命令 | 逐行展开 SET；还原后命令列表；可用 batch 脱混淆工具；**禁止**未还原就当「无动作」 | E-batch-deobf | P0 |
| **V** | 文本打开乱码，HEX 头 FF FE（UTF-16 LE BOM） | 确认 BOM → 转 UTF-8 再解析；或 chcp 65001 + type | E-batch-encoding | P2 |
| **W** | 大量 REM/::、冗余 GOTO/标签淹没真实逻辑 | 去注释；梳 GOTO 真路径；隔离执行抓 cmd 实际命令日志 | E-batch-deadcode | P1 |

## 2. PowerShell（X Z）

> 编号保留提出者习惯：**无补丁 Y**。

| ID | 触发 | 动作（摘要） | Evidence | 优先 |
|----|------|--------------|----------|------|
| **X** | 多层 FromBase64String / Gzip / Compress / 嵌套 -replace | **逐层**解码；每层结果单独记；工具可选（PowerDecode 等），无工具则手工/脚本 | E-ps-decode-layer-N | P0 |
| **Z** | 字符串倒序、碎片 + 拼接后 Invoke-Expression/IEX | 还原完整串；对 IEX 下断或脚本块日志；明文命令入 Evidence | E-ps-string-restore | P1 |

## 3. VBA 宏（AA AB AC）

| ID | 触发 | 动作（摘要） | Evidence | 优先 |
|----|------|--------------|----------|------|
| **AA** | olevba/OLEDump 仅见 P-Code、源码流空（VBA Stomping） | P-Code 反编译工具；不全则 Word/Excel 宏调试观察；写清限制 | E-vba-pcode | P0 |
| **AB** | 大量 Chr() 拼接或 Base64 串，疑 shellcode/嵌套脚本 | 立即窗口/脚本还原串；解码后判类型；动态盯 CreateObject/Shell | E-vba-str-decode | P1 |
| **AC** | 无意义 If 1=2、或 InsertLines/DeleteLines 自修改 | 静跟真分支；动态 bp 自修改 API 并 dump 改后宏 | E-vba-selfmod | P2 |

## 4. JavaScript（AD AE AF）→ 主路径 js-reverse

| ID | 触发 | 动作（摘要） | Evidence | 优先 |
|----|------|--------------|----------|------|
| **AD** | 自定义字节码数组 + while/switch 解释器（JSVMP） | 找 VM 入口与 opcode 分发；动态日志轨迹；AST+动态双轨；见 js-reverse DeepDive | E-js-vmp | P0 |
| **AE** | while(1){switch} + 大字符串数组下标 | AST/Babel 重构；数组下标还原字符串；wakaru 等可选；**勿**整份粘贴 PE ollvm-deobfuscation 长文 | E-js-deobf | P0 |
| **AF** | debugger、劫持 console、performance.now 差、DevTools 检测 | 停用断点/固定时间源/无头浏览器；patch 检测点；授权页面 | E-js-anti-debug | P1 |

## 5. SYS 内核驱动（AG AH AI）

| ID | 触发 | 动作（摘要） | Evidence | 优先 |
|----|------|--------------|----------|------|
| **AG** | DriverEntry 很短，逻辑不在入口 | 扫 MajorFunction[] 非空槽；优先 IRP_MJ_DEVICE_CONTROL/CREATE；地址列表入证 | E-driver-irp-handlers | P0 |
| **AH** | 存在 DeviceIoControl / IOCTL 分发 | 建控制码→处理函数表；标 METHOD_* 与缓冲方向；用户态通信面 | E-driver-ioctl | P0 |
| **AI** | 样本加载/投放知名脆弱驱动或异常签名驱动（BYOVD 模式） | 对照 LOLDrivers 等**公开**列表；记驱动名/哈希/签名；分析**调用意图**；**不**展开 exploit 步骤 | E-driver-byovd | P1 |

详见 kernel-driver-reverse.md 流程；本表只补 agent 动作锚点。

## 6. DLL（AJ–AQ）— 与 A–T / #72 去重

| ID | 触发 | 动作（摘要） | Evidence | 优先 |
|----|------|--------------|----------|------|
| **AJ** | DLL 分析只看了导出/EP，忽略 TLS 或 DllMain | **TLS 回调 + DllMain 都必须看**；动态断点顺序仍遵循四级火箭（TLS→EP/DllMain→API→ExitProcess） | E-dll-tls-dllmain | P0 |
| **AK** | 导出名前良后恶、错名、或导出与行为不符 | 导出表与实际调用交叉；异常导出列表 | E-exports-anomaly | P0 |
| **AL** | 无导出或导出极少，仍被加载 | 从入口、字符串、xrefs、调用方定位；不要因「无导出」放弃 | E-dll-noexport | P0 |
| **AM** | 静态 IAT 缺 DLL、运行时才用 | **See A–T 补丁 R**（Delay-Load / E-delay-import），此处不双写长文 | E-delay-import | P0 指针 |
| **AN** | 需还原导出函数参数与调用约定 | 交叉引用 + 动态看寄存器/栈；标注 stdcall/fastcall 等 | E-dll-export-abi | P1 |
| **AO** | 疑 DLL 劫持/侧加载 | 查应用目录同名 DLL、搜索路径、KnownDLLs；合法程序+异常 DLL 组合 | E-dll-sideload | P1 |
| **AP** | 无文件映射/反射加载线索 | 内存特征、加载器行为、无路径模块；授权环境取证 | E-dll-reflective | P1 |
| **AQ** | 仅因导出名「不像恶意」降风险 | **禁止**只凭导出名判安全；结合段权限、入口、字符串、动态行为 | E-dll-export-priority | P1 |

DLL/SYS 硬门仍：E-imports + E-exports（见 re-agent-workflow）。

## 7. Android 格机 / 持久化（AR AS AT）→ apk-reverse

> **仅授权样本、镜像或测试设备。** 动作是检测、提取 IOC 与持久化路径，不是实施破坏。

| ID | 触发 | 动作（摘要） | Evidence | 优先 |
|----|------|--------------|----------|------|
| **AR** | Magisk 模块/脚本含删库、刷写、批量 rm 系统分区等**格机特征命令** | 特征命令表 + 模块路径；标高危破坏能力；不执行格机命令 | E-android-wiper-cmd | P0 |
| **AS** | 循环 curl|sh / 远程拉脚本、非常规 C2 URL | 提 URL；分析下载体是否含格机命令；记临时路径 | E-android-wiper-backdoor | P0 |
| **AT** | /data/adb/service.d、post-fs-data.d、可疑 /system/priv-app 等 | 列持久化脚本/APK；内容摘要入证 | E-android-persistence | P1 |

## 8. Android 透明/隐藏图标（AU AV）→ apk-reverse

| ID | 触发 | 动作（摘要） | Evidence | 优先 |
|----|------|--------------|----------|------|
| **AU** | LAUNCHER 图标全透明/空 label、Theme.NoDisplay、无 LAUNCHER category、组件 disabled | aapt dump badging + manifest；反编译查图标像素；异常项入证 | E-android-hidden-icon-manifest | P0 |
| **AV** | 已装但桌面无图标，后台流量/自启/高危权限/动态恢复图标 | pm list vs 桌面；dumpsys package；广播与 device_admin；行为入证 | E-android-hidden-icon-behavior | P1 |

## 9. 约束（全局）

1. **不平行主流程**：阶段门闩仍以 re-agent-workflow / 各 skill 为准。  
2. **Evidence 必记**：含失败、半还原、quality= 标注。  
3. **与 A–T 去重**：PE 反调试不重复；AM→R；AJ 补 DLL 视角不推翻 TLS 火箭。  
4. **工具缺失**：记 n/a + 手工等价，不假装已用商业套件。  
5. **授权**：破坏性/注入/驱动漏洞类只做防御分析与取证表述。

## 10. P0 最小勾选（类型命中时）

```text
□ bat/cmd → U（+ 需要时 V/W）
□ ps1 → X（+ Z）
□ vba → AA（+ AB/AC）
□ js 强混淆 → AD 或 AE（+ AF）
□ sys → AG + AH（+ AI 若疑 BYOVD）
□ dll → AJ + AK/AL；Delay-Load 走 R
□ apk 破坏/隐藏 → AR/AS 或 AU（+ AT/AV）
```
