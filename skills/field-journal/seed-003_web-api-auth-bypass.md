# [种子] Web API 未授权访问 + IDOR

## 场景分类
渗透测试

## 目标概述
对某 Web 应用的 REST API 进行黑盒测试，发现未授权访问和 IDOR 漏洞。

## 完整执行链路

1. 信息收集：Nmap 扫描 → 发现 443 端口运行 Nginx + 后端 API
2. 目录发现：FFUF 爆破 → 发现 `/api/v1/` 路径
3. API 枚举：访问 `/api/v1/docs` → 发现 Swagger 文档暴露
4. 认证分析：注册两个测试账号 A 和 B
5. 测试 IDOR：用账号 A 的 token 访问账号 B 的资源 → 成功（水平越权）
6. 测试未授权：去掉 Authorization header → 部分接口仍返回数据（未授权访问）
7. 验证影响：确认可读取任意用户的个人信息（姓名、邮箱、手机号）
8. 证据收集：保存请求/响应截图，脱敏后整理报告

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| FFUF 被 WAF 拦截 | 请求频率太高触发限流 | 降低速率 `-rate 10`，加 `-H "User-Agent: Mozilla/5.0..."` | 10min |
| Swagger 文档 404 | 路径不是标准的 /swagger | 尝试 `/api/v1/docs`、`/api-docs`、`/openapi.json` | 5min |
| IDOR 测试不确定是否成功 | 返回的数据没有明显的用户标识 | 对比两个账号的响应，找到 user_id 字段差异 | 15min |
| 报告被 SRC 拒绝 | 只提交了截图没有完整复现步骤 | 补充 curl 命令 + 完整请求/响应 | 20min |

## 工具链发现

- FFUF 比 Gobuster 快，但需要控制速率避免被封
- Swagger/OpenAPI 文档暴露是最快的 API 枚举方式
- IDOR 测试必须用两个自己的账号互测，不要碰别人的数据
- SRC 报告必须有可复现的 curl 命令，不能只有截图

## 关键代码/命令

```bash
# 目录发现
ffuf -u https://target.example.com/api/v1/FUZZ -w /path/to/SecLists/Discovery/Web-Content/api/api-endpoints.txt -rate 10

# IDOR 测试
# 用账号 A 的 token 访问账号 B 的资源
curl -H "Authorization: Bearer <token_A>" https://target.example.com/api/v1/users/USER_B_ID

# 未授权测试
curl https://target.example.com/api/v1/users/USER_B_ID
# 如果返回 200 + 数据 → 未授权访问
```

## 对本包的改进建议

- pentest-tools 应该加入"API 渗透测试"的专项 checklist
- src-hunter 的 IDOR playbook 很好用，但缺少"如何判断 IDOR 影响范围"的指导

## 可复用的模式/脚本片段

**API 未授权测试三步法**：
```text
1. 正常请求（带 token）→ 记录正常响应
2. 去掉 token → 看是否仍返回数据（未授权）
3. 换另一个用户的 token → 看是否能访问（越权）
```

**IDOR 快速验证**：
```text
1. 注册两个账号 A 和 B
2. 获取 A 的资源 ID 和 B 的资源 ID
3. 用 A 的 token 请求 B 的资源 ID
4. 如果返回 B 的数据 → IDOR 确认
```

## 进化动作
- [ ] 无需更新路由矩阵
- [ ] 无需更新 bootstrap-manifest
- [ ] 无需更新子 skill 文档

## 环境信息
- OS: Windows（本机）→ 目标 Linux 服务器
- 工具版本: FFUF 2.x, curl, Burp Suite
- 目标平台: Web API (REST, JSON)

## 脱敏要求
本条目为种子数据，基于公开技术模式编写，不涉及真实目标。

---
<!-- [进化统计] 本包累计完成项目: 3 | 本次新增模式: 2 | 本次修复工具链问题: 0 -->
<!-- [社区贡献] 种子数据，无需 PR -->
