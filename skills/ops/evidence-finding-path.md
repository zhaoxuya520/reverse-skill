# Evidence → Finding → Path 证据链

> 灵感来自 Z3r0 Evidence Plane，落地为 **Markdown 字段契约**。  
> reverse-skill 特色：与 `docs-generator` 报告模板、`field-journal` 脱敏回写、可复现命令绑定。

## 1. Evidence（不可变观察）

每条证据独立一段或表行：

```markdown
### E-{nnn}
- title:
- observed_at:
- source_type: command | screenshot | file | log | memory | network | manual
- source_ref: {path or command id}
- content_hash: {sha256 of artifact if file, else n/a}
- repro_command: |
    {exact command}
- raw_excerpt: |
    {脱敏摘录}
- linked_workitem: WI-{nnn} | n/a
- supersedes: E-{nnn} | none
```

**MUST**：Finding 引用的 Evidence 至少 1 条；`repro_command` 第三方可跑或标明离线限制。

**CLI helper**（写入 `work/<case>/evidence/E-*.md`）：

```powershell
powershell -File skills/scripts/append-evidence.ps1 -CaseRoot work/<case> `
  -Id E-001 -Title "..." -ReproCommand "..." -Severity info -Status observed
```

## 2. Finding（安全/逆向结论）

```markdown
### F-{nnn}
- title:
- severity: critical | high | medium | low | info | n/a_re
- category: vuln | misconfig | design | reverse_algo | bypass | other
- status: candidate | validated | false_positive | accepted_risk
- evidence_ids: [E-001, E-002]
- location: {file:line | addr | url | class.method}
- impact:
- confidence: high | medium | low
- repro_steps:
  1.
  2.
- remediation: {or n/a for pure RE}
- optional_attack: {ATT&CK ID or empty}
```

**MUST**：`evidence_ids` 非空；`status=validated` 时 confidence 不得为 low（除非标注 residual risk）。

## 3. Path（攻击路径 / 调用路径 / 解题路径）

统一叫 **Path**，按任务类型解释：

| 任务 | Path 含义 |
|------|-----------|
| 渗透 / 攻击链 | 攻击路径步骤 |
| 逆向 | 关键调用/数据流步骤 |
| CTF | 解题步骤 |

```markdown
### P-{nnn}
- title:
- path_type: attack | callflow | solve
- start:
- goal:
- steps:
  1. action: — evidence: E-xxx — finding: F-xxx | none
  2. action: — evidence: E-xxx — finding: F-yyy | none
- residual_risks:
```

**MUST**：每步可关联 Evidence；攻击路径终点 Finding 若声明「已拿权限/数据」必须有 validated 证据。

## 4. 报告中的位置

`docs-generator` 安全报告 **MUST** 含：

1. Scope 摘要（链到 case `scope.md`）  
2. Evidence 表或章节  
3. Findings 列表（含 evidence_ids）  
4. 至少 1 条 Path（攻击/调用/解题）  
5. Timeline 摘要（可选全文链到 `timeline.md`）

详见 `docs-generator/references/security-report-templates.md` 中 **Evidence Chain** 节。

## 5. field-journal 挂钩

回写 journal 时 **SHOULD** 摘录：

- 3 条内关键 Evidence id + 命令  
- 1 条核心 Finding  
- 可复用 Path 模式一句话  

完整敏感内容只在用户项目报告中；journal **MUST** 脱敏（`anonymization.md`）。

## 6. 与 Z3r0 的差异（特色）

| Z3r0 | reverse-skill |
|------|----------------|
| PG 不可变行 + API | Markdown 文件 + hash 字段 |
| UI 审阅队列 | 报告 + next-step 菜单 + journal |
| ATT&CK 深度绑定 | 可选标签，不强制 UI |
