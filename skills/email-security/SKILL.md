---
name: email-security
maturity: experimental
description: Use for authorized email security review including phishing analysis, header authentication (SPF/DKIM/DMARC), BEC patterns, and mailbox token abuse research.
---

> **Maturity: `experimental`** · scaffold playbook · see [`../references/skill-maturity.md`](../references/skill-maturity.md). Prefer deeper sibling skills when they overlap; extend `references/` before relying on this in production engagements.

# Email Security & Phishing Analysis

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: 确认授权（分析样本邮件 / 租户配置评审）
2. `NOW`: 不向真实用户二次投递恶意样本
3. `ACT`: 头认证 → 内容/URL → 附件沙箱 → 租户控制面建议

## 适用场景

- 钓鱼邮件拆解与 IOC
- SPF/DKIM/DMARC 配置评估
- BEC 商务邮件欺诈模式
- OAuth 应用钓鱼 / 邮箱令牌滥用（联合 llm/cloud 身份）
- 安全意识演练设计（授权）

## 工作流

```text
□ 完整原始头：Received 链、From/Return-Path 一致性
□ SPF/DKIM/DMARC 对齐结果
□ URL 沙箱与附件静态（联合 malware-analysis）
□ 仿冒品牌与回复地址差异
□ 租户：反钓鱼策略、外部标记、MFA、OAuth app 同意
```

## 工具链

| 工具 | 用途 |
|------|------|
| 邮件客户端「查看源」 | 头 |
| dig/nslookup | SPF/DMARC 记录 |
| urlscan / 沙箱 | 链接与附件 |
| 租户管理中心 | 策略 |

## 参考

- `references/email-auth-checklist.md`
- `../malware-analysis/` `../attack-chain/`（钓鱼阶段） `../windows-ad/`（令牌）

## 路由上下文

**上游**: MASTER R36  
**MUST NOT**: 未授权对第三方域群发测试钓鱼

## 任务完成自检

- [ ] 头认证结论是否完整？
- [ ] IOC 是否可检测化（联合 threat-hunting）？
- [ ] Checklist？