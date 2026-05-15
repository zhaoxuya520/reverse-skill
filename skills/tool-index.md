# 逆向工具索引

- 扫描时间: 2026-05-15 18:35:26 +08:00
- 路由入口: `SKILL.md` → `routing.md` → 对应子 skill
- 说明: 本表由 `scripts/refresh-tool-index.ps1` 自动生成，优先用于 Claude 路由和工具路径确认。
- 注意: 对于 jshookmcp 这类 MCP server，`yes` 只表示本机具备通过 node/npx 拉起它的条件，不表示它已经在 Claude MCP 配置里注册并启用。

| 工具 | 归属 skill | 作用 | 可用 | 路径 | 版本 | 来源 | 脚本引用 |
|---|---|---|---|---|---|---|---|
| jadx | apk-reverse | Java 反编译 | yes | C:\Users\24781\Tools\jadx\bin\jadx.bat | 1.5.5 | FallbackPath | apk-reverse/scripts/decode.ps1 |
| apktool | apk-reverse | APK 解包与重建 | yes | C:\Users\24781\Tools\apktool\apktool.bat | — | FallbackPath | apk-reverse/scripts/decode.ps1<br>apk-reverse/scripts/rebuild-sign-install.ps1 |
| adb | apk-reverse | 设备连接与 logcat | yes | C:\Users\24781\AppData\Local\Android\Sdk\platform-tools\adb.exe | Android Debug Bridge version 1.0.41 | FallbackPath | apk-reverse/scripts/rebuild-sign-install.ps1 |
| java | apk-reverse | 运行 jar 与 Java 工具链 | yes | C:\Program Files\Common Files\Oracle\Java\javapath\java.exe | — | Get-Command | apk-reverse/scripts/decode.ps1 |
| apksigner | apk-reverse | APK 签名 | no | — | — | Missing | apk-reverse/scripts/rebuild-sign-install.ps1 |
| zipalign | apk-reverse | APK 对齐 | no | — | — | Missing | apk-reverse/scripts/rebuild-sign-install.ps1 |
| frida | apk-reverse | Frida 动态注入 | yes | C:\Users\24781\AppData\Local\Programs\Python\Python313\Scripts\frida.exe | 17.9.1 | Get-Command | apk-reverse/scripts/frida-run.ps1 |
| frida-ps | apk-reverse | Frida 进程枚举 | yes | C:\Users\24781\AppData\Local\Programs\Python\Python313\Scripts\frida-ps.exe | 17.9.1 | Get-Command | apk-reverse/scripts/frida-run.ps1 |
| r2 | radare2 | radare2 主分析器 | no | — | — | Missing | radare2/scripts/recon.ps1 |
| rabin2 | radare2 | 二进制侦察 | no | — | — | Missing | radare2/scripts/recon.ps1 |
| rasm2 | radare2 | 汇编/反汇编 | no | — | — | Missing | radare2/SKILL.md |
| radiff2 | radare2 | 二进制差分 | no | — | — | Missing | radare2/SKILL.md |
| rahash2 | radare2 | 哈希与校验 | no | — | — | Missing | radare2/SKILL.md |
| rax2 | radare2 | 进制与位运算转换 | no | — | — | Missing | radare2/SKILL.md |
| python | reverse-engineering | 辅助脚本执行 | yes | C:\Users\24781\AppData\Local\Programs\Python\Python313\python.exe | Python 3.13.12 | Get-Command | apk-reverse/scripts/frida-run.ps1 |
| pip | reverse-engineering | Python 包管理 | yes | C:\Users\24781\AppData\Local\Programs\Python\Python313\Scripts\pip.exe | pip 26.0.1 from C:\Users\24781\AppData\Local\Programs\Python\Python313\Lib\site-packages\pip (python 3.13) | Get-Command | — |
| node | js-reverse | 运行 Node 侧 JS 复现与 MCP 客户端 | yes | C:\Program Files\nodejs\node.exe | v24.14.0 | Get-Command | js-reverse/SKILL.md |
| npx | js-reverse | 运行临时 npm 包与 MCP 入口 | yes | C:\Program Files\nodejs\npx.ps1 | 11.9.0 | Get-Command | js-reverse/SKILL.md |
| jshookmcp | js-reverse | 通过 npx 启动 @jshookmcp/jshook MCP（仍需先配置并启用 MCP server） | yes | C:\Program Files\nodejs\npx.ps1 | @jshookmcp/jshook@latest | Get-Command | js-reverse/SKILL.md |
| agent-browser | browser-automation | 浏览器自动化（Playwright）：打开页面、点击、填表、爬取、截图 | yes | C:\Users\24781\AppData\Roaming\npm\agent-browser.ps1 | agent-browser 0.27.0 | Get-Command | browser-automation/SKILL.md |
| analyzeHeadless | reverse-engineering | Ghidra 无头分析（免费 IDA 替代） | no | — | — | Missing | reverse-engineering/SKILL.md |
| playwright | browser-automation | Playwright 浏览器引擎 | yes | C:\Users\24781\AppData\Local\Programs\Python\Python313\Scripts\playwright.exe | Version 1.53.0 | Get-Command | browser-automation/SKILL.md<br>browser-automation/scripts/setup.ps1 |


---

## 能力状态视图 (Capability Status)

| 能力 | 工具可用 | MCP 已注册 | 服务在线 | 可自动安装 | 安装方式 |
|------|---------|-----------|---------|-----------|---------|
| jadx | ✓ | — | — | ✓ | github-release-zip |
| apktool | ✓ | — | — | ✓ | github-release-jar-wrapper |
| frida | ✓ | — | — | ✓ | pip-package |
| idalib-mcp | ✗ | — | — | ✓ | pip-package |
| jshookmcp | ✓ | ✓ | — | ✓ | npm-mcp |
| anything-analyzer | ✗ | ✓ | — | ✓ | local-http-mcp |
| idapro | ✗ | ✓ | — | ✓ | local-http-mcp |
| r2 | ✗ | — | — | ✓ | github-release-zip |
| adb | ✓ | — | — | ✓ | winget-package |
| agent-browser | ✓ | — | — | ✓ | npm-global |

> ✓ = 是 | ✗ = 否 | — = 不适用或未检测

