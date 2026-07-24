---
name: ida-reverse
maturity: core
description: |
  IDA Pro 逆向分析辅助技能。当用户提到逆向、反编译、分析二进制/PE/ELF/APK/DLL/SO、破解、找密码、漏洞分析、病毒分析、firmware 固件分析，或需要分析 exe/dll/so/elf/macho/sys 等文件时，务必使用此技能。

  Ensure to use this skill when the user wants to analyze any binary file, regardless of whether they explicitly mention "IDA" or "reverse engineering". This includes requests like "看看这个exe", "分析这个dll", "帮我破解", "找一下密码", "这个软件怎么注册", etc.

  Use the bundled scripts (scripts/start.ps1, scripts/open.ps1) for deterministic server management and file opening — do NOT write ad-hoc PowerShell commands for these operations.
---

> **Maturity: `core`** · production-depth entry · see [`../references/skill-maturity.md`](../references/skill-maturity.md).

# IDA Pro 逆向分析技能

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: 读取 `../field-journal/precedent-reverse.md` — 确认本 skill 的操作是已授权的常规操作
2. `NOW`: 确认当前任务是否命中本 skill 的适用范围
3. `NEXT`: 读取 `../tool-index.md`，校验工具可用性和实际路径
4. `NEXT`: 缺工具时调用 bootstrap，不要猜路径
5. `ACT`: 进入"工作流"第一步并执行，不要停在确认状态

## 已知问题与反思（必读）

### 踩过的坑

1. **`idalib_open` 不能通过 部分代码 AI 客户端 MCP 直接调用**
   - 部分代码 AI 客户端 的 MCP 客户端对 `idalib_open` 的 output schema 校验有 BUG
   - 报错：`Structured content does not match the tool's output schema`
   - **解决办法**：使用 `scripts/open.ps1` 脚本通过 HTTP API 直调，绕过 MCP 校验层
   - 文件打开后，数据库绑定到共享上下文，其他所有 `idapro_*` 工具可直接使用

2. **`C:\Windows\System32\` 文件无权限打开**
   - idalib 无法直接读取 System32 目录下的文件
   - **解决办法**：`open.ps1` 自动检测并复制到 `临时目录` 目录后再打开

3. **启动服务器命令阻塞对话**
   - `idalib-mcp` 启动后会持续输出 INFO 日志到控制台
   - **解决办法**：使用 `scripts/start.ps1`（`-WindowStyle Hidden` 后台静默启动）
   - 脚本会等待服务就绪后自动退出，不阻塞对话

4. **MCP 服务器名不能用横线**
   - 之前用 `ida-pro-mcp` 作为服务器名，可能引起工具注册问题
   - **当前配置**：服务器名 `idapro`，工具前缀 `idapro_*`

5. **Remote HTTP vs Local Stdio**
   - `type:"local"`（stdio）模式：`idalib_open` 同样有 schema 校验问题
   - `type:"remote"`（HTTP）模式：可以先用脚本直开文件，再用 MCP 工具
   - **当前方案**：Remote HTTP 模式

6. **PR #389 修复了部分 schema 问题**
   - 作者 mrexodia 在 issue #388 后通过 PR #389 合并了修复
   - 修复了 HTTP 模式下的 structuredContent schema，但 部分代码 AI 客户端 侧校验仍有问题
   - 已安装最新 `main` 分支版本

7. **idalib 超时留下孤儿 worker 进程锁文件**
   - 第一次 `open.ps1` 超时后，idalib 的 python worker 子进程变成孤儿进程，咬着 `.id0`/`.id1`/`.nam` 不放
   - 后续任何工具或手动拖入 IDA GUI 都会报"权限不足"
   - **解决办法**：`start.ps1` 改用 `taskkill /F /T` 杀进程树，不再留孤儿
   - **兜底**：`open.ps1` 加了自动降级，检测到旧库被锁自动复制到 Temp 并加 GUID 前缀

8. **带自动分析打开看起来像卡死**
   - `idalib_open(run_auto_analysis=true)` 可能长时间不回包，但后端实际上仍在继续打开和分析
   - 之前用户侧看到的是“PowerShell 一直无输出”，容易误判成脚本卡死
   - **当前解决办法**：`open.ps1` 新增 `-TimeoutSeconds`，并改为后台请求 + 前台轮询 + 定时进度输出
   - 轮询到会话已就绪时会提前返回 `OK:文件名:session_id`，超时则返回 `ERR:open_timeout_xxs`

### 工作流程原则

| 步骤 | 做什么 | 用什么 |
|------|--------|--------|
| 1 | 确保 HTTP 服务器在运行 | `scripts/start.ps1`（无参数） |
| 2 | 打开目标二进制文件 | `scripts/open.ps1 -Path "xxx.exe"` |
| 3 | 使用所有 72 个 MCP 工具 | 直接调用 `idapro_*` 工具 |
| 4 | 分析完毕 | 工具自动可用 |

## 脚本资源

### start.ps1 — 启动 MCP HTTP 服务器

路径：`scripts/start.ps1`

- 用 `taskkill /F /T` 杀旧进程树（连 worker 子进程一起清理）→ 后台启动 `idalib-mcp` → 等待就绪（最多 15 秒）
- 成功输出 `OK:72`，失败输出 `ERR:timeout`
- 服务器在后台运行，不阻塞对话

**调用方式**：
```
powershell -File "<skill-root>\ida-reverse\scripts\start.ps1"
```

### open.ps1 — 打开二进制文件

路径：`scripts/open.ps1`

- 通过 HTTP API 直调 `idalib_open`，绕过 MCP schema 校验
- 自动检测 System32 路径并复制到临时目录
- 自动清理同名旧数据库文件（`.id0`/`.id1`/`.nam`/`.til`/`.i64`）
- 旧库被锁时自动降级：复制到 Temp 加 GUID 前缀后打开，不报错
- 将打开请求放到后台执行，避免长时间同步等待导致脚本无响应
- 支持 `-TimeoutSeconds`，超时后返回 `ERR:open_timeout_xxs`，不会无限卡住
- 每隔 10 秒输出一次 `INFO:opening:已用时/超时秒数`，便于判断仍在分析中
- 成功输出 `OK:文件名:session_id`，降级时加 `(temp copy)` 标记
- 失败时自动重试走 Temp 副本

**调用方式**：
```
powershell -File "<skill-root>\ida-reverse\scripts\open.ps1" -Path "C:\path\to\file.exe"
```

**可选参数**：
```
# 指定 SessionId
powershell -File "scripts\open.ps1" -Path "file.exe" -SessionId "my_session"

# 跳过自动分析（大文件推荐）
powershell -File "scripts\open.ps1" -Path "large.exe" -NoAutoAnalysis

# 设置超时，避免带自动分析时长时间无返回
powershell -File "scripts\open.ps1" -Path "file.exe" -TimeoutSeconds 600
```

**输出约定**：
```
# 分析进行中（每 10 秒输出一次）
INFO:opening:11/600s

# 成功打开
OK:sample.exe:abcd1234

# 成功打开，但因锁文件降级到 Temp 副本
OK:1234abcd-sample.exe:abcd1234 (temp copy)

# 达到超时上限
ERR:open_timeout_600s
```

**实测说明**：
- `Snipaste.exe` 带自动分析实测约 `324s` 才返回成功，属于“分析很久”而不是“脚本死锁”
- 因此遇到 GUI 程序或较复杂样本时，建议优先显式设置 `-TimeoutSeconds 600`

## 核心工具列表

### 概况分析（第一步）
- `idapro_survey_binary(detail_level="minimal")` — 快速概况：函数数、字符串、段、入口点、导入分类（加密/网络/文件IO）
- `idapro_list_funcs(queries)` — 列出函数（分页、按名称过滤）
- `idapro_list_globals(queries)` — 列出全局变量
- `idapro_entity_query(kind, filter)` — 统一查询：functions/globals/imports/strings/names

### 反编译与反汇编
- `idapro_decompile(addr)` — 反编译为伪代码
- `idapro_disasm(addr, max_instructions=N)` — 反汇编
- `idapro_analyze_function(addr, include_asm=false)` — 综合分析（伪代码+字符串+常量+调用者+被调用者+块）
- `idapro_func_profile(queries)` — 函数概要指标

### 交叉引用与数据流
- `idapro_xrefs_to(addrs)` — 查谁引用目标地址
- `idapro_xref_query(addr, direction)` — 高级 xref 查询（方向/类型过滤）
- `idapro_callees(addrs)` — 子函数列表
- `idapro_callgraph(roots, max_depth)` — 调用图
- `idapro_trace_data_flow(addr, direction, max_depth)` — 数据流追踪（forward/backward）

### 搜索
- `idapro_find_regex(pattern, limit)` — 正则搜字符串
- `idapro_search_text(pattern)` — 在反汇编列表中搜文本
- `idapro_find_bytes(patterns, limit)` — 字节模式搜索（支持 ?? 通配符）
- `idapro_find(type, targets)` — 高级搜索（立即数/字符串/引用）

### 内存与数据
- `idapro_get_bytes(addrs)` — 读原始字节
- `idapro_get_string(addrs)` — 读字符串
- `idapro_get_int(queries)` — 读整数值
- `idapro_get_global_value(queries)` — 读全局变量值
- `idapro_read_struct(queries)` — 读结构体字段值
- `idapro_search_structs(filter)` — 搜索结构体

### 修改操作
- `idapro_set_comments(items)` — 添加注释（反汇编+反编译双向同步）
- `idapro_append_comments(items)` — 追加注释
- `idapro_rename(batch)` — 批量重命名（函数/全局/局部/栈变量）
- `idapro_patch_asm(items)` — Patch 汇编指令
- `idapro_patch(patches)` — Patch 字节
- `idapro_define_func(items)` — 定义函数
- `idapro_undefine(items)` — 取消定义
- `idapro_define_code(items)` — 将字节转为代码

### 类型系统
- `idapro_declare_type(decls)` — 声明 C 结构体/枚举/联合体
- `idapro_set_type(edits)` — 应用类型到函数/全局/局部
- `idapro_infer_types(addrs)` — 推断类型
- `idapro_type_query(queries)` — 查询已声明类型
- `idapro_type_inspect(queries)` — 查看类型详情

### 栈帧
- `idapro_stack_frame(addrs)` — 查看栈帧变量
- `idapro_declare_stack(items)` — 声明栈变量
- `idapro_delete_stack(items)` — 删除栈变量

### 签名
- `idapro_make_signature(addrs)` — 为地址生成唯一字节签名
- `idapro_make_signature_for_function(addrs)` — 为函数生成签名
- `idapro_find_xref_signatures(addrs)` — 为引用地址的代码生成签名

### 调试器（需要 ?ext=dbg）
- `idapro_open_file(file_path)` — 在 GUI IDA 实例中打开文件
- 调试器工具默认隐藏，可通过 URL 参数 `?ext=dbg` 启用

### 会话管理
- `idapro_idalib_open(input_path)` — ⚠️ 有 schema 校验 BUG，改用 `open.ps1` 脚本
- `idapro_idalib_list()` — 列出所有 session
- `idapro_idalib_current()` — 当前上下文绑定的 session
- `idapro_idalib_switch(session_id)` — 切换到其他 session
- `idapro_idalib_close(session_id)` — 关闭 session
- `idapro_idalib_save(path)` — 保存数据库
- `idapro_idalib_health(session_id)` — 检查 worker 健康状态

### 其他
- `idapro_int_convert(inputs)` — 进制转换（**必须用这个，不要自己算进制！**）
- `idapro_export_funcs(addrs, format)` — 导出函数（json/c_header/prototypes）
- `idapro_py_eval(code)` — 在 IDA 上下文执行 Python
- `idapro_server_health()` — 服务器健康检查
- `idapro_server_warmup()` — 预热子系统（字符串缓存、Hex-Rays 等）

## 逆向分析完整工作流

### Step 1: 启动服务器
确保 HTTP 服务在后台运行。
```
powershell -File "scripts/start.ps1"
```
输出 `OK:72` 表示就绪。

### Step 2: 打开文件
```
powershell -File "scripts/open.ps1" -Path "C:\目标.exe" -TimeoutSeconds 600
```
输出 `OK:文件名:session_id` 表示成功（后带 `(temp copy)` 表示自动降级到临时副本）。
若分析时间较长，会周期性输出 `INFO:opening:...`；若达到超时则输出 `ERR:open_timeout_xxs`。

### Step 3: 全局概览
```
idapro_survey_binary(detail_level="minimal")
```
关注：
- 架构（x86/x64/ARM）
- 入口点（main/WinMain/DllMain）
- 有趣的字符串（URL、路径、错误消息）
- 导入分类（加密函数？网络 API？文件操作？）
- 热门函数（高 xref 计数的函数通常是关键逻辑）

### Step 4: 深入关键函数
```
idapro_analyze_function(addr="关键函数名")
```
或：
```
idapro_decompile(addr="函数名")
idapro_disasm(addr="函数名", max_instructions=50)
```

### Step 5: 数据流和交叉引用
```
idapro_xrefs_to(addrs="关键地址/字符串")
idapro_callgraph(roots=["关键函数"], max_depth=3)
idapro_trace_data_flow(addr="关键地址", direction="backward", max_depth=5)
```

### Step 6: 记录和优化
```
idapro_set_comments(items=[{"addr": "0x140001000", "comment": "你的理解"}])
idapro_rename(batch={"func": [{"addr": "函数地址", "name": "有意义的名字"}]})
```

### Step 7: 输出报告
分析完成后，生成 `report.md` 记录发现和步骤。

## Prompt 工程准则

1. **不要手动算进制** — 任何时候需要转换数字，用 `idapro_int_convert`
2. **先 survey 后深入** — 先看概况再针对性分析
3. **持续加注释和重命名** — 分析过程中不断更新函数名和变量名，提升后续分析的准确性
4. **跟踪交叉引用** — 发现有趣的数据/字符串，用 `xrefs_to` 看谁引用了它
5. **遇到混淆代码** — 先做字符串解密、导入哈希去除、控制流平坦化去除等预处理
6. **C++ STL 代码** — 用 FLIRT/Lumina 识别库函数后，再分析业务逻辑
7. **不要暴力破解** — 分析应从反汇编中推导解决方案，用简单 Python 辅助计算
8. **遇到 "No database bound"** — 还没有打开任何二进制文件，先执行 `open.ps1`
9. **遇到 "Failed to open database"** — 可能是旧数据库文件被锁，`open.ps1` 会自动降级到 Temp 副本（输出含 `(temp copy)` 标记）
10. **带自动分析打开 GUI/复杂样本时** — 默认加 `-TimeoutSeconds 600`，不要把长时间 `INFO:opening:...` 误判成脚本卡死

---

## 路由上下文

**上游入口**: `skills/SKILL.md`（总控）、`routing.md`
**上游备选**: `radare2/`（如果不想开 IDA，可以先 r2 快速侦察）
**下游出口**:
- 需 Frida 动态验证 → `reverse-engineering/tools-dynamic.md`
- 需符号执行/angr → `reverse-engineering/tools-dynamic.md`
- 需通用逆向方法论 → `reverse-engineering/SKILL.md`

**同级关联模块**: `radare2/`（IDA 不可用时替代方案）

---

## 按需自举（On-Demand Bootstrap）

本 skill 的入口脚本已接入统一自举系统。

### 自动化能力边界

| 工具 | 可自动安装 | 安装方式 | 说明 |
|------|-----------|---------|------|
| idalib-mcp | ✓ | pip install (from GitHub) | `start.ps1` 缺失时自动安装 |
| IDA Pro 本体 | ✗ | 商业软件，需手动安装 | 设置 `IDADIR` 环境变量指向安装目录 |

### 安装步骤（已验证）

```cmd
# 1. 设置 IDA 路径（替换为你的实际 IDA 安装目录）
setx IDADIR "<你的IDA安装目录>"

# 2. 从 GitHub 安装 ida-pro-mcp（PyPI 上的 ida-mcp 是另一个项目，不要装错！）
pip install git+https://github.com/mrexodia/ida-pro-mcp.git

# 3. 安装 IDA 插件（选择 Streamable HTTP + Global + 全选客户端）
ida-pro-mcp --install

# 4. 重启 IDA Pro，打开目标文件
# 插件自动监听 127.0.0.1:13337

# 5. 验证
ida-pro-mcp --config
```

> ⚠️ **注意**：PyPI 上的 `ida-mcp` 包（作者 jtsylve）是另一个项目，不是我们需要的。
> 必须从 GitHub 安装 `mrexodia/ida-pro-mcp`。

### 自举触发点

- `scripts/start.ps1`：缺 `idalib-mcp` 时自动调用 `bootstrap-reverse.ps1`
- MCP 注册：bootstrap 会自动把 `idapro` 写入 Claude MCP 配置

### 前置条件

- IDA Pro 已安装且 `IDADIR` 环境变量已设置（或脚本内默认路径正确）
- Python 已安装（idalib-mcp 依赖 Python）


## 任务完成自检（声称完成前 MUST 通过）

- [ ] 我是否执行了工作流中的每一步（而不是只阅读）？
- [ ] 我是否基于 `tool-index` 使用了真实工具路径？
- [ ] 我是否产出了可复现证据（命令/脚本/截图/报告）？
- [ ] 我是否完成并回写了 RULES 要求的 Checklist 项？
