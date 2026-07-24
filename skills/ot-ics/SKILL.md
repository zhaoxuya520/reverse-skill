---
name: ot-ics
maturity: extended
description: Use for authorized OT/ICS security assessment covering Purdue model zoning, PLC/SCADA exposure, industrial protocol discovery, and safe passive-first evaluation.
---

> **Maturity: `extended`** · usable playbook · see [`../references/skill-maturity.md`](../references/skill-maturity.md). Expect more manual tool work than **core** skills.

# OT / ICS Security

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: 读取 `../field-journal/precedent-pentest.md` — **工控环境误操作可致物理危害**
2. `NOW`: 书面授权必须写清：站点、网段、是否允许主动扫描/写寄存器
3. `NOW`: case-init；默认 **passive-first**；`ready_for_act` 前禁止对 PLC 写操作
4. `NEXT`: tool-index；多数工控工具需手动与隔离实验网
5. `ACT`: 资产与分区识别 → 暴露面 → 只读验证

## 适用场景

- 工控/SCADA/DCS 安全评估（授权）
- Purdue 模型分区与跨区通道
- Modbus/DNP3/S7/EtherNet/IP 等协议暴露
- 工程师站、HMI、历史库、跳板主机
- IT/OT 融合边界（防火墙规则、单向闸）

## 安全铁律（MUST）

```text
MUST NOT 在未明确允许时：
- 对 PLC 写线圈/寄存器
- 全网高速率扫描生产 OT
- 中断安全仪表系统（SIS）相关路径
优先：只读识别、流量镜像、离线固件/配置分析
```

## 工作流

### Phase 1 — 分区与资产

```text
□ Purdue L0–L5 草图：现场设备 → 控制 → 监督 → 站点 DMZ → 企业
□ 资产清单：PLC/RTU/HMI/工程师站/历史库/Jump host
□ 协议与端口基线（仅授权网段）
```

### Phase 2 — 被动与只读

```text
□ SPAN/镜像 PCAP → protocol-reverse / Wireshark 工控解析器
□ 配置与工程文件离线审计（TIA/RSLogix 导出等）
□ 默认口令与明文协议（Modbus 无认证）记录为 Finding，不写盘改值
```

### Phase 3 — 受限主动（仅授权）

```text
□ 低速识别，维护窗口
□ 只读功能码优先
□ 每步 Evidence；异常立即停止并通报
```

### Phase 4 — 固件/补丁面

```text
□ 控制器固件版本 → CVE 映射（不盲刷固件）
□ 联合 firmware-pentest 做离线镜像分析
```

## 工具链

| 工具 | 用途 | 注意 |
|------|------|------|
| Wireshark 工控 dissectors | 被动解析 | 镜像流量 |
| Nmap NSE（受限） | 识别 | 速率与时间窗 |
| Claroty/Nozomi 等 | 资产发现 | 商业/现场 |
| PLC 厂商工程软件 | 配置审计 | 离线优先 |
| binwalk / Ghidra | 固件 | 离线 |

## 参考

- `references/ot-safe-assessment.md`
- `../firmware-pentest/` `../protocol-reverse/` `../network` via pentest-tools

## 路由上下文

**上游**: MASTER R28  
**下游**: 固件深挖 `firmware-pentest`；协议 `protocol-reverse`；IT 横向 `windows-ad`/`attack-chain`  
**同级**: 不要用普通 Web 扫默认参数打 OT

## 任务完成自检

- [ ] 是否默认被动/只读并记录授权边界？
- [ ] 是否避免对控制回路写操作（除非明确允许）？
- [ ] Finding 是否含物理/过程影响说明？
- [ ] Checklist / journal？