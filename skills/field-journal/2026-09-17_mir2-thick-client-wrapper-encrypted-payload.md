# 2026-09-17 Mir2 系厚客户端「外壳 + 加密载荷」双段结构分析

## 场景分类

二进制分析 / Windows 厚客户端 / Mir2（传奇）系游戏客户端 / 加壳载荷 / 代理隧道 / 反作弊完整性校验

## 目标概述

对一个 Windows x86 C/S 游戏客户端（`{game_root}`，路径含非 ASCII 字符）完成离线静态逆向：确认「面向用户的启动器」与「真正主程序」的分工、加密载荷的嵌套关系、游戏引擎族谱、资源容器格式，以及启动器的网络/权限/自更新能力面。全程 `network_profile=offline`，未连接任何远端。

## 完整执行链路

1. 走 reverse-skill 阶梯：`RULES.md` → `MASTER-ROUTING.md` → `master-route.ps1` → PRIMARY=`thick-client` (R32) → `case-init.ps1 -Preset offline-sample` → 才动手。
2. **先解决工具路径坑**：`rabin2` 无法打开含非 ASCII（本项目含 `[云]`）的路径，报 `Cannot open file` 并输出乱码路径。把样本复制到纯 ASCII 临时目录后再分析，原始文件保持只读。
3. 对两个 PE 做「三角」：节区 + 熵 + 导入 + 资源 + overlay。这一步直接决定后续路线。
4. 主程序判为**加壳桩**：`.text` 熵 8.000、overlay 24 MB 熵 7.998、**整程序仅 4 个导入**（`LoadLibraryA`/`GetProcAddress`/`VirtualAlloc`/`VirtualFree`）、entry 落在 `.text` 起始且该节可写可执行。
5. 启动器判为**正常 MSVC/MFC 外壳**：685 导入（含 `WS2_32` 21 / `CRYPT32` 8）、22.8 MB `.rsrc`、无 overlay、PDB 泄露内部工程名与开发者路径。
6. 解析资源树，发现 `MYDATA#136` 的体积（34,273,734 B）**与主程序文件体积逐字节相同** → 确认「外壳内嵌加密主程序」。同时捞出 `MYDATA#131/132/138` 三个小载荷。
7. **密钥流反推（crib drag）**：利用「PE 必以 `4D5A9000 03000000 04000000 FFFF0000` 开头」，从密文直接异或反推密钥流。反推出 16 字节后验证——**只有前 16 字节成立**，按此密钥全量解密后熵仍 7.9999、`e_lfanew` 处不是 `PE\0\0` → 判定为**位置相关（多表/滚动）异或**，静态解密受阻，记录受阻点并转面。
8. 转**行为面取证**：GBK 感知字符串挖掘 + 字符串 VA 交叉引用映射，从 `.rdata/.data` 恢复能力面：AES 配置层（`secretkey`/`ipconfigSecretKey`/`ipconfigSecretVI`）、`configServerIP`、`clientFileMD5`/`cDataTopMD5`、代理隧道日志、`SeDebugPrivilege`、`\pro.nlp`/`\update.temp`/`\dunupdate.`。
9. 提取 VERSIONINFO 与 manifest：内部名、版本、以及 **`requireAdministrator`**；VERSIONINFO 的公司/产品字段仍是 `TODO:` 模板，且**未数字签名**。
10. 资源容器三角定引擎：地图文件头 `90 01 90 01` + 明文 `"Legend of mir"` → **Mir2**；`.Pak` 带 `GAMEOFMIR` 签名 → GOM 引擎家族；`WZL`/`puk` 全加密。
11. **发现真实运行残留**（非本次产生）：`%APPDATA%\awsip\cloudx<id>.ip`、`%APPDATA%\clinkm2.data`、`pro.nlp`。逐个还原结构：`pro.nlp` = BOM + GBK 的安装目录全路径（**防移动判据**）；`clinkm2.data` = `u32 len` + 32 字符 hex（16 字节机器 ID）+ 零填充至 4096 B；`cloudx*.ip` = `u32 len`（=文件全长）+ 密文。
12. 找到唯一可解层：伪装成 `.zip` 的文件头是 `78 9C`（zlib 而非 `PK`），`zlib.decompress()` 一次成功（1.30 MB → 3.09 MB）。
13. 解压体语义还原：Delphi 对象/RTTI 表，含配置对话框类、自动玩法、自动补给、怪物过滤、物品/技能名单、以及 `Config\%s.%s.{Friends,Target,HeiMingDan}.txt` 三类名单文件 → 判定为**随包分发的第三方游戏辅助模块配置表**（仅静态还原，未运行）。
14. 输出报告 + 信任边界图 + 证据台账（每条证据附复现命令）+ 时间线，并把 4 项方法失败记录单列，禁止其进入结论。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|---|---|---|---|
| `rabin2` 报 `Cannot open file` 且路径乱码 | 工具无法处理含非 ASCII 的路径 | 复制到纯 ASCII 临时目录再分析 | 低 |
| 高熵区"字符串"里出现 `IP`/`Nt`/`MZ` | 熵≈8 的随机字节必然产生大量短伪命中 | 只在 `.rdata/.data` 取字符串；高熵区命中一律不作证据 | 低 |
| GBK 字节对扫描产出 **82 万条**"中文" | 对二进制字节对做 GBK 解码必然大量伪命中 | **废弃该方法**，改用 ASCII 字符串 + 语义关键词 | 中 |
| UTF-16LE 扫描产出 **5.6 万条**伪中文 | 同上，二进制的偶发 `0x4E-0x9F` 高位字节 | **废弃该方法**，结果整体丢弃 | 中 |
| PAK 2 字节周期异或爆破出现 8557 组"可行"密钥 | 约束太弱（只要可打印），无鉴别力 | 判定为退化结果，**丢弃**；改走动态读栈或取服务端口令表 | 中 |
| crib drag 反推出的密钥只在前 16 字节成立 | 误把「多表异或」当「固定周期异或」 | 用全量解密后的熵 + `e_lfanew` 处签名做**反证**，确认受阻并换路线 | 中 |
| `.zip` 用 zipfile 打不开 | 扩展名撒谎，实体是 zlib 流 | 先看文件头魔数，再选解码器 | 低 |
| 内嵌载荷与主程序**体积相同但哈希不同** | 把"体积吻合"误当"内容相同" | 体积吻合只作为线索，必须哈希/逐字节确认 | 低 |

## 工具链发现

- **熵 + 导入数量 + 节区布局** 三件套能在几秒内判定「加壳桩」，是最省时的分诊手段：`.text` 熵 8.000 且导入 ≤ 5 个，几乎必然是运行时解密装载器。
- **资源节体积异常**是发现内嵌载荷的第一线索；把资源里每个 `MYDATA`/自定义类型的体积与目录内已知文件体积对比，可直接锁定嵌套关系。
- **crib drag 必须做反证**：反推出密钥后，一定要用「全量解密后的熵」和「结构字段（如 `e_lfanew`、`PE\0\0`）」验证，否则会把固定周期异或的巧合当成功。
- **运行时残留常常比二进制更好读**：`%APPDATA%` 下的配置/缓存文件往往是「长度前缀 + 加密体」的简单结构，比分析加壳主程序高效得多。
- **扩展名不可信**：`.zip` 实为 zlib、`.puk` 实为加密数据、`.dat` 实为 GBK 文本；一律先看魔数。
- 对含非 ASCII 路径的 Windows 项目，**先复制样本到 ASCII 路径**应作为标准前置步骤。

## 关键代码/命令

```powershell
# 0) 路由与授权门禁
powershell -NoProfile -ExecutionPolicy Bypass -File "<ROOT>\skills\scripts\master-route.ps1" `
  -Hint "Windows 厚客户端 C/S 游戏客户端逆向分析" -ProjectRoot "<PROJECT_ROOT>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<ROOT>\skills\scripts\case-init.ps1" `
  -Hint "<task>" -CaseName "<case>" -Preset offline-sample -Sample "<sample.exe>" -ProjectRoot "<PROJECT_ROOT>"

# 1) ASCII 路径规避非 ASCII 路径坑
Copy-Item -LiteralPath "<PROJECT_ROOT>\{game}.exe" -Destination "C:\Temp\<ascii>\game.exe" -Force

# 2) 加壳桩判定（熵 / 节区 / 导入 / overlay）
& "<r2>\rabin2.exe" -I "C:\Temp\<ascii>\game.exe"
& "<r2>\rabin2.exe" -S "C:\Temp\<ascii>\game.exe"
& "<r2>\rabin2.exe" -i "C:\Temp\<ascii>\game.exe"
# 若可用，用 r2.bat 做符号化交叉引用（Windows 上主程序是 r2.bat 而非 r2.exe）
& "<r2>\r2.bat" -2 -q -e scr.color=0 -c "izz" "<sample>"
```

```python
# 3) crib drag + 反证（PE 头是已知明文）
MZ = bytes([0x4D,0x5A,0x90,0x00,0x03,0x00,0x00,0x00,0x04,0x00,0x00,0x00,0xFF,0xFF,0x00,0x00])
ks = bytes(a ^ b for a, b in zip(cipher[:16], MZ))
# 周期检测：若 16 字节内无更小周期 -> 固定周期异或假设可疑
per = next((p for p in range(1, 17) if all(ks[i] == ks[i % p] for i in range(16))), None)
# 反证：全量解密后熵仍≈8 或 e_lfanew 处非 'PE\0\0' -> 多表异或，静态受阻
```

```python
# 4) 扩展名撒谎：先看魔数再选解码器
import zlib
d = open(path, 'rb').read()
if d[:2] in (b'\x78\x9c', b'\x78\xda', b'\x78\x01'):
    out = zlib.decompress(d)          # .zip 实为 zlib 流的情况
```

## 对本包的改进建议

1. 在 `thick-client` 与 `reverse-engineering` 的 triage 清单里固化一条**「熵 8 + 导入 ≤5 ⇒ 加壳桩」**快速判据，并附「资源体积 ↔ 目录文件体积比对」找嵌套载荷的步骤。
2. 新增 **crib-drag 反证**强制项：反推密钥后必须校验「全量解密熵」与「结构字段」，禁止仅凭前 N 字节断言解密成功——本次差点在这点上误判。
3. 为「高熵区字符串」加显式警告：熵≈8 区域的关键词命中属噪声，不得作为能力证据写入报告。
4. 在 Windows 逆向路线的前置步骤中加入**「路径含非 ASCII → 先复制到 ASCII 路径」**，避免各工具（rabin2/IDA 插件等）重复踩坑。
5. 增加**「运行时残留优先」**提示：当主程序为加壳时，优先去 `%APPDATA%`/`%LOCALAPPDATA%`/注册表找配置与缓存，性价比高于硬啃解密算法。

## 可复用的模式/脚本片段

1. **两段式外壳识别模式**：外壳（正常 MSVC/MFC + 大资源节 + 网络与校验能力）→ 资源内嵌主程序（体积与目录内同名文件吻合）→ 主程序为加壳桩。识别到该模式后，优先分析**外壳**（未加壳、字符串全可读）而非主程序。
2. **长度前缀配置记录模式**：`u32 length + payload`，且 `length` 常等于文件全长；据此可切出密文体，并判断文件是否被截断。
3. **安装路径锚点模式**：把安装目录写入自有标记文件（BOM + GBK/本地编码），启动时比对实际路径 ⇒ 实现「移动即失效/自杀」。取证时应把该文件与目录实际路径一并固定。
4. **完整性校验字段命名法**：`clientFileMD5` / `cDataTopMD5` 这类 camelCase 键名是定位反作弊逻辑的高价值路标，往往与 `configServerIP`、更新逻辑相邻出现。
5. **方法作废纪律**：对退化/无鉴别力的爆破（如弱约束的短周期异或）与噪声爆炸的启发式（二进制广扫 CJK）应当**显式作废并写入台账**，避免其结论污染报告。

## 进化动作

- [x] 新增了 pitfalls 记录
- [x] 更新了经验索引
- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档

## 环境信息

- OS: Windows 11 x64
- 工具版本: radare2 6.1.4 (rabin2/rahash2/r2.bat), Python 3 (msys64 ucrt64), zlib
- 目标平台/版本: Windows x86 PE32 / 32 位 Mir2 系游戏客户端

## 脱敏要求

本文仅保留通用结构、字节级格式特征、能力类别与分析手法。样本名、游戏名、安装目录、机器 ID、内部工程名、开发者路径、PDB 路径、真实域名、文件哈希与具体偏移均已替换为占位符或省略；未附带样本文件与解压产物。
