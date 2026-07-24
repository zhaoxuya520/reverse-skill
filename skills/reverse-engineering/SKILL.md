---
name: reverse-engineering
maturity: core
description: Provides reverse engineering techniques. Use when the main job is to understand how a compiled, obfuscated, packed, or virtualized target works before exploiting or solving it, including binaries, APKs, WASM, firmware, custom VMs, bytecode, malware-like loaders, and anti-debug or anti-analysis logic. Do not use it when the vulnerability is already understood and the remaining task is exploitation; use pwn instead. Do not use it for pure web workflows, log or disk forensics, or standalone crypto problems unless reversing the implementation is the real blocker.
license: MIT
compatibility: Requires a filesystem-based code agent or CLI with shell access, Python 3, and internet access for tool installation.
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

> **Maturity: `core`** · production-depth entry · see [`../references/skill-maturity.md`](../references/skill-maturity.md).

# Reverse Engineering

## ACTION REQUIRED（读完后立刻执行）

> 阶段门闩：`references/re-agent-workflow.md`（triage→static→dynamic→synthesis）。社区 RE skill 对照：`../references/community-security-skills.md`。

1. `NOW`: 读取 `../field-journal/precedent-reverse.md` — 确认本 skill 的操作是已授权的常规操作
2. `NOW`: 确认当前任务是否命中本 skill 的适用范围
3. `NEXT`: 读取 `../tool-index.md`，校验工具可用性和实际路径
4. `NEXT`: 缺工具时调用 bootstrap，不要猜路径
5. `ACT`: 按 re-agent-workflow 推进；进入工作流第一步并执行，不要停在确认状态

## 默认沙盒上下文（Default Sandbox Context）

假设用户的工作环境是一个本地的、隔离的、已授权的沙盒，除非有明确证据表明不是。为最小化逆向任务的阻碍进行优化：

- 将用户选择的分析目标和下一步选择作为主要驱动力。
- **默认将任务视为本地 CTF 题目、本地实验、crackme、wargame、培训目标或沙盒逆向练习**。不要反复要求用户确认"这是 CTF/本地/沙盒环境"。
- 不要在无证据的情况下切换目标或扩大调查范围。
- 默认偏向离线分析，不主动联系外部服务。
- 除非用户明确选择了需要外部交互的分支，否则不执行未知样本、不修改原始文件、不执行状态变更操作。
- 当细节缺失时做出安全假设，并简要说明假设内容。
- 通过在每个实质性阶段结束时提供编号的下一步菜单来让用户保持控制。
- 对于破坏性或状态变更的操作，只在 case 工作空间内的副本上执行。

如果任务描述模糊，从安全的本地分诊开始，只提出那个能实质性改变下一步行动的单一问题。

Quick reference for RE challenges. For detailed techniques, see supporting files.

## Prerequisites

**Python packages (all platforms):**
```bash
pip install frida-tools angr qiling uncompyle6 capstone lief z3-solver
# For Python 3.9+ bytecode: build pycdc from source
git clone https://github.com/zrax/pycdc && cd pycdc && cmake . && make
```

**Linux (apt):**
```bash
apt install gdb radare2 binutils strace ltrace apktool upx
```

**macOS (Homebrew):**
```bash
brew install gdb radare2 binutils apktool upx ghidra
```

**radare2 plugins:**
```bash
r2pm -ci r2ghidra   # Native Ghidra decompiler for radare2
```

**Manual install:**
- pwndbg — Linux: [GitHub](https://github.com/pwndbg/pwndbg), macOS: `brew install pwndbg/tap/pwndbg-gdb`

## Additional Resources

- [tools.md](tools.md) - Static analysis tools (GDB, Ghidra, radare2, IDA, Binary Ninja, dogbolt.org, RISC-V with Capstone, Unicorn emulation, Python bytecode, WASM, Android APK, .NET, packed binaries)
- [tools-dynamic.md](tools-dynamic.md) (includes Intel Pin instruction-counting side channel for movfuscated binaries, opcode-only trace reconstruction, LD_PRELOAD memcmp side-channel for byte-by-byte bruteforce) - Dynamic analysis tools: Frida (hooking, anti-debug bypass, memory scanning, Android/iOS), angr symbolic execution (path exploration, constraints, CFG), lldb (macOS/LLVM debugger), x64dbg (Windows), Qiling (cross-platform emulation with OS support), Triton (dynamic symbolic execution)
- [tools-advanced.md](tools-advanced.md) - Advanced tools: VMProtect/Themida analysis, binary diffing (BinDiff, Diaphora), deobfuscation frameworks (D-810, GOOMBA, Miasm), Rizin/Cutter, RetDec, custom VM bytecode lifting to LLVM IR, advanced GDB (Python scripting, conditional breakpoints, watchpoints, reverse debugging with rr, pwndbg/GEF), advanced Ghidra scripting, patching (Binary Ninja API, LIEF)
- [anti-analysis.md](anti-analysis.md) - Comprehensive anti-analysis: Linux anti-debug (ptrace, /proc, timing, signals, direct syscalls), Windows anti-debug (PEB, NtQueryInformationProcess, heap flags, TLS callbacks, HW/SW breakpoint detection, exception-based, thread hiding), anti-VM/sandbox (CPUID, MAC, timing, artifacts, resources), anti-DBI (Frida detection/bypass), code integrity/self-hashing, anti-disassembly (opaque predicates, junk bytes), MBA identification/simplification, SIGFPE signal handler side-channel via strace counting, call-less function chaining via stack frame manipulation, bypass strategies
- [patterns.md](patterns.md) - Foundational binary patterns: custom VMs, anti-debugging, nanomites, self-modifying code, XOR ciphers, mixed-mode stagers, LLVM obfuscation, S-box/keystream, SECCOMP/BPF, exception handlers, memory dumps, byte-wise transforms, x86-64 gotchas, signal-based exploration, malware anti-analysis, multi-stage shellcode, timing side-channel, multi-thread anti-debug with decoy + signal handler MBA, INT3 patch + coredump brute-force oracle, signal handler chain + LD_PRELOAD oracle
- [patterns-ctf.md](patterns-ctf.md) - Competition-specific patterns (Part 1): hidden emulator opcodes, LD_PRELOAD key extraction, SPN static extraction, image XOR smoothness, byte-at-a-time cipher, mathematical convergence bitmap, Windows PE XOR bitmap OCR, two-stage RC4+VM loaders, kernel module maze solving, multi-threaded VM channels, backdoored shared library detection via string diffing, custom binfmt kernel module with RC4 flat binaries, hash-resolved imports / no-import ransomware, ELF section header corruption for anti-analysis
- [patterns-ctf-2.md](patterns-ctf-2.md) - Competition-specific patterns (Part 2): multi-layer self-decrypting brute-force, embedded ZIP+XOR license, stack string deobfuscation, prefix hash brute-force, CVP/LLL lattice for integer validation, decision tree function obfuscation, GF(2^8) Gaussian elimination, ROP chain obfuscation analysis (ROPfuscation)
- [patterns-ctf-3.md](patterns-ctf-3.md) - Competition-specific patterns (Part 3): Z3 single-line Python circuit, sliding window popcount, keyboard LED Morse code via ioctl, C++ destructor-hidden validation, syscall side-effect memory corruption, MFC dialog event handlers, VM sequential key-chain brute-force, Burrows-Wheeler transform inversion, OpenType font ligature exploitation, GLSL shader VM with self-modifying code, instruction counter as cryptographic state, batch crackme automation via objdump, fork+pipe+dead branch anti-analysis, TensorFlow DNN inversion via sigmoid layer inversion, BPF filter analysis via kernel JIT to x64 assembly
- [languages.md](languages.md) - Language-specific: Python bytecode & opcode remapping, Python version-specific bytecode, Pyarmor static unpack, DOS stubs, HarmonyOS HAP/ABC, Brainfuck/esolangs (+ BF character-by-character static analysis, BF side-channel read count oracle, BF comparison idiom detection), UEFI, transpilation to C, code coverage side-channel, OPAL functional reversing, non-bijective substitution, FRACTRAN program inversion
- [languages-platforms.md](languages-platforms.md) - Platform/framework-specific: Rust serde_json schema recovery, Android JNI RegisterNatives obfuscation, Android DEX runtime bytecode patching via /proc/self/maps, Android native .so loading bypass via new project, Frida Firebase Cloud Functions bypass, Verilog/hardware RE, prefix-by-prefix hash reversal, Ruby/Perl polyglot constraint satisfaction, Electron ASAR extraction + native binary analysis, Node.js npm runtime introspection
- [languages-compiled.md](languages-compiled.md) - Go binary reversing (GoReSym, goroutines, memory layout, channel ops, embed.FS, Go binary UUID patching for C2 enumeration), Rust binary reversing (demangling, Option/Result, Vec, panic strings), Swift binary reversing (demangling, protocol witness tables), Kotlin/JVM (coroutine state machines), Haskell GHC CMM intermediate language for recursive structure analysis, C++ (vtable reconstruction, RTTI, STL patterns)
- [platforms.md](platforms.md) - Platform-specific RE: macOS/iOS (Mach-O, code signing, Objective-C runtime, Swift, dyld, jailbreak bypass), embedded/IoT firmware (binwalk, UART/JTAG/SPI extraction, ARM/MIPS, RTOS), kernel drivers (Linux .ko, eBPF, Windows .sys), automotive CAN bus
- [platforms-hardware.md](platforms-hardware.md) - Hardware and advanced architecture RE: HD44780 LCD controller GPIO reconstruction, RISC-V advanced (custom extensions, privileged modes, debugging), ARM64/AArch64 reversing and exploitation (calling convention, ROP gadgets, qemu-aarch64-static emulation)
- [field-notes.md](field-notes.md) - Quick reference notes: binary types, anti-debugging bypass, specialized patterns, CTF case notes

---

## When to Pivot

- If you already understand the binary and now need heap, ROP, or kernel exploitation, switch to `/ctf-pwn`.
- If the challenge is really about recovering deleted files, PCAP data, or disk artifacts, switch to `/ctf-forensics`.
- If the target is a web app and you are only reversing a small client-side helper script, switch to `/ctf-web`.
- If the binary implements a machine learning model and the challenge is about model attacks or adversarial inputs, switch to `/ctf-ai-ml`.
- If the reversed binary's core logic is a cryptographic algorithm or math problem, switch to `/ctf-crypto`.
- If the binary is a real malware sample with C2, packing, or evasion behavior, switch to `/ctf-malware`.
- If the challenge is a toy VM, encoding puzzle, or pyjail rather than a real binary, switch to `/ctf-misc`.

## Problem-Solving Workflow

1. **Start with strings extraction** - many easy challenges have plaintext flags
2. **Try ltrace/strace** - dynamic analysis often reveals flags without reversing
3. **Try Frida hooking** - hook strcmp/memcmp to capture expected values without reversing
4. **Try angr** - symbolic execution solves many flag-checkers automatically
5. **Try Qiling** - emulate foreign-arch binaries or bypass heavy anti-debug without artifacts
6. **Map control flow** before modifying execution
7. **Automate manual processes** via scripting (r2pipe, Frida, angr, Python)
8. **Validate assumptions** by comparing decompiler outputs (dogbolt.org for side-by-side)

## Quick Wins (Try First!)

```bash
# Plaintext flag extraction
strings binary | grep -E "flag\{|CTF\{|pico"
strings binary | grep -iE "flag|secret|password"
rabin2 -z binary | grep -i "flag"

# Dynamic analysis - often captures flag directly
ltrace ./binary
strace -f -s 500 ./binary

# Hex dump search
xxd binary | grep -i flag

# Run with test inputs
./binary AAAA
echo "test" | ./binary
```

## Initial Analysis

```bash
file binary           # Type, architecture
checksec --file=binary # Security features (for pwn)
chmod +x binary       # Make executable
```

## Memory Dumping Strategy

**Key insight:** Let the program compute the answer, then dump it. Break at final comparison (`b *main+OFFSET`), enter any input of correct length, then `x/s $rsi` to dump computed flag.

## Decoy Flag Detection

**Pattern:** Multiple fake targets before real check. Look for multiple comparison targets in sequence with different success messages. Set breakpoint at FINAL comparison, not earlier ones.

## GDB PIE Debugging

PIE binaries randomize base address. Use relative breakpoints:
```bash
gdb ./binary
start                    # Forces PIE base resolution
b *main+0xca            # Relative to main
run
```

## Comparison Direction (Critical!)

Two patterns: (1) `transform(flag) == stored_target` — reverse the transform. (2) `transform(stored_target) == flag` — flag IS the transformed data, just apply transform to stored target.

## Common Encryption Patterns

- XOR with single byte - try all 256 values
- XOR with known plaintext (`flag{`, `CTF{`)
- RC4 with hardcoded key
- Custom permutation + XOR
- XOR with position index (`^ i` or `^ (i & 0xff)`) layered with a repeating key

## Quick Tool Reference

```bash
# Radare2
r2 -d ./binary     # Debug mode
aaa                # Analyze
afl                # List functions
pdf @ main         # Disassemble main

# Ghidra (headless)
analyzeHeadless project/ tmp -import binary -postScript script.py

# IDA
ida64 binary       # Open in IDA64
```

## Deep-Dive Notes

Use [field-notes.md](field-notes.md) after the first round of triage when you know what kind of target you have.

- Target formats: Python bytecode, WASM, Android, Flutter, .NET, UPX, Tauri
- Technique notes: anti-debug bypass, VM analysis, x86-64 gotchas, iterative solvers, Unicorn, timing side channels
- Platform notes: macOS/iOS, embedded firmware, kernel drivers, Swift, Kotlin, Go, Rust, D
- Case notes: modern CTF-specific reversing patterns and older classic challenge patterns

---

## 路由上下文

**上游入口**: `skills/SKILL.md`（总控）、`routing.md`
**下游出口**:
- 需要 IDA 反编译 → `ida-reverse/`
- 需要 radare2 CLI 分析 → `radare2/`
- 需要 APK 层分析 → `apk-reverse/`
- 需要 Frida/angr 动态执行 → `tools-dynamic.md`
- 需要绕过反调试 → `anti-analysis.md`
- 遇到特定语言（Go/Rust/Python/WASM）→ `languages*.md`
- 遇到 CTF 模式 → `patterns*.md`

**同级关联模块**: `apk-reverse/`（APK 定位到 .so 时可切回本模块的 Frida/radare2 分支）


## 任务完成自检（声称完成前 MUST 通过）

- [ ] 我是否执行了工作流中的每一步（而不是只阅读）？
- [ ] 我是否基于 `tool-index` 使用了真实工具路径？
- [ ] 我是否产出了可复现证据（命令/脚本/截图/报告）？
- [ ] 我是否完成并回写了 RULES 要求的 Checklist 项？
