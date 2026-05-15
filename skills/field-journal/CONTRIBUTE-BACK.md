# 社区进化：向主仓库贡献经验

## 机制说明

每次你完成一个项目并生成 field-journal 条目后，AI 会询问：

```
✅ 经验已记录到 field-journal/

📤 是否将本次经验贡献到社区主仓库？
- 数据已按模板要求脱敏（域名/IP/Token/PII 已替换）
- 只会提交 field-journal/ 目录下的新文件
- 不会提交你的 tool-index、scope、findings 等私有文件
- 贡献后其他用户也能复用你的经验

回复"是"提交，回复"否"跳过。
```

## 贡献流程

```text
1. AI 生成 field-journal 条目（已脱敏）
2. AI 询问用户是否贡献
3. 用户同意 → AI 执行以下步骤：
   a. 检查脱敏是否完整（二次确认无真实域名/IP/Token）
   b. 检查是否与主仓库已有条目重复（按场景+关键词匹配）
   c. 如果不重复 → 创建 PR 到主仓库
   d. PR 标题格式：[field-journal] YYYY-MM-DD 场景类型 - 关键词
4. 主仓库维护者审核合并
```

## 技术实现

### 方式 1：GitHub CLI（推荐）

```bash
# 1. Fork 主仓库（如果还没 fork）
gh repo fork zhaoxuya520/reverse-skill-private --clone=false

# 2. 在本地创建贡献分支
git checkout -b contribute/journal-YYYY-MM-DD-keyword

# 3. 只添加 field-journal 文件
git add skills/field-journal/YYYY-MM-DD_*.md
git add skills/field-journal/_index.md

# 4. 提交
git commit -m "[field-journal] 场景类型: 关键词摘要"

# 5. 推送到 fork
git push origin contribute/journal-YYYY-MM-DD-keyword

# 6. 创建 PR
gh pr create --repo zhaoxuya520/reverse-skill-private \
  --title "[field-journal] YYYY-MM-DD 场景类型 - 关键词" \
  --body "## 贡献内容\n- 场景：xxx\n- 关键词：xxx\n- 脱敏确认：✓\n\n## 数据安全声明\n本条目已按模板要求完成脱敏，不包含真实目标信息。"
```

### 方式 2：直接推送（如果用户有主仓库写权限）

```bash
git checkout -b contribute/journal-YYYY-MM-DD-keyword
git add skills/field-journal/YYYY-MM-DD_*.md
git add skills/field-journal/_index.md
git commit -m "[field-journal] 场景类型: 关键词摘要"
git push origin contribute/journal-YYYY-MM-DD-keyword
gh pr create --repo zhaoxuya520/reverse-skill-private \
  --title "[field-journal] YYYY-MM-DD 场景类型 - 关键词" \
  --body "脱敏确认：✓"
```

## 去重规则

AI 在提交前必须检查主仓库的 `field-journal/_index.md`：

1. **场景+关键词完全相同** → 不提交，提示"已有相同经验"
2. **场景相同但关键词不同** → 可以提交（同类场景的不同变体有价值）
3. **场景相同且解决方案相同，但目标不同** → 不提交（重复）
4. **场景相同但解决方案是新的** → 可以提交（新的解决路径）

判断标准：
- 读取 `_index.md` 中同类场景的所有条目
- 对比关键词重叠度（>80% 视为重复）
- 对比"踩坑记录"表中的问题描述（相似度 >90% 视为重复）

## 只允许提交的文件

**白名单**（只有这些文件可以出现在 PR 中）：
- `skills/field-journal/YYYY-MM-DD_*.md`（新的经验条目）
- `skills/field-journal/_index.md`（索引更新）

**黑名单**（绝对不能出现在 PR 中）：
- `tool-index.*`（包含用户本机路径）
- `pentest-tools/templates/scope.md`（包含目标信息）
- `pentest-tools/templates/findings.md`（包含漏洞详情）
- `pentest-tools/templates/progress.md`（包含操作记录）
- `.claude/`（用户配置）
- `.kiro/`（用户配置）
- 任何 `.env`、`*.key`、`*.pem` 文件

## 脱敏二次检查

AI 在提交前必须扫描待提交文件，确认不包含：

- [ ] 真实域名（非 `example.com`/`target.example.com`）
- [ ] 真实 IP（非 `10.x.x.x`/`192.168.x.x`）
- [ ] Token/Cookie/API Key 原文
- [ ] 手机号/邮箱/用户名原文
- [ ] 公司名/产品名（如果是 SRC 目标）

如果发现任何一项未脱敏，停止提交并提示用户修改。

## 对用户的价值

- 你贡献的经验会帮助其他用户避免踩同样的坑
- 主仓库的 field-journal 越丰富，所有用户的 AI 越聪明
- 你的贡献会在 _index.md 中保留（匿名，只有场景和关键词）
