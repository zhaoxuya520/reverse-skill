# [种子] ELF 自解压加载器逆向

## 场景分类
二进制分析

## 目标概述
分析一个伪装成 .sh 脚本的 ARM64 ELF 自解压加载器，还原其解压算法和 payload 注入流程。

## 完整执行链路

1. `file` 命令确认真实类型（ELF，非 shell 脚本）
2. `readelf -l` 查看程序头 → 发现第 3 个 PHDR 被故意损坏（0x0a 填充）
3. `rabin2 -I` 获取架构（AArch64）、入口点、编译器信息
4. IDA/Ghidra 加载 → 从入口点开始分析
5. 识别出 LZSS 解压循环（位流操作 + 滑动窗口回拷）
6. 识别出 mmap → 解压 → mprotect → 跳转的注入流程
7. 用 Python 重写解压器，dump 出 payload
8. 分析 payload 内容（包含 /proc/self/exe 引用，说明是进程注入器）

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| readelf 报错无法解析 | 第 3 个 PHDR 被故意填充 0x0a | 忽略损坏的 PHDR，只看前 2 个 LOAD 段 | 10min |
| IDA 反编译结果不可读 | ARM64 位操作密集，Hex-Rays 优化不好 | 切到反汇编视图手动分析 | 30min |
| 解压器 Python 实现输出错误 | pop_bit refill 路径返回值搞错（adcs vs adds） | 仔细对照汇编，refill 时返回的是新加载字的 bit31 | 2h |
| 不确定 payload 入口偏移 | 数据表中 entry_offset 字段含义不明 | 跟踪 loader 函数的 `br mmap_base + 0x14`，确认入口在 +0x14 | 20min |

## 工具链发现

- `file` 命令是第一步，永远不要相信文件后缀
- `rabin2 -I` 比 `readelf` 更容错（能处理损坏的 PHDR）
- ARM64 位操作密集的代码，反编译器不如直接看汇编
- Python struct 模块 + 手写解压器是分析自定义压缩的标准方法

## 关键代码/命令

```bash
# 确认文件类型
file LinYuDriverLoader4.9.sh
# ELF 64-bit LSB executable, ARM aarch64

# 查看程序头
readelf -l binary 2>/dev/null | head -20

# 提取压缩数据
dd if=binary bs=1 skip=$((0xa6a24)) count=1981 of=compressed.bin

# 计算文件偏移
# vaddr 0x3d66bc → file_offset = 0x3d66bc - 0x330000 = 0xa66bc
```

```python
# LZSS 解压器核心（简化）
def decompress(data):
    shift_reg = 0x80000000
    # ... 位流读取 + 字面量/匹配分支
```

## 对本包的改进建议

- `elf-analysis.md` 应该加入"自定义压缩算法识别"的更多特征
- ARM64 syscall 表应该包含 cache 维护指令（dc cvau / ic ivau）的说明
- 建议加入"如何用 Python 重写汇编算法"的通用方法论

## 可复用的模式/脚本片段

**识别自解压 ELF 的标准模式**：
```text
入口点 → 少量初始化 → 调用解压函数 → mmap(RW) → 解压到 mmap 区域 → mprotect(RX) → 跳转
```

**ARM64 位流读取的通用模式**：
```text
lsl w4, w4, #1    # 左移（提取最高位到 carry）
cbz w4, refill    # 如果移空了，从输入加载新的 32 位
```

## 进化动作
- [x] 更新了子 skill 文档（elf-analysis.md 已新增）
- [ ] 无需更新路由矩阵
- [ ] 无需更新 bootstrap-manifest

## 环境信息
- OS: Linux/Android ARM64 目标
- 工具版本: IDA Pro / Ghidra + radare2
- 目标平台: Android ARM64 (AArch64)

## 脱敏要求
本条目为种子数据，基于公开技术模式编写，不涉及真实目标。

---
<!-- [进化统计] 本包累计完成项目: 1 | 本次新增模式: 2 | 本次修复工具链问题: 0 -->
<!-- [社区贡献] 种子数据，无需 PR -->
