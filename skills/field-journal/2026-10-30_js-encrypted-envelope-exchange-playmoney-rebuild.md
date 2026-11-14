# 公开交易所 + 真人桌游站点的被动侦察与"后台全量实时可控"的玩币版重建

> 日期：2026-10-30
>
> 场景：Web / JS 逆向（R3 js-reverse）+ 实时协议分析 + 本地重建（多 agent swarm）
>
> 脱敏：目标域名、品牌、账号、token、加密密钥均以占位符或类别描述；不含任何原始抓包。

## 场景分类

JS 签名/加密信封 + 抓包分析 + 本地重建

## 目标概述

仅做公开被动观察，提取一个体育交易所（match odds / bookmaker / fancy）加真人卡牌桌（dt20 / teen20 / lucky7 等）站点的信息架构、
API 形状与实时节奏，然后用自有品牌、虚拟筹码（不涉及真钱）重建：Next.js 玩家端 + Next.js 管理后台 + Spring Boot Modulith 后端。
要求后台可实时控制前台全部内容与后端投注逻辑。

## Scope 摘要（脱敏）

- auth_basis: public_passive_observation（无站方授权，主动测试排除）
- network_profile: 公开页面只读浏览 + 公开 demo 登录；独立 Chrome profile 经 CDP 记录
- asset_types: [web, frontend_js, encrypted_api_envelope, websocket_score_feed, screenshot]

## 角色

- lead_role: lead（coordinator）
- specialists: [cie（bundle/realtime 分析）, cre（产品/赔率数学）, ui-analyst, 多个实现 worker]

## 完整执行链路

1. master-route 选 R3；case-init 时写明 `public_passive_observation` 与 out_of_scope（不扫描、不爆破、不碰支付）；case-guard 通过后才开始抓取。
2. 独立 Chrome profile + CDP（端口隔离）录制：先登出态首页过 CF，再 22 条静态路由、体育列表、5 个赛事、11 张牌桌；单次长任务用 detached 脚本规避 10 分钟工具超时。
3. 所有接口响应是 AES 信封；密钥藏在混淆前导代码中。写离线 decoder（不对线上发任何额外请求）批量解码已录流量。
4. 由解码后的样本统计实时节奏：赔率约 500 ms 轮询、牌桌约 700 ms 轮询、比分走独立 socket（revision/baseRevision 增量）。据此设计 STOMP 推送 + 每 topic seq + Redis 重放缓冲 + REST 快照兜底。
5. 证据 E-001..E-009 做 SHA-256 + review_case `--verify-hashes --strict` 通过（Gate G1）；匿名化副本落项目 Docs。
6. 规范先行：backend-contract（模块表 + 迁移号段 + 构建隔离）、realtime（信封/重放/鉴权）、casino（可证明公平算法 + 跨语言测试向量）、domain-model、PRD，再分发给 worker。
7. 多 worker 并行实现（identity/wallet/cms/realtime/admin/sportsbook/casino + 两个前端），协调者逐个独立复验（隔离 build 目录、Testcontainers、真实 HTTP + 真实 JWT）后按模块提交。
8. Phase 7：2,000 个 STOMP 订阅者扇出压测；安全自审 S-01..S-08b 全部修复并配回归测试；Playwright e2e 覆盖"后台操作 -> 前台无刷新生效"；按 recon 的 must-match 规则做可度量的视觉一致性检查。

## Evidence 链摘要（脱敏）

| E-id | severity | status | source_type | 可复用命令模式 | 关联 Finding |
|------|----------|--------|-------------|----------------|--------------|
| E-003 | n/a | observed | network | `node recorder.mjs --cdp 9333 --out runs/r03 --routes routes.txt`（CDP 被动录制） | F-001 |
| E-006 | n/a | validated | file | `node decode.mjs runs/r03/*.json --key-from preamble.js > decoded.ndjson`（离线解信封） | F-002 |
| E-008 | n/a | observed | runtime_visual | `node crawl.mjs --tables tables.txt --shots 1440,390`（UI 基线 + tokens 取样） | F-004 |

## Finding / Path 摘要

- top_finding: 站点"实时"实为高频轮询加 AES 信封；重建侧改为推送（STOMP + seq + 重放），延迟从轮询周期级降到亚秒级，并可后台直接控制。
- path_type: callflow
- path_one_liner: 后台操作 -> 模块服务（同事务写审计）-> after-commit 发布 -> Redis seq/缓冲/扇出 -> STOMP -> 前端按 seq 合并，缺口走 REST 重放或快照。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| worker 长时间不落盘、会话中断后上下文丢失 | 大任务一次性构思；会话被暂停或中断 | 要求"按切片落盘"（迁移 -> 领域 -> 控制器 -> 测试）；中断后起新 worker 并明确"在已有文件上完成和验证，不要重写" | ~1 h 累计 |
| JWT 里 `adm`（=能进后台）被当成"平台管理员"，导致代理层越权读全平台数据 | 一个布尔同时承载"受众"和"数据范围"两层语义 | 拆成 `console()`（受众）与 `globalScope()/canReach()/scopePath()`（范围）；先写"旧代码必失败"的 HTTP 回归测试再修 | ~40 min |
| 前后端字段名不一致（marketId/selectionId/limits/delaySec vs id/minStake/betDelaySec） | UI 先按规范猜字段，后端按自身领域命名 | 在共享 SDK 放唯一的 wire normalizer，两个前端都经过它；单测用真实后端样本 | ~25 min |
| 并行构建互相覆盖 target/ | 多 worker 同时 mvn | 用环境变量为每个 worker 指定独立构建目录（如 `{build_dir_env}=target-<name>`） | ~15 min |
| 玩家登录/接受规则把乐观锁版本号 +1，导致紧随其后的后台锁定偶发 409 | 用实体保存做"簿记"更新 | 簿记字段改为原生定向 UPDATE，不动 version；加回归测试 | ~15 min |
| Next 保留上一路由的隐藏 DOM，e2e 选择器命中两个元素 | 客户端路由缓存 | 断言限定 `:visible`；桌面/移动重复组件用不同 test id | ~10 min |

## 工具链发现

- CDP 直连已登录的独立 profile，比无头新实例更容易通过 CF，也不污染日常浏览器。
- Node 22 自带 WebSocket：一个无依赖的 STOMP 1.2 framer 就能做 2,000 连接压测，p99 182 ms，0 丢失。
- Spring Modulith 的 ModularityTests 能有效挡住跨模块直连；共享内核放端口接口（FeatureFlags、ApprovalGateway、RealtimePublisher）。
- 可证明公平：HMAC-SHA256 字节流 + 拒绝采样（无模偏）+ 逆向 Fisher-Yates。Java 与浏览器端 TS 用同一测试向量逐卡对齐，e2e 在浏览器内复算 hash 与发牌。

## 关键代码/命令

```
# 证据完整性
python skills/case-review/scripts/review_case.py {case_root} --verify-hashes --strict
# 隔离构建 + 指定测试
{build_dir_env}=target-<name> ./mvnw -q -Dtest='ModularityTests,<Module>IntegrationTest' test
# 全量门禁（含 e2e）
scripts/verify.sh --e2e
# 扇出压测
node tools/load/ws-load.mjs --url ws://{remote_host}:{port}/ws --topic /topic/site-config --clients 2000 --trigger ./publish.sh
```

## 对本包的改进建议

- R3 路由可增加"加密 API 信封"子分支：优先在前导代码里定位密钥并离线解码，避免对目标做额外请求。
- case-init 模板可加入"重建型任务"的 out_of_scope 默认值（不复制品牌/素材/文案、不接真钱支付）。
- 多 agent 场景建议在 role-map 中加入"coordinator 必须独立复验 worker 产出"的硬性步骤（隔离构建目录 + 真实 HTTP 测试）。

## 可复用的模式/脚本片段

- "受众 vs 范围"分离：`console()` 只决定能否进后台；数据查询一律走 `globalScope()/canReach()/scopePath()`。
- 实时推送三件套：每 topic 单调 seq + Redis 有界缓冲（200 条 / 10 min）+ 缺口重放或 `{reset:true}` 触发 REST 快照。
- after-commit 发布：回滚的变更永远不会被广播；审计写入使用 `Propagation.MANDATORY` 与业务同事务。

## 进化动作

- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档
- [x] 新增了 pitfalls 记录（本条目）
- [ ] 无需更新

## 环境信息

- OS: macOS（colima 4 CPU / 6 GB）
- 工具版本: Node 22、JDK 21、Spring Boot 4.1、Next.js 16、Postgres 17、Redis 7、Playwright（系统 Chrome）
- 目标平台/版本: 公开 Web（Angular 前端 + 加密 JSON API + 比分 socket），抓取日期 2026-10-29

---
<!-- [进化统计] 本次新增模式: 3 | 本次修复工具链问题: 0 -->
<!-- [社区贡献] 已征得用户同意，按 CONTRIBUTE-BACK.md 提交 PR -->
