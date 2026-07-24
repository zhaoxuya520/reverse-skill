---
name: code-audit
maturity: experimental
description: Use for authorized source-code security review and SAST workflows including Semgrep, CodeQL patterns, dangerous API hunting, and fix verification.
---

> **Maturity: `experimental`** · scaffold playbook · see [`../references/skill-maturity.md`](../references/skill-maturity.md). Prefer deeper sibling skills when they overlap; extend `references/` before relying on this in production engagements.

# Source Code Security Audit

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: 读取 `../field-journal/precedent-pentest.md` 或代码审计授权
2. `NOW`: 确认有**源码/仓库访问**（无源码二进制 → 转 RE skill）
3. `NOW`: 明确语言栈与范围（目录/服务/PR diff）
4. `NEXT`: tool-index；semgrep 等
5. `ACT`: 威胁建模草图 → 自动扫描 → 人工验证

## 适用场景

- 白盒审计、PR/差分安全审查
- Semgrep / CodeQL / Bandit / gosec 等 SAST
- 危险 API、注入点、鉴权缺失、加密误用
- 与 `supply-chain-security/` 分工：本 skill 偏**自有代码逻辑**，供应链偏依赖与管道

## 工作流

### 1. 范围与威胁模型

```text
□ 信任边界：用户输入、文件、反序列化、SSRF、鉴权中间件
□ 高价值资产：鉴权、支付、管理端、密钥处理
```

### 2. 自动扫描

```bash
semgrep --config auto .
# 或项目规则包
semgrep --config p/owasp-top-ten .
```

### 3. 人工验证（MUST）

```text
□ 每个 SAST 命中：可达性？可利用性？误报？
□ 鉴权：IDOR/越权、缺校验、错误的多租户隔离
□ 注入：SQL/命令/模板/LDAP
□ 加密：硬编码密钥、ECB、自定义 crypto
```

### 4. 产出

```text
Finding：位置 + 数据流 + PoC + 修复建议
可选 ATT&CK / CWE 编号
```

## 工具链

| 工具 | 语言/场景 |
|------|-----------|
| Semgrep | 多语言快速规则 |
| CodeQL | 深数据流（GitHub） |
| Bandit | Python |
| gosec / staticcheck | Go |
| SpotBugs / FindSecBugs | Java |

## 参考

- `references/sast-review-checklist.md`
- `../supply-chain-security/` `../api-security/` `../llm-security/`（Agent 代码）

## 路由上下文

**上游**: MASTER R26  
**角色**: `ops/role-map.md` cae  
**下游**: 依赖漏洞 → supply-chain；运行时验证 → pentest-tools

## 任务完成自检

- [ ] 是否人工验证而非只贴扫描器输出？
- [ ] 是否含修复建议？
- [ ] 是否限定在授权仓库范围？
- [ ] Checklist？