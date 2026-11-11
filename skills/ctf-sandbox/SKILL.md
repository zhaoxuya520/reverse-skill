---
name: ctf-sandbox
description: Use as the PRIMARY entry for CTF, attack-and-defense, and sandbox challenge orchestration when a more specific pwn, APK, or IDA route does not take precedence. Delegate to CTF-Sandbox-Orchestrator.
---

# CTF sandbox entry (sidecar, not a second router)

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: 跑 `../scripts/case-init.ps1`；`auth.status=granted` 前禁止对真实外网 ACT。竞赛/靶场用 `-NetworkProfile lab` 或 `offline`。
2. `NOW`: 打开包根下的 `../../CTF-Sandbox-Orchestrator/ctf-sandbox-orchestrator/SKILL.md`，按它的 sandbox 假设继续。
3. `MUST NOT` 把 40+ 个 `competition-*` 子技能写进 `routing.json`。本入口只是一条 PRIMARY 门闩。
4. `ACT`: 由 orchestrator 选一个 downstream `competition-*`。具体题型已明确时（pwn/ROP、APK、IDA）应已由 `routing.json` 更靠前的规则赢下，不要再抢。

## 为什么单独一层

`CTF-Sandbox-Orchestrator/` 是 **GPL 旁路包**，授权默认是沙箱内部。核心路由包仍是 MIT + `scope.md` 门禁。本 skill 只做关键词入口，不把竞赛树并进核心。

## 任务完成自检（声称完成前 MUST 通过）

- [ ] 我是否先走了 case-init / scope，而不是把“用户说了 CTF”当成已授权外网？
- [ ] 我是否打开了 sidecar orchestrator，而不是把 40 个子技能当 PRIMARY？
- [ ] 若任务其实是 pwn/APK/IDA，我是否让更具体的 PRIMARY 接手？
