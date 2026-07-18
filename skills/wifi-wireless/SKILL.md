---
name: wifi-wireless
description: Use for authorized wireless security assessment including Wi-Fi capture, WPA handshake analysis, rogue AP detection research, and lab-only deauth testing.
---

# Wi-Fi / Wireless Security

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: 读取 precedent-pentest；**无线攻击法律风险高**，必须书面授权与物理范围
2. `NOW`: scope 写明目标 SSID/BSSID/场地；禁止扫邻居网络
3. `NEXT`: 确认适配器监听模式能力
4. `ACT`: 侦察 → 采集 → 分析（实验室优先）

## 适用场景

- 授权 Wi-Fi 安全评估
- WPA/WPA2 握手采集与离线评估
- 流氓 AP / 钓鱼热点检测研究
- 企业无线隔离与门户安全

## 工作流

```text
□ iwconfig / airmon-ng 进入 monitor（合法环境）
□ airodump-ng 锁定目标 BSSID 频道
□ 握手或 PMKID 采集（仅目标）
□ hashcat/aircrack 离线评估口令策略
□ 报告：加密类型、隔离、门户绕过、建议
```

## 工具链

| 工具 | 用途 |
|------|------|
| aircrack-ng suite | 采集/评估 |
| hcxdumptool / hcxtools | PMKID |
| hashcat | 口令评估 |
| Wireshark | 管理帧分析 |

## 参考

- `references/wireless-lab-rules.md`
- `../pentest-tools/` `../attack-chain/`（近源章节）

## 路由上下文

**上游**: MASTER R29  
**MUST NOT**: 未授权 deauth、对非目标客户网络操作

## 任务完成自检

- [ ] 是否严格锁定目标 BSSID？
- [ ] 是否在报告中给出加固建议？
- [ ] Checklist？