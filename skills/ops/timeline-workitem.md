# Timeline + WorkItem / Coverage

> 可回放作战记录（Z3r0 timeline 思想）+ 覆盖勾选（WorkItem 思想）。  
> 全部落在 **`work/<case>/`**（仓库 gitignore），不进 skill 包正文。

## 目录约定

```text
work/<case>/
  scope.md           # 契约（ops/scope-contract.md）
  timeline.md        # 追加写，禁止改历史条目
  workitems.md       # 工作项与覆盖
  evidence/          # 原始产物（截图、pcap、日志）
  notes/
  report/            # 最终报告草稿或拷贝
```

初始化：

```powershell
powershell -File skills\scripts\case-init.ps1 -Hint "full pentest" -CaseName "acme-2026"
```

## timeline.md 格式

每条记录 **只追加**：

```markdown
## {ISO-8601} | {role} | {phase}
- action:
- command_or_ref:
- result_summary:
- artifacts: []      # relative paths under this case
- evidence_ids: []   # E-xxx when promoted
- next:
```

**MUST NOT** 删除或改写已有 `##` 时间块（更正用新条目 + `corrects: {timestamp}`）。

## workitems.md 模板

```markdown
# Work Items

| ID | title | role | targets | surface | status | evidence | notes |
|----|-------|------|---------|---------|--------|----------|-------|
| WI-001 | Port scan edge | cie | {ip} | network | done | E-001 | |
| WI-002 | Auth bypass check | cpe | /api/login | web | blocked | | need creds |

status: pending | in_progress | blocked | done | cancelled

## Coverage
- [ ] Recon complete for in_scope assets
- [ ] Critical/High candidates triaged
- [ ] Validated findings have Evidence
- [ ] Path documented (attack/call/solve)
- [ ] Timeline continuous (no silent gaps >1 major phase)
- [ ] Report exported via docs-generator
- [ ] field-journal written (anonymized)
```

## attack-chain / pentest 挂钩

| Skill | MUST |
|-------|------|
| `attack-chain/` | 多阶段任务创建 case 目录；每阶段结束更新 workitems + timeline |
| `pentest-tools/` | 每次工具跑批后至少 1 条 timeline；发现 → Evidence 草稿 |
| 其它 RE skill | 建议 timeline；至少在出报告前补齐 Evidence 链 |

## 特色

- Agent 友好的纯文本，diff/review 友好  
- 与 tool-index 命令路径可交叉引用  
- 不依赖 WebSocket 直播；需要时把 timeline 贴进报告即可  
