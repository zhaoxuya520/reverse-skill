# 反作弊家族识别（防御 / RE）

> 本页是 reverse-skill **家族识别快表** + 内核交接。完整 AGS anti-cheat / DMA / game-hacking 目录在 [ags/anti-cheat.md](ags/anti-cheat.md)、[ags/dma-attack.md](ags/dma-attack.md)、[ags/game-hacking.md](ags/game-hacking.md)。  
> Distill from [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) (MIT, 2026-08-22).

## 授权（reverse-skill）

- **MUST** `auth.status=granted` 后才对目标 ACT。
- 完整 bypass / 检测目录：**MUST** 打开 [ags/anti-cheat.md](ags/anti-cheat.md)，不要用本快表代替。
- **MUST NOT** 把模块名表当 L1 归因（AGS research-rigor + `ops/evidence-finding-path.md`）。磁盘哈希 + 服务名才是 Observation。
- 内核深挖交接 [`kernel-driver-reverse.md`](../../reverse-engineering/kernel-driver-reverse.md)；EDR-like 栈用 [`edr-bypass-re/SKILL.md`](../../edr-bypass-re/SKILL.md)（跟那些 skill 自己的门禁）。

## 识别表（public names；随标题变化）

| Family | 典型模块 / 服务 / 驱动（公开名） | 层 | 备注 |
|--------|----------------------------------|----|------|
| **Easy Anti-Cheat** | `EasyAntiCheat.exe` / `EasyAntiCheat_EOS.exe`；服务 `EasyAntiCheat*`；`EasyAntiCheat.sys` | user + kernel + server | EOS 变体常见于 Epic 发行 |
| **BattlEye** | `BEService.exe`；`BEClient*.dll`；`BEDaisy.sys` | user + kernel + server | 服务 + 游戏内模块 + 驱动 |
| **Riot Vanguard** | `vgc.exe`；`vgk.sys`（boot-start） | user + kernel + server | 早启动内核可见性 |
| **FACEIT AC** | `FACEIT*.exe` / FACEIT Client；`FACEIT.sys`（标题相关） | user + kernel + platform | 竞技平台完整性 |
| **VAC** | Steam 侧载 user-mode 模块（历史 `vac*.dll`）；无常驻独立内核 AC | user + server | 延迟 ban wave；签名扫描 |
| **nProtect GameGuard / TenProtect** | `GameGuard.des` / `GameMon.des`；`npgg*.sys`；TenProtect：`TPHelper.exe` / `tpsys.sys` | user + kernel | 韩 / 腾讯老栈；与 ACE 分流 |
| **Tencent ACE / AntiCheatExpert** | `ACE-*.sys`（如 `ACE-Base` / `ACE-CORE` 公开名）；`SGuard*`；`GameScan*` | user + kernel + server | 当 EDR-like 栈识别 |
| **XIGNCODE3** | `xhunter1.sys`；`x3.xem` / `xcorona*.xem` | user + kernel | Wellbia；PC/移动都有部署 |
| **PunkBuster** | `PnkBstrA.exe` / `PnkBstrB.exe`；`pbcl.dll` / `pbsv.dll` | user + server | 遗产 FPS；服务成对 |
| **FairFight** | 无典型客户端内核驱动 | **server** | EA 统计 / 回放侧 |
| **Denuvo Anti-Cheat**（historical） | 历史内核组件（非 Denuvo **DRM**） | user + kernel（当时） | AC 产品已停；勿与 DRM 混淆 |
| **Ricochet** | 标题相关 user 模块 + 内核 + 服务端遥测 | user + kernel + server | Activision；CoD 系 |

**MUST** 用本机 `sc query` / `fltmc` / 模块列表 / 文件哈希核验。社区别名不是 Evidence。

## 分层架构

```text
[ game process ]
    user-mode scanner / module hash / overlay & handle checks
           |  service / IOCTL
[ AC service + kernel driver ]
    callbacks (process / image / thread / object) + integrity
           |  telemetry channel
[ server ]
    statistical / replay / report / ban
```

可选第四层：平台虚拟化 / HVCI / 启动度量。有无该层是 **Observation**，不是“已击败内核”。

## DMA（完整目录在 ags/dma-attack.md）

PCIe DMA 可在 OS 之下读物理内存。**完整** 目录：**MUST** 打开 [ags/dma-attack.md](ags/dma-attack.md)（含该文件 Ethical Use）。不要用本段代替。

## 内核 / EDR-like 交接

| 问题 | 去哪 |
|------|------|
| WDM/KMDF、IOCTL、`DriverEntry`、callback 登记 | `reverse-engineering/kernel-driver-reverse.md` |
| hook 表 / ETW / 完整性 — 分析 AC 像分析 EDR | `edr-bypass-re/` |
| 引擎制品而非 AC | [engines.md](engines.md) |

疑似 BYOVD：记名 / 哈希 / 签名与调用意图（见 `kernel-driver-reverse.md` 自己的锚点）。

## 研究严谨度

对齐 [`ops/evidence-finding-path.md`](../../ops/evidence-finding-path.md) 与 AGS research-rigor：

| 层 | 含义 | 反例 |
|----|------|------|
| **Observation** | 本机出现 `vgk.sys` / 某服务在跑 | “已确认作弊” |
| **Finding** | 在声明基线下，完整性 / 不变式被打破 | 单次 callback 命中 = 外挂 |
| **Attribution** | 因果 / 行为者假设，需独立证据 | 模块名 → 某作弊作者 |
| **Path** | 调用 / 检测路径，每步可挂 Evidence | 合成表当 L1 源 |

缺失数据 **MUST** 标 inconclusive。Detector 命中 ≠ 作弊意图。
