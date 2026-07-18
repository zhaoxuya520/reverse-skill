---
name: thick-client
description: Use for authorized security testing of desktop thick clients including local storage, update channels, IPC, traffic, and client-side trust boundaries.
---

# Thick Client Security Testing

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: 读取 `../field-journal/precedent-pentest.md`
2. `NOW`: 确认目标是 **桌面厚客户端**（Win/macOS/Linux GUI 或服务伴生），非纯 Web
3. `NOW`: case-init；安装包来源与测试账号写入 scope
4. `NEXT`: 工具（Burp 上游代理、进程监控、逆向工具）
5. `ACT`: 信任边界图 → 本地面 → 网络面 → 更新/供应链

## 适用场景

- C/S 架构客户端、Electron/Qt/.NET WinForms/WPF
- 本地配置/凭证存储、IPC、命名管道
- 客户端强制校验绕过研究（授权）
- 自动更新通道与代码签名验证

## 工作流

### 1. 建边界

```text
□ 进程树、子进程、驱动/服务
□ 监听端口与出站域名
□ 本地敏感路径：%APPDATA%、Keychain、注册表
```

### 2. 本地攻击面

```text
□ 明文配置、硬编码密钥、调试开关
□ DLL 劫持/搜索顺序（Windows）
□ 数据库文件（SQLite）权限与加密
□ IPC：谁可连接？是否鉴权？
```

### 3. 网络面

```text
□ 系统代理 / 应用自定义 TLS
□ 证书钉扎 → 联合 mobile/js 方法学或 Frida
□ API 越权：客户端隐藏的管理接口
```

### 4. 逆向验证

```text
□ .NET → dotnet-reverse；原生 → ida/ghidra；Electron → asar + js-reverse
```

## 工具链

| 工具 | 用途 |
|------|------|
| Process Monitor / API Monitor | 行为 |
| Burp / mitmproxy | 流量 |
| dnSpy / IDA / Ghidra | 逆向 |
| Sysinternals | Windows 面 |
| asar / nexe 检测 | Electron |

## 参考

- `references/thick-client-checklist.md`
- `../dotnet-reverse/` `../ida-reverse/` `../js-reverse/` `../api-security/`

## 路由上下文

**上游**: MASTER R32  
**下游**: 纯协议 `protocol-reverse`；供应链更新 `supply-chain-security`

## 任务完成自检

- [ ] 是否画出信任边界？
- [ ] 本地+网络面是否都覆盖？
- [ ] Checklist？