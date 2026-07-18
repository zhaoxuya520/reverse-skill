# [日期] [项目简称]

## 场景分类
<!-- APK逆向 / JS签名 / 二进制分析 / 渗透测试 / CTF / 抓包分析 / 其他 -->

## 目标概述
<!-- 一句话说明在干什么 -->

## Scope 摘要（脱敏）
<!-- auth.basis / network_profile.mode / in_scope 类型（勿写真实域名/IP） -->
- auth_basis:
- network_profile:
- asset_types: []

## 角色
<!-- lead / cie / cpe / cre / … 见 skills/ops/role-map.md -->
- lead_role: lead
- specialists: []

## 完整执行链路
<!-- 从拿到目标到产出结果的完整步骤，包括走过的弯路 -->

1. ...
2. ...
3. ...

## Evidence 链摘要（脱敏）
<!-- 最多 3 条：E-id + 命令模式 + 结论类型；完整证据在用户项目 -->
| E-id | source_type | 可复用命令模式 | 关联 Finding |
|------|-------------|----------------|--------------|
| E-001 | | | F-001 |

## Finding / Path 摘要
- top_finding:
- path_type: attack | callflow | solve
- path_one_liner:

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| ... | ... | ... | ... |

## 工具链发现
<!-- 用到了哪些工具，哪些好用，哪些有坑，版本兼容性问题 -->

## 关键代码/命令

```
<!-- 贴实际用到的关键命令、hook 脚本、解密逻辑 -->
```

## 对本包的改进建议
<!-- 路由是否准确？bootstrap 是否缺失？文档是否需要补充？新工具是否需要加入 manifest？ -->

## 可复用的模式/脚本片段
<!-- 如果产出了可复用的 hook 脚本、解密逻辑、绕过方案，贴在这里 -->

## 进化动作
<!-- 本次回写后实际执行了哪些更新 -->
- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档
- [ ] 新增了 pitfalls 记录
- [ ] 无需更新

## 环境信息
<!-- 记录当时的关键环境 -->
- OS:
- 工具版本:
- 目标平台/版本:

## 脱敏要求

> **本文件可能随仓库同步到远程，必须脱敏。完整规范见 [`anonymization.md`](anonymization.md)（占位符总表 + 自动检测脚本）。**

- 目标域名/IP：用 `{target_domain}` / `{target_ip}` 替代（详见 `anonymization.md`）
- 真实 URL 路径：保留结构，替换域名
- Token/Cookie/密码/JWT/API key：用 `{token}` / `{password}` / `{api_key}` 占位
- 用户名/手机号/邮箱：用 `{username}` / `{phone}` / `{user_email}` 占位
- 内部 IP/端口：内网 IP 段保留前两段（`10.0.x.x`）
- 漏洞 payload：可保留技术内容，但替换目标特征参数（如 `?id={user_id}`）

提交前对照 `anonymization.md` 末尾的 **Field-Journal 必查项 checklist** 跑一遍正则扫描。

如果是私有仓库且确认不会公开，可以放宽以上限制，但仍建议脱敏。

## 索引同步（提交前最后一步）

写完本日志后，必须同步更新 `_index.md`：

1. 在「按场景分类」对应小节新增一行（含日期、关键词）
2. 在「高频成功模式（按技术）」对应技术下追加本文件名
3. 在「实体倒排（按目标特征）」对应实体下追加本文件名
4. 更新「累计统计」的总数与"最近更新"日期

---
<!-- [进化统计] 本包累计完成项目: N | 本次新增模式: X | 本次修复工具链问题: Y -->
<!-- [社区贡献] 完成后询问用户是否 PR 到主仓库。流程见 CONTRIBUTE-BACK.md -->
