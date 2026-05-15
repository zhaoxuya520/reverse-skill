# 项目经验索引

> 本文件由 AI 在每次完成逆向/渗透/安全项目后自动维护。
> 新任务开始前先查阅本索引，复用已有经验，避免重复踩坑。
> 带 [种子] 标记的条目是预置的教科书级参考，非真实项目。

## 按场景分类

### APK 逆向
<!-- 格式: - [YYYY-MM-DD] 项目简称 — 关键词: keyword1, keyword2, keyword3 -->

### JS 签名 / Web 逆向
- [种子] JS 签名逆向（Webpack+AES+时间戳）— 关键词: webpack, HmacSHA256, sign参数, 断点, initiator

### 二进制分析
- [种子] ELF 自解压加载器逆向 — 关键词: ARM64, LZSS, mmap, 自解压, 反分析, 损坏PHDR
- [种子] Go 恶意软件逆向（stripped+Garble）— 关键词: Go, Garble, GoReSym, GoResolver, C2, AES密钥

### 渗透测试
- [种子] Web API 未授权访问+IDOR — 关键词: REST API, IDOR, 越权, Swagger暴露, FFUF

### CTF
<!-- 格式: - [YYYY-MM-DD] 项目简称 — 关键词: keyword1, keyword2, keyword3 -->

### 抓包分析
<!-- 格式: - [YYYY-MM-DD] 项目简称 — 关键词: keyword1, keyword2, keyword3 -->

### 其他
<!-- 格式: - [YYYY-MM-DD] 项目简称 — 关键词: keyword1, keyword2, keyword3 -->

---

## 高频踩坑 Top 5

1. 文件后缀不可信 — 永远用 `file` 命令确认真实类型
2. Go 二进制函数太多看不过来 — 用 GoReSym 恢复后按包名过滤
3. FFUF/扫描被 WAF 拦截 — 降低速率 + 换 User-Agent
4. 解压器/解密器 Python 实现输出错误 — 仔细对照汇编的进位/溢出行为
5. SRC 报告被拒 — 必须有可复现的 curl 命令，不能只有截图

---

## 累计统计

- 总项目数: 4（含种子）
- 新增模式数: 8
- 工具链修复数: 0
- 最近更新: 2026-05-15
