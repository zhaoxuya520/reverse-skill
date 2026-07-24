---
name: cloud-k8s
maturity: extended
description: Use for authorized cloud, container, and Kubernetes security assessment including metadata SSRF, IAM misconfig, container escape paths, and cluster RBAC review.
---

> **Maturity: `extended`** · usable playbook · see [`../references/skill-maturity.md`](../references/skill-maturity.md). Expect more manual tool work than **core** skills.

# Cloud / Container / Kubernetes Security

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: 读取 `../field-journal/precedent-pentest.md` — **云/K8s 测试必须书面授权**
2. `NOW`: case-init + scope；明确账号边界、禁止破坏性操作
3. `NOW`: 确认是云元数据/容器/K8s/IAM，而非普通 Web 扫（后者 `pentest-tools/`）
4. `NEXT`: tool-index；kubectl/aws/gcloud 等多为手动安装
5. `ACT`: 从「身份与暴露面」开始，禁止默认全网扫描

## 适用场景

- 云元数据 SSRF（169.254.169.254 / IMDS）
- IAM 过度权限、公开存储桶、错误安全组
- Docker/containerd 逃逸路径评估
- Kubernetes RBAC、Secrets、Admission、供应链镜像
- 容器镜像漏洞（可联动 `supply-chain-security/`）

## 工作流

### Phase 1 — 身份与边界

```text
□ 当前身份：云 AK/SK、K8s SA、节点 SSH？
□ 范围：单账号 / 单 cluster / 单 namespace
□ 网络档：authorized_target_only
```

### Phase 2 — 云控制面

```bash
# 示例（按厂商替换；MUST 在授权账号内）
aws sts get-caller-identity
aws s3 ls
# Azure / GCP 对应 identity 命令
```

```text
□ 公开桶 / 错误 ACL
□ 元数据：IMDSv1 vs v2；SSRF 链
□ 角色可扮演（PassRole）与横向
```

### Phase 3 — 容器

```text
□ 是否 privileged / hostPath / hostNetwork
□ capabilities（SYS_ADMIN 等）
□ 可写宿主机路径 → 逃逸候选
□ 镜像历史与已知 CVE → Trivy
```

### Phase 4 — Kubernetes

```bash
kubectl auth can-i --list
kubectl get pods,secrets,svc -A
kubectl get clusterrolebindings
```

```text
□ SA token 挂载与权限
□ 危险 admission webhook 缺失
□ etcd / dashboard 暴露
□ 网络策略是否默认放行
```

## 工具链

| 工具 | 用途 | 自举 |
|------|------|------|
| kubectl | 集群交互 | 手动 |
| trivy | 镜像/IaC | bootstrap `trivy` 若可用 |
| kube-bench / kubeaudit | CIS/配置 | 手动 |
| pacu / scoutsuite | 云审计（授权） | 手动 |
| nuclei | 已知云漏洞模板 | bootstrap nmap/nuclei 生态 |

## 参考

- `references/k8s-cloud-checklist.md`
- CTF 对照：`../../CTF-Sandbox-Orchestrator/competition-agent-cloud/`
- `../supply-chain-security/` `../pentest-tools/`

## 路由上下文

**上游**: MASTER R23  
**下游**: 拿到节点 shell → `attack-chain` / `windows-ad`；镜像漏洞 → supply-chain  
**MUST NOT**: 未授权扫公有云其他租户

## 任务完成自检

- [ ] 是否限定在授权账号/cluster？
- [ ] 发现是否含复现与影响？
- [ ] 是否避免破坏性操作？
- [ ] 报告 / journal？