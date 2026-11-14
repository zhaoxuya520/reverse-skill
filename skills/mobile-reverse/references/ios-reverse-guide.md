# iOS 逆向工程专项

## IPA 获取与解密

```bash
# 从 App Store 下载
ipatool search "Target App"
ipatool purchase -b com.target.app
ipatool download -b com.target.app -o app.ipa

# 从设备提取已安装应用
# 越狱设备
scp root@device:/private/var/containers/Bundle/Application/*/Target.app .

# 解密（App Store 二进制为加密 FAT 格式）
# frida-ios-dump（推荐）
python3 dump.py com.target.app -o decrypted.ipa

# Clutch
Clutch -i  # 列出已安装
Clutch -d 1  # 解密第 1 个

# dumpdecrypted
DYLD_INSERT_LIBRARIES=dumpdecrypted.dylib /path/to/App
```

### 离线解密：fairplay-decrypt（16 字节账号凭据）

来源 <https://github.com/EthanArbuckle/fairplay-decrypt>，装在 `~/Developer/fairplay-decrypt`（Tom-MacM5 与 M4-32G-001 均已构建并自检通过）。

与 frida-ios-dump / Clutch 的区别：那两个**必须在越狱设备上跑、必须在设备上装载目标 App**；fairplay-decrypt 是**离线解包**，只要拿到该 App Store 账号的 16 字节 FairPlay 凭据，就能在 macOS/Linux 上直接解一个加密 IPA，不需要设备在场，也不用装载目标 App。

```bash
cd ~/Developer/fairplay-decrypt

# 一次性准备（已做，换机才需要）
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
make transform                     # 只编 C 变换器；make all 在只有 CommandLineTools 的机上会失败（见下）

# 解密
.venv/bin/python decrypt.py /path/to/encrypted.ipa /path/to/decrypted.ipa \
  --credential /path/to/credential.bin
```

要点：

- `credential.bin` 恰好 16 字节，对应**拥有该 App 的账号**，一个账号一份，跨 App 复用。
- 输出路径必须不存在，工具拒绝覆盖；输入输出不能同一个文件。
- 支持 SUPF v3/v5、SINF `priv` 448 字节与 440 字节（440 必须末 8 字节全零）、加密 arm64 slice。
- `decrypt.py` 靠同目录的 `transform`（C 变换器）+ `transform_const_data.bin` 跑页密钥派生，**这两个必须在项目根**，缺了报 `build transform executable and keep constant-data file`。
- 能解的是加密段（`cryptid` 非 0）的 arm64 页；已经是 cryptid=0 的二进制会被跳过，全部跳过时报 `no encrypted arm64 binaries`。

凭据获取（`credential-retrieval/`）需要**一台已配对、可 root SSH 的越狱设备**，外加 `idevice_id`、`iproxy`：

```bash
python3 credential-retrieval/retrieve.py --output-dir /path/to/new-dir   # 产出 credential.bin
```

该子模块要用 `xcrun --sdk iphoneos` 编 iOS 目标，**必须装完整 Xcode + `ldid`**（只有 CommandLineTools 时会 `CommonCrypto/CommonCryptor.h not found`；Tom-MacM5 与 M4-32G-001 目前都是这种状态，所以两台的 `make all` 会失败，`make transform` 正常）。所以：**解密随时可用，取凭据要有完整 Xcode + 越狱设备**。凭据在别处拿到的，直接喂 `--credential` 即可。

## Mach-O 分析

```bash
# 基本信息
otool -l TargetBinary | grep crypt    # 加密状态
otool -L TargetBinary                 # 动态库依赖
otool -hv TargetBinary                # 头部信息
jtool2 --pages TargetBinary           # 内存页信息

# Fat Binary 瘦身
lipo -info TargetBinary
lipo TargetBinary -thin arm64 -output TargetBinary_arm64

# 符号分析
nm -g TargetBinary                    # 导出符号
nm -a TargetBinary                    # 全部符号
swift-demangle <mangled_name>         # Swift 符号还原

# class-dump
class-dump -H TargetBinary -o headers/
# 导出 ObjC 类及方法声明到 headers/ 目录
```

## Objective-C 运行时分析

```text
消息传递机制：
objc_msgSend(id self, SEL op, ...)  →  动态方法派发
  ↓
运行时查找：
1. 类方法列表 cache
2. 类方法列表
3. 逐级父类查找
4. +resolveInstanceMethod / +resolveClassMethod
5. forwardingTargetForSelector
6. methodSignatureForSelector + forwardInvocation
```

### Frida ObjC Hook

```javascript
// Hook 实例方法
var hook = ObjC.classes.ClassName["- instanceMethod:"];
Interceptor.attach(hook.implementation, {
    onEnter: function(args) {
        // args[0] = self, args[1] = selector, args[2+] = method args
        console.log("self: " + new ObjC.Object(args[0]));
        console.log("arg: " + args[2].toInt32());
    }
});

// Hook 类方法
var hook = ObjC.classes.ClassName["+ classMethod:"];
Interceptor.attach(hook.implementation, { ... });

// 调用 ObjC 方法
var NSString = ObjC.classes.NSString;
var str = NSString.stringWithString_("test");
console.log(str.UTF8String());
```

## Swift 逆向

```text
Swift 名称修饰（Name Mangling）：
$s10ModuleName5ClassC6method3argSi_tF
  │ │         │     │ │      │  │   └─ 参数类型
  │ │         │     │ │      │  └───── 返回类型  
  │ │         │     │ │      └──────── 参数名
  │ │         │     │ └─────────────── 方法名
  │ │         │     └──────────────── 类名(长度+名称)
  │ │         └────────────────────── 模块名
  │ └──────────────────────────────── 标识符标识
  └────────────────────────────────── 全局标识

工具: swift-demangle, Hopper (自动还原)
```

## 越狱检测绕过

```text
检测方法分类：

1. 文件系统检查：
   □ /Applications/Cydia.app
   □ /var/lib/apt/
   □ /bin/bash
   □ /usr/sbin/sshd
   → Hook NSFileManager.fileExistsAtPath:

2. 沙箱逃逸检测：
   □ fork() 是否成功（沙箱内禁止）
   □ system() 调用
   → Hook fork → 返回 -1

3. Dyld 注入检测：
   □ _dyld_get_image_count > 限制值
   → 限制返回值在合理范围

4. Scheme 检测：
   □ cydia:// URL Scheme
   → Hook UIApplication.canOpenURL:

5. sysctl 检测：
   □ CTL_KERN/KERN_PROC/KERN_PROC_PID → kinfo_proc
   → Hook sysctl → 清空 p_flag P_TRACED 位
```

### Frida 统一绕过脚本

```javascript
// 文件检测绕过
var NSFileManager = ObjC.classes.NSFileManager;
var defaultManager = NSFileManager.defaultManager();
Interceptor.attach(defaultManager["- fileExistsAtPath:"].implementation, {
    onLeave: function(retval) {
        var path = ObjC.Object(args[2]).toString();
        if (path.includes("Cydia") || path.includes("apt") || 
            path.includes("sshd") || path.includes("bash")) {
            retval.replace(0); // false
        }
    }
});

// fork 绕过
Interceptor.replace(Module.findExportByName(null, "fork"), 
    new NativeCallback(function() { return -1; }, 'int', []));

// dyld 绕过
var _dyld_get_image_count = Module.findExportByName(null, "_dyld_get_image_count");
Interceptor.attach(_dyld_get_image_count, {
    onLeave: function(retval) {
        if (retval.toInt32() > 200) retval.replace(200);
    }
});
```

## 关键防护绕过清单

| 防护 | iOS 绕过方法 |
|------|-------------|
| App Store 加密 | frida-ios-dump / Clutch（设备在线）/ fairplay-decrypt（离线，需账号凭据） |
| SSL Pinning | Objection `ios sslpinning disable` / SSL Kill Switch 2 |
| 越狱检测 | Objection `ios jailbreak disable` / 自定义 Frida Hook |
| 反调试 (PT_DENY_ATTACH) | Frida 启动后注入 / debugserver |
| 完整性校验 | Hook MAC 检查 / 代码签名验证 |
| 反注入 | 修改 Mach-O 去除 __RESTRICT 段 |
| Swift 混淆 | swift-demangle + LLM 辅助语义恢复 |
| 屏幕截图防护 | Hook UIScreen.mainScreen.snapshotViewAfterScreenUpdates |

Source: OWASP MSTG, frida-ios-dump, The iPhone Wiki
