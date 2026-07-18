# reverse-skill 身份宣言（相对 Z3r0）

> 本文件固定 **我们是谁**。吸收 Z3r0 的证据/范围/分工/时间线思想，但 **不** 做成 Z3r0 平台。

## 我们是

| 维度 | reverse-skill |
|------|----------------|
| 形态 | **Skill 路由包** — 给任意 AI 客户端（Claude/Cursor/Codex…）用的方法论 + 工具自举 |
| 入口 | `RULES.md` → `MASTER-ROUTING` / `master-route.ps1` → 子 skill |
| 工具真相 | `tool-index.md` + `bootstrap-manifest.json`（本机路径，不猜） |
| 进化 | `field-journal/` 脱敏经验回写 |
| 产物 | Markdown 报告 + `work/<case>/` 本地作战目录（gitignore） |
| 部署 | `git clone` 即可；无强制 PG/UI/Docker 池 |

## 我们不是

| Z3r0 有 | reverse-skill **故意不做** |
|---------|---------------------------|
| React 作战台 | ❌ |
| FastAPI 控制面 + WebSocket 会话 | ❌ |
| PostgreSQL 证据库 | ❌ |
| LightRAG 服务 | ❌ |
| Docker 主机池 / noVNC 控制代理 | ❌（可 **文档** 推荐可选沙箱 profile） |
| 多 Agent 进程运行时 | ❌（仅 **角色→skill 映射 + 交接协议**） |

## 我们从 Z3r0 学什么（缩水落地）

| 思想 | reverse-skill 形态 |
|------|-------------------|
| 授权与项目边界 | `ops/scope-contract.md` → 每案 `scope.md` |
| Evidence→Finding→Path | `ops/evidence-finding-path.md` + 报告模板 |
| 专家分工 | `ops/role-map.md`（Lead/cie/cpe/cre…→ skill） |
| 可回放 | `work/<case>/timeline.md` 追加写 |
| WorkItem/覆盖 | `workitems.md` + coverage 勾选 |
| 沙箱工具齐 | `ops/sandbox-profile.md` vs bootstrap-manifest |
| 出站管控 | `network_profile` 字段（offline/lab/authorized） |

## 特色（必须保留）

1. **三轴路由 + PRIMARY 快路径**（目标类型 / 意图 / 工具链）  
2. **bootstrap 按需装工具**，跨 Windows/Kali/Linux/macOS  
3. **MCP 友好**（IDA/Burp/jshook/anything-analyzer）  
4. **field-journal 脱敏进化**  
5. **服从性工程**：ACTION REQUIRED / 完成自检 / 禁止假停  

## 与 Z3r0 的健康关系

```text
Z3r0 = 红队操作系统 / 团队协作平台
reverse-skill = Agent 的安全作业路由器 + 说明书

可选未来：把本包 skill 内容挂进 Z3r0 sandbox-local skills
当前：零依赖 Z3r0 安装即可完整工作
```

## 与「800+ 社区微 skill」的关系

- **不** submodule 巨型 skill 库（投毒面与维护成本，见 `skill-supply-chain.md`）  
- **要** 维护 `references/community-security-skills.md` 作索引与借鉴规则  
- **要** 用 `domain-coverage-map.md` 证明：深度 skill + 路由 > 碎片 skill 堆叠  
- 外部 skill 安装：AST10 思维 + 只信 curated 源（如 Trail of Bits curated）  
