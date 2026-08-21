# 发布 Checklist

> 每次发版前逐项核对。版本事实源：VERSION 文件必须与 CHANGELOG.md 最新发布版本一致（CI ersion-check job 自动校验，不一致会红）。

## 发版步骤

1. [ ] 确认 CHANGELOG.md 的 [Unreleased] 段内容齐全（Keep a Changelog 分组：Added / Fixed / Security / Removed）
2. [ ] 将 ## [Unreleased] 改为 ## [x.y.z] — YYYY-MM-DD，并把比较链接从 ...HEAD 更新到新 tag
3. [ ] 同步更新 VERSION 文件为 x.y.z
4. [ ] 里程碑版本（如 v1.0.0 / v1.1.0）同步更新 docs/RELEASE_NOTES_v<x.y.z>.md
5. [ ] 打 tag：git tag v<x.y.z> + git push --tags
6. [ ] 推送后确认 CI 全绿（routing 173 基准 + coherence + pin gate + version-check）

## 元数据同步（发版顺手项）

- 新增/删除 bootstrap 能力 → 同步 RULES.md / RULES_zh.md / skills/SKILL.md 的能力列表（以 skills/scripts/bootstrap-manifest.json 为唯一事实源，当前 25 项）
- 新增 field-journal 条目 → 更新 skills/field-journal/_index.md 三处（场景分类 / 高频模式 / 实体倒排）与统计
- 路由规则变更 → 只改 skills/config/routing.json（文档由生成脚本维护或至少保持一致）

> 注：journal 条目底部不再手工维护 <!-- [进化统计] --> 累计注释（已于 2026-08-10 移除，数字无法可靠维护），项目计数以 _index.md 为准。
