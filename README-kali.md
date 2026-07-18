# Kali Linux 入口（短跳转）

> **详细说明以 [kali/README-kali.md](kali/README-kali.md) 为准。**  
> 本文件仅作仓库根目录的 Kali 快捷入口，避免与 `kali/` 下正文重复维护。

## AI：读完后立即执行

```text
1. 检测包根目录（含 README.md / skills/ 的目录）
2. 读 kali/README-kali.md → 再读 kali/RULES-kali.md 并执行
3. bash kali/scripts/refresh-tool-index.sh
4. 任务路由与 Windows 共用：skills/MASTER-ROUTING.md、skills/ops/（scope 门）
5. 向用户报告配置结果
```

## 人：30 秒上手

```bash
cd /path/to/reverse-skill
bash kali/scripts/refresh-tool-index.sh
# 详细 bootstrap / MCP 见 kali/README-kali.md
```

## 与主包关系

| 内容 | 位置 |
|------|------|
| 共享 skill / 路由 / ops | `skills/`、`RULES.md` |
| Kali 脚本与 manifest | `kali/scripts/` |
| 完整 Kali 文档 | **[kali/README-kali.md](kali/README-kali.md)** |

通用 AI 引导仍见 [README_AI.md](README_AI.md)（选 Kali 分支时转本目录文档）。
