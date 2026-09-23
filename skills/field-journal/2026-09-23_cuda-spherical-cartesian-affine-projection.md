# 2026-09-23 CUDA Spherical Cartesian-affine projection closure

## 场景分类

二进制分析 / 科学计算与 GPU 净室还原 / 摄影测量

## 目标概述

从历史冻结输入中恢复 Spherical PatchMatch cost 的有效性首差，并依据目标 PTX
纠正 Cartesian 分量、球面角和图像中心项的精确混合方式，同时用同输入原生 A/B
区分“指令语义闭合”和“端到端质量变化”。

## 完整执行链路

1. 先在最新连续链输入上强制 camera type，发现历史差异不能复现，拒绝把旧计数当作普遍规律。
2. 批量重放历史 cost 捕获，找回能稳定复现 170 个差异的冻结输入，并输出首差的邻图、候选和位型。
3. 首差中 source 给出有效 cost，而目标 PTX 返回拒绝哨兵，因此把审计点前移到投影和纹理窗口准入。
4. 按目标 PTX 基本块建立逐操作图，确认 longitude/latitude 仍是球面角，但 `b1` 乘的是 Cartesian `point.x`。
5. 同一指令图还证明 `cx/cy` 在角度仿射项之后、半幅尺寸之前累计，不能提前代数合并。
6. 只修改 Spherical 分支，不改变阈值、纹理采样规则、其他 camera family 或下游 support/filter。
7. 在原始输入上验证 170 个差异归零，再扩展到 14 个历史捕获和 1,310 万级 cost 槽位。
8. 对三个已闭合 camera type 做两组保护性直接回放，并复跑完整连续链、Frame 和 RPC 回归。
9. 用修改前冻结正式二进制和修改后正式二进制跑完全相同的原生 Spherical 输入，逐文件比较非 manifest 产物。
10. 原生产物完全一致；检查标定后确认该样例 `b1=0`，因此保留正确性修复，但不声称 mesh 指标改善。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|---|---|---|---|
| 在最新输入上复现不到历史 170 个差异 | 差异依赖投影参数和纹理边界，不是固定计数 | 系统重放历史冻结捕获，先恢复原始输入再定位首差 | 中 |
| 首差被误当作 NCC 尾数误差 | source 有效而 PTX 返回拒绝哨兵，分叉发生在 cost 计算之前 | 比较投影坐标和窗口准入，沿 PTX 控制流向前追踪 | 低 |
| 把 `b1` 视为球面 longitude 的线性项 | 仅凭高层相机模型推断了变量语义 | 按 PTX 寄存器 def-use 证明操作数来自 Cartesian `point.x` | 中 |
| 与旧端到端 artifact 比较出现多项指标变化 | 旧 artifact 混入若干轮其他生产修改 | 保留旧结果作历史状态，另用同工作树 legacy/new binary 做干净 A/B | 中 |
| 修复后原生产物没有变化 | 当前标定 `b1=0`，centering 舍入也未跨采样边界 | 以 direct PTX 合同验收正确性，并明确不宣称质量收益 | 低 |
| 一个历史 propagation capture 被 source-only replay 拒绝 | 捕获 schema 不在该工具的支持集合 | 改用同 camera family 的兼容 refinement capture，不绕过门禁 | 低 |

## 工具链发现

- camera type 强制回放适合快速筛分分支，但“某个输入为零差异”不能证明整个分支闭合。
- 当 source 输出有效值、目标输出拒绝哨兵时，优先审计投影、边界和有效性控制流，而不是继续比较代价尾数。
- 相机模型中的系数名不保证高层语义；应通过 PTX 寄存器 def-use 确认它乘的是 Cartesian 分量还是角度变量。
- 正确性修复可在现有原生夹具上表现为完全 inert。冻结旧二进制的同输入 A/B 能防止把历史累计变化错误归因。
- 生产和目标 PTX oracle 应继续分构建管理；oracle-on 用于归因，oracle-off 才是发布合同。

## 关键代码/命令

```text
# 在同一冻结 cost 输入上切换被测 camera family
METMODEL_COST_CAMERA_TYPE={camera_type} {oracle-replay} {capture}

# 正式构建始终关闭目标 PTX oracle
cmake -S {source} -B {production-build} -DMETMODEL_ENABLE_CUDA_PTX_ORACLES=OFF

# 同输入原生 A/B：排除 manifest 后比较所有产品哈希
{legacy-production-runner} {same-input} {before-output}
{current-production-runner} {same-input} {after-output}
```

目标 Spherical 横向投影的不变量：

```text
longitude = atan2(point.x, point.z)
latitude  = atan2(point.y, hypot(point.x, point.z))
affine_x  = b1 * point.x + f * longitude + b2 * latitude
pixel_x   = width * 0.5 + (affine_x + cx)
pixel_y   = height * 0.5 + (f * latitude + cy)
```

## 对本包的改进建议

- 在 CUDA 浮点差分指南加入“有效值对拒绝哨兵”的快速路由，优先转到 projection/admission 审计。
- 在 camera ABI 记录中同时标注字段名、真实操作数来源和适用分支，避免按名称猜测变量语义。
- 把冻结旧正式二进制的同输入 A/B 加入净室修复验收模板，明确隔离累计变更。
- 报告模板应强制区分 direct contract closure、native product delta 和未覆盖参数域。

## 可复用的模式/脚本片段

遇到历史差分只在部分输入出现时：

1. 不把旧 mismatch 计数当作固定单元测试期望；
2. 批量枚举历史冻结输入并记录每个分支的差异方向；
3. 用首差的“有效/拒绝”类别选择投影、采样或代价算术审计路线；
4. 为目标 PTX 建立寄存器 def-use 和逐操作 DAG，不依赖高层变量命名；
5. 最小修改单个 camera 分支，并用其他 family 做保护性回放；
6. 最后用冻结旧正式二进制做同输入 A/B，避免跨阶段 artifact 归因；
7. 若原生样例参数退化导致修复 inert，报告覆盖缺口而不是制造指标收益。

## 进化动作

- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档
- [x] 新增了 pitfalls 记录
- [ ] 无需更新

## 环境信息

- OS: Linux x86-64
- 工具版本: CMake/Ninja、CUDA source/PTX 双后端、冻结状态 replay、SHA-256 产品比较
- 目标平台/版本: Linux x86-64 摄影测量应用，CUDA PatchMatch，Spherical central camera

## 脱敏要求

本记录仅保留公开产品类别、camera type、通用位型和方法。工作区、目标与捕获路径均
使用占位符；无真实域名、IP、凭证、身份信息或私有样本。

## 索引同步

已同步 `_index.md` 的场景分类、高频技术模式、实体倒排和累计统计。

---
<!-- [进化统计] 本包累计完成项目: 22 | 本次新增模式: 1 | 本次修复工具链问题: 0 -->
<!-- [社区贡献] 完成后询问用户是否 PR 到主仓库。流程见 CONTRIBUTE-BACK.md -->
