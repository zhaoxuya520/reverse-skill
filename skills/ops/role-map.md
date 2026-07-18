# 专家角色 → Skill 映射（无多 Agent 服务器）

> 角色代号灵感来自 Z3r0 专家队；**实现方式**是 reverse-skill 路由与交接协议，不是进程编排。

## 角色表

| Code | 名称（可本地化） | 职责 | PRIMARY / 工具 skill |
|------|------------------|------|----------------------|
| **lead** | Lead / 总指挥 | 拆任务、定 scope、阶段门控、汇总报告 | `attack-chain/` 或当前 PRIMARY hub；结束 → `docs-generator/` |
| **cie** | 情报收集 | 资产发现、暴露面、关系 | `pentest-tools/`（recon）；浏览器 → `browser-automation/`；云面 → `cloud-k8s/` |
| **cpe** | 渗透验证 | 扫描、利用验证、影响确认 | `pentest-tools/`；API → `api-security/`；AD → `windows-ad/`；无线 → `wifi-wireless/`；库 → `database-security/`；SSO → `identity-federation/`；OT → `ot-ics/` |
| **cre** | 逆向分析 | 二进制/固件/移动/前端逻辑 | `ida-reverse/` `ghidra-reverse/` `radare2/` `apk-reverse/` `mobile-reverse/` `macos-reverse/` `js-reverse/` `browser-extension-reverse/` `dotnet-reverse/` `go-rust-reverse/` `firmware-pentest/` `hardware-security/` `malware-analysis/` `protocol-reverse/` `thick-client/` `reverse-engineering/` |
| **cae** | 代码审计 | 源码/依赖/供应链 | `code-audit/` + `supply-chain-security/` |
| **cbe** | 蓝队/取证 | 狩猎、检测、IR 伪影 | `threat-hunting/` `digital-forensics/` |
| **cce** | 密码学 | 算法/协议/密钥误用 | 通用密码：`reverse-engineering` 模式文档；链上/独立包不进核心 |
| **llm** | AI 安全 | Prompt/Agent | `llm-security/` |
| **doc** | 文档官 | 报告/writeup/图 | `docs-generator/` + `diagram-generator/` |

## Lead 强制协议

```text
1. 输出 PRIMARY（master-route）+ lead_role=lead
2. 写 scope.md（ops/scope-contract）
3. 指定 specialist_roles[] 与 handoff 条件
4. 每阶段结束：更新 timeline + workitems；决定继续/换角色/出报告
5. 禁止跳过 scope 直接 cpe 扫生产
```

## 交接（Handoff）规则

| 从 → 到 | 触发 | 交付物 |
|---------|------|--------|
| lead → cie | 需要资产面 | scope + 已知域名/IP |
| cie → cpe | 有存活面/服务 | assets 列表 + 端口/URL |
| cpe → cre | 需逆向校验/客户端逻辑 | 样本路径 + 可疑点 |
| cre → cpe | 还原出协议/密钥/校验 | 算法说明 + 复现命令 |
| any → doc | 阶段或任务完成 | Evidence/Finding/Path 草稿 |
| any → lead | 阻塞/越权/换路径 | timeline 备注 + blocked 原因 |

## 单人 Agent 怎么用（特色）

不必真起 6 个 Agent：

```text
同一会话内：
  [lead] 规划
  [cie] 执行侦察 skill
  [cpe] 切换 pentest-tools
  …
输出时用角色前缀标签，方便 timeline 检索：
  [cpe] nuclei high findings → E-003
```

## 与 master-route 关系

- `master-route` 定 **PRIMARY skill**  
- `role-map` 定 **谁在当前阶段负责**（可写在 scope.md）  
- 多阶段任务 PRIMARY 常为 `attack-chain/`，由 lead 再分发  

## MUST NOT

- 不要假设存在 Z3r0 会话 API  
- 不要为角色启动未授权目标的额外扫描  
