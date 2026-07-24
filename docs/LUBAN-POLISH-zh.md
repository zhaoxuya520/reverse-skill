# reverse-skill 打磨说明（中文）

> 对应 PR：[#23 polish: PRIMARY bash parity, honest install channel, showcase GIF](https://github.com/zhaoxuya520/reverse-skill/pull/23)  
> 定位一句话：**授权逆向/渗透的 Skill 路由器——先 PRIMARY，再 scope，再碰目标。**

## 这份 PR 在干什么

不是再堆一批微 skill，而是把现有「路由器包」打磨成：

1. **一眼能看懂**（README 首屏 GIF + 路由图）
2. **一分钟能装上**（`npx skills add` + skills.sh 徽章 + Claude marketplace）
3. **三分钟能跑出可见结果**（`demo-primary-path.sh` 真产物）
4. **敢信任**（工具/成熟度诚实标注 + 授权门闩 + 写前确认）

## 主要改动

### 1. PRIMARY 路径 bash 对等（Linux / macOS / Kali）

| 脚本 | 作用 |
|------|------|
| `skills/scripts/master-route.sh` | 一句话 → PRIMARY skill |
| `skills/scripts/case-init.sh` | 落地 case + `scope.md`；preset：`offline-sample` / `ctf-public` / `own-system` |
| `skills/scripts/case-guard.sh` | 未就绪禁止 ACT |
| `skills/scripts/verify-routing-coherence.sh` | 路由一致性校验 |
| `skills/scripts/smoke.sh` | 一键回归 |

兼容 **macOS 自带 bash 3.2**（不用关联数组）。

### 2. 诚实层

- **tool-index**：java stub / 命令损坏如实标 `available=no`；jshookmcp 仅在 MCP 已注册时才算可用
- **skill maturity**：`core` / `extended` / `experimental`（见 `skills/references/skill-maturity.md`）
- **Global Injection**：RULES / README_AI 写前必须确认（confirm-before-write）

### 3. Showcase（可复现，不是摆拍）

```bash
bash skills/scripts/demo-primary-path.sh
bash skills/scripts/record-primary-path-demo.sh   # 重生成 GIF
```

产物：

- `examples/primary-path-demo/`（RESULT-CARD、route-matrix、case 样本）
- `docs/assets/primary-path-demo.gif`
- `docs/demo/primary-path.tape`（vhs 备用）

> `fixtures/sample.apk` 只是 **占位路径**，不是真实应用，demo 不会对它做真反编译。

### 4. 安装双通道

```bash
# Agent skill 一行安装
npx skills add zhaoxuya520/reverse-skill

# 只列不装
npx skills add zhaoxuya520/reverse-skill -l
```

Claude Code marketplace：

```text
/plugin marketplace add zhaoxuya520/reverse-skill
```

清单：`.claude-plugin/marketplace.json`（**路由器单入口**，不是「800 个微 skill」）。

**诚实边界**：`npx skills add` 装的是 Agent skill 文件；完整工具链（bootstrap、tool-index 刷新、Kali 辅助、本地 `work/`）仍以 **git clone** 为准。

### 5. README 中文结构修复

`README_zh.md` 关于区：流程图 code fence 先闭合，再接「30 秒实证」，与英文结构对齐。

## 怎么验收

```bash
bash skills/scripts/smoke.sh
# 期望：SMOKE PASSED
# 覆盖：路由矩阵 R1/R3/R14、case-init/guard、demo、GIF、marketplace、README 安装段、README_zh 结构
```

合入后建议再验：

```bash
npx skills add zhaoxuya520/reverse-skill -l
# GitHub 页面上看徽章 / GIF / 相对链接是否正常渲染
```

## 给维护者的合并建议

1. 先看 `README.md` / `README_zh.md` 安装节与 30 秒 GIF
2. 本机跑一遍 `bash skills/scripts/smoke.sh`
3. 合并后更新 skills.sh 展示（徽章会随安装累积）
4. 本 PR **不含** release/tag；发版请另开动作

## 明确没做的事

- 未删 experimental skill（只做诚实标注）
- 未扩 skill 数量充数
- 未做「可授权真实 APK」静态摘要 demo（需样本授权后再开）
- 未在本 PR 内 merge/发版

## 相关文件速查

| 路径 | 说明 |
|------|------|
| `skills/MASTER-ROUTING.md` | PRIMARY 快路径 |
| `skills/ops/` | scope / 证据链 / 角色 / 时间线 |
| `skills/references/skill-maturity.md` | 成熟度定义 |
| `.claude-plugin/marketplace.json` | Claude marketplace |
| `CHANGELOG.md` → `[Unreleased]` | 英文变更摘要 |
| `examples/primary-path-demo/` | 真跑产物样例 |

---

打磨工位：鲁班工坊 · 方案 A（细修）+ 方案 B（精雕）  
工作分支：`luban/polish-router-pack`
