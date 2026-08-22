> **reverse-skill adapter** - AGS `mobile-security` under PRIMARY `game-security/` (routing **R43**). Not a second PRIMARY.
>
> **Gates that already exist (do not add more here):** reverse-skill `case-init` / `auth.status=granted` before ACT; AGS Ethical Use / authorized-testing text in this file if the upstream skill has it.
> **Handoff:** unpack first -> ``apk-reverse/`` (Android) or ``mobile-reverse/`` (iOS), then return here for game-specific IL2CPP/root/Zygisk catalog. Dump chain -> ``../il2cpp-dump.md``.
> **Fetch:** [fetch-upstream.md](fetch-upstream.md). Wiki: `wiki/overviews/mobile-security.md`.
> **Distill:** duplicated Data Source footer only. Taxonomy and workflows kept.
>
> Source: [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) (MIT, Copyright 2022 gmh).
---
name: mobile-security
description: Guide for Android and iOS game security, reversing, and anti-cheat-adjacent platform research. Use this skill when working with APK or IPA analysis, IL2CPP mobile titles, Frida, Zygisk or Magisk, jailbreak or root detection bypass, Android kernel modules, emulator detection, or mobile anti-cheat systems.
---

# Mobile Game Security

## Overview

This skill covers mobile security resources from the awesome-game-security collection, focusing on Android and iOS game security research, reverse engineering, and protection bypass techniques.

Mobile behavior is strongly version-, OEM-, entitlement-, signing-, kernel-,
and policy-dependent. Verify the exact device/build and use
[`research-rigor`](research-rigor.md) before treating a root, hook,
emulator, or integrity signal as attribution.

## README Coverage

- `Cheat > Magisk`
- `Cheat > Xposed`
- `Cheat > Frida`
- `Cheat > Hook ART(android)`
- `Cheat > Hook syscall(android)`
- `Cheat > Android Terminal Emulator`
- `Cheat > Android File Explorer`
- `Cheat > Android Memory Explorer`
- `Cheat > Android Application CVE`
- `Cheat > Android Kernel CVE`
- `Cheat > Android Bootloader Bypass`
- `Cheat > IoT / Smart devices`
- `Cheat > Android ROM`
- `Cheat > Android Device Trees`
- `Cheat > Android Kernel Source`
- `Cheat > Android Root`
- `Cheat > Android Kernel driver development`
- `Cheat > Android Kernel Explorer`
- `Cheat > Android Kernel Driver`
- `Cheat > Android Network Explorer`
- `Cheat > Android memory loading`
- `Cheat > IOS jailbreak`
- `Cheat > IOS Memory Explorer`
- `Cheat > IOS File Explorer`
- `Cheat > IOS App Packaging`
- `Cheat > Injection:Android`
- `Cheat > Injection:IOS`
- `Anti Cheat > Detection:Android root`
- `Anti Cheat > Detection:Magisk`
- `Anti Cheat > Detection:Frida`
- `Some Tricks > Android`
- `Android Emulator`
- `IOS Emulator`

## Android Security

### APK Analysis

#### Tools
- **apktool**: Decompile/recompile APKs
- **jadx**: DEX to Java decompiler
- **APKiD**: Identify packers/protectors
- **Frida**: Dynamic instrumentation
- **APKLab**: VS Code integration

#### Workflow
```bash
# Decompile APK
apktool d game.apk

# Analyze DEX files
jadx -d output game.apk

# Identify protection
apkid game.apk
```

### Native Library Analysis

#### IL2CPP Games (Unity)
```
1. Extract libil2cpp.so from APK
2. Use IL2CPP Dumper to generate headers
3. Analyze with IDA/Ghidra
4. Hook using Frida or native hooks
```

#### Native Games
```
1. Identify target libraries (.so files)
2. Analyze with reverse engineering tools
3. Pattern scan for functions
4. Apply hooks/patches
```

### Memory Manipulation

#### Tools
- **GameGuardian**: Memory editor
- **Cheat Engine (ceserver)**: Remote debugging
- **Custom memory tools**: Direct /proc/pid/mem access

#### Access Methods
```c
// Via /proc filesystem
int fd = open("/proc/pid/mem", O_RDWR);
pread64(fd, buffer, size, address);
pwrite64(fd, buffer, size, address);
```

### Hooking Frameworks

#### Frida
```javascript
// Basic function hook
Interceptor.attach(Module.findExportByName("libgame.so", "function_name"), {
    onEnter: function(args) {
        console.log("Called with: " + args[0]);
    },
    onLeave: function(retval) {
        retval.replace(0);
    }
});
```

#### Native Hooks
- **Substrate**: Inline hooking framework
- **And64InlineHook**: ARM64 inline hooks
- **xHook**: PLT hook library
- **Dobby**: Multi-platform hook framework

### Modern Root Solutions

#### KernelSU
```
- Kernel-based root solution, works at kernel level (no /system modification)
- Module system compatible with Magisk modules via KSU module API
- Stealth advantage: no su binary on filesystem, harder to detect
- Requires custom kernel or GKI (Generic Kernel Image) patching
- APatch: newer alternative, patches boot.img with KernelPatch
```

#### APatch
```
- Patches Android kernel at boot via KernelPatch
- No need for custom kernel source (works on stock GKI kernels)
- Module support similar to Magisk/KernelSU
- Root process runs within kernel context
```

#### Root Solution Comparison
```
| Solution  | Level       | Stealth | GKI Support | Module System |
|-----------|-------------|---------|-------------|---------------|
| Magisk    | User/Init   | Medium  | Yes         | Mature        |
| KernelSU  | Kernel      | High    | Yes         | Growing       |
| APatch    | Kernel      | High    | Yes         | Growing       |
```

### Managed Dynamic Instrumentation on Rooted Android
```
Methodology (KSU/Magisk module + single binary engine):
- Package injector + loader + agent into one ARM64 binary
  to reduce footprint and version mismatch risk
- Expose a local HTTP RPC control plane (127.0.0.1:<port>) for
  low-latency script management, session listing, and function calls
- Keep boot path safe: do NOT start instrumentation engine in
  post-fs-data/service early stage; use delayed manual start after
  boot_completed to avoid zygote/module startup contention

Injection modes:
- Attach: ptrace into running process, inject bootstrap shellcode,
  resolve libc symbols, dlopen agent, then run JS
- Spawn: zygote-hijack path to pause child at fork and inject before
  app initialization (covers Application.onCreate / class init)
- Watch-SO: eBPF-based dlopen monitor that triggers injection when
  target native library is loaded

Stealth tiers:
- NORMAL: direct RWX patching (fastest, easiest to detect)
- WXSHADOW: shadow-page patching to reduce /proc memory visibility
- RECOMP: function recompile/relocation with minimal inline patch

Operational pattern:
- Lifecycle commands: start/stop/restart/status
- Analysis mode: temporarily disable conflicting zygisk modules,
  reboot, instrument, then restore and reboot back to normal mode
- Troubleshooting-first logging: keep manager and engine logs separate
```

### Root Detection Bypass

#### Common Checks
```
- /system/bin/su existence
- /system/xbin/su existence  
- Build.TAGS contains "test-keys"
- ro.build.selinux property
- Magisk files/folders
- Package manager checks
```

#### Bypass Methods
- **Magisk DenyList / Shamiko**: Modern root hiding (replaces MagiskHide)
- **LSPosed/EdXposed**: Xposed framework hooks
- **Frida scripts**: Hook detection functions
- **APK patching**: Remove detection code
- **KernelSU SU isolation**: Process-level root visibility control

### Zygisk Modules

```cpp
// Zygisk module structure
class Module : public zygisk::ModuleBase {
    void onLoad(zygisk::Api *api, JNIEnv *env) override {
        this->api = api;
        this->env = env;
    }
    
    void preAppSpecialize(zygisk::AppSpecializeArgs *args) override {
        // Before app loads
    }
    
    void postAppSpecialize(const zygisk::AppSpecializeArgs *args) override {
        // After app loads - inject here
    }
};
```

### Android Protections

#### Common Protectors
- **Tencent ACE**: Chinese market protection
- **AppSealing**: Commercial protection
- **DexGuard/ProGuard**: Obfuscation
- **Arxan**: Enterprise protection

## iOS Security

### Analysis Tools
- **Hopper**: Disassembler
- **IDA Pro**: Industry standard
- **class-dump**: Objective-C header extraction
- **Frida**: Dynamic instrumentation
- **Clutch/dumpdecrypted**: App decryption

### Jailbreak Tools
- **H5GG**: iOS cheat engine
- **Flex**: Runtime patching
- **Cycript**: Runtime manipulation
- **ceserver-ios**: Cheat Engine for iOS

### Hooking (Jailbroken)
```objc
// Using Logos (Theos)
%hook TargetClass
- (int)targetMethod:(int)arg {
    int result = %orig;
    return result * 2;  // Modify return
}
%end
```

### Non-Jailbreak Techniques
- **Sideloading**: Modified IPAs
- **Enterprise certificates**: Custom signing
- **AltStore**: Self-signing tool

## Unity Mobile Games

### IL2CPP Analysis
```
1. Locate libil2cpp.so (Android) or UnityFramework (iOS)
2. Find global-metadata.dat
3. Run IL2CPPDumper
4. Generate SDK/headers
5. Hook target functions
```

### Mono Analysis
```
1. Extract managed DLLs
2. Decompile with dnSpy/ILSpy
3. Modify and repackage
4. Or hook at runtime
```

### Common Targets
```
- Currency/coins values
- Player stats (health, damage)
- Inventory manipulation
- Premium unlocks
- Ad removal
```

## Unreal Mobile Games

### Analysis Approach
```
1. Identify UE version
2. Dump SDK using appropriate tool
3. Locate GObjects, GNames
4. Find target functionality
5. Apply memory patches or hooks
```

## Overlay Rendering (Android)

### Surface-Based
```cpp
// Native surface overlay
ANativeWindow* window = ANativeWindow_fromSurface(env, surface);
// Render using OpenGL ES or Vulkan
```

### ImGui Integration
- Zygisk + ImGui modules
- Surface hijacking
- Direct framebuffer access

## Network Analysis

### Tools
- **mitmproxy**: MITM proxy
- **Charles Proxy**: Traffic analysis
- **Frida SSL bypass**: Certificate pinning bypass

### Certificate Pinning Bypass
```javascript
// Frida universal SSL bypass
Java.perform(function() {
    var TrustManager = Java.registerClass({
        implements: [X509TrustManager],
        methods: {
            checkClientTrusted: function() {},
            checkServerTrusted: function() {},
            getAcceptedIssuers: function() { return []; }
        }
    });
    // Install custom TrustManager
});
```

## Anti-Cheat on Mobile

### Common Systems
- **Tencent ACE**: Chinese games
- **NetEase Protection**: NetEase games
- **Custom solutions**: Per-game implementations

### Detection Methods
```
- Root/jailbreak detection
- Frida detection
- Emulator detection
- Integrity checks
- Debugger detection
- Hook detection
```

### Bypass Strategies
```
1. Static analysis of detection code
2. Hook detection functions
3. Hide injection footprint
4. Timing attack consideration
5. Clean environment emulation
```

## eBPF-Based Tools

### Tracing & Hooking
```
- stackplz: eBPF-based stack trace tool for Android
- eDBG: eBPF-powered debugger for Android processes
- tracee: Aqua Security's eBPF runtime security tool (Linux/Android)
- eBPF hooking: attach to tracepoints, kprobes, uprobes without kernel module
```

### Advantages Over Traditional Approaches
```
- No kernel module compilation required (runs in eBPF VM)
- May work on compatible GKI kernels when BPF features, BTF, privileges,
  SELinux policy, lockdown state, and required attach points permit it
- Can avoid a custom kernel module, but programs, maps, links, helpers, and
  privileged loader activity still create an observable surface
- CO-RE improves portability across kernels with compatible BTF/type changes;
  it does not guarantee run-everywhere behavior
- The verifier rejects many unsafe programs and reduces risk, but verifier,
  helper, JIT, driver, and kernel bugs can still cause failures
```

## Android Kernel Driver Development

### Development Patterns
```
- Loadable kernel module (LKM) for older kernels
- GKI-compatible modules via vendor_dlkm partition
- Kernel build scripts: build from AOSP source or vendor BSP
- Device Trees: hardware description for board-specific drivers
```

### Common Use Cases in Game Security
```
- Process memory access: /dev/custom_mem → read/write target process
- Syscall hooking: __NR_read, __NR_write interception
- Binder hooking: intercept IPC transactions
- GPU memory inspection: access GPU buffers directly
```

### Android Kernel Source
```
- AOSP Common Kernel (ACK): google/common branch
- GKI: versioned Generic Kernel Image model; capabilities and module rules vary
  across Android releases and OEM implementations
- Vendor-specific: Qualcomm (CodeAurora), MediaTek, Samsung Exynos
- Build system: build/build.sh or Bazel-based (newer)
```

## HarmonyOS / OpenHarmony

```
- HarmonyOS (Huawei): abc file format for compiled apps
- arkdecompiler: decompile HarmonyOS abc bytecode
- OpenHarmony: open-source base, growing ecosystem
- Security model differs from Android: distributed capabilities
- Reverse engineering challenges: new bytecode VM, different IPC
```

## Android CVE Research

### Application-Level CVEs
```
- WebView RCE (CVE-based exploit chains)
- Intent redirection / deep link abuse
- Content provider data leaks
- Serialization vulnerabilities (Parcel, Bundle)
```

### Kernel-Level CVEs
```
- Use-after-free in Binder driver
- Privilege escalation via ion/DMA-BUF
- GPU driver vulnerabilities (Adreno, Mali, PowerVR)
- SELinux policy bypass chains
- Reference: Android Security Bulletins (monthly)
```

## Emulator Considerations

### Android Emulators
- **LDPlayer**: Gaming focused
- **BlueStacks**: Popular emulator
- **NoxPlayer**: Game optimization
- **MEmu**: Android gaming

### Emulator Detection
```
- Build.FINGERPRINT checks
- Hardware sensor verification
- File system characteristics
- Performance timing
```

## Resource Organization

The README contains:
- Android hooking frameworks
- iOS jailbreak tools
- Memory manipulation utilities
- Root/jailbreak bypass tools
- Mobile anti-cheat research
- Emulator resources

---
