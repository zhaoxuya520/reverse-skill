> **reverse-skill adapter** - AGS `windows-kernel-security` under PRIMARY `game-security/` (routing **R43**). Not a second PRIMARY.
>
> **Pin:** `gmh5225/awesome-game-security@bf403cf9e37f` (`bf403cf9e37f4c04f8c68a866fdd2a8f3054bfe2`). Refresh: `scripts/install-ags-refs.ps1`.
> **Gates that already exist (do not add more here):** reverse-skill `case-init` / `auth.status=granted` before ACT; AGS Ethical Use / authorized-testing text in this file if the upstream skill has it.
> **Handoff:** driver RE operations -> ``reverse-engineering/kernel-driver-reverse.md``. EDR-like AC analysis -> ``edr-bypass-re/``.
> **Fetch:** [fetch-upstream.md](fetch-upstream.md). Wiki: `wiki/overviews/windows-kernel.md`.
> **Distill:** duplicated Data Source footer only. Taxonomy and workflows kept.
>
> Source: [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) (MIT, Copyright 2022 gmh).
---
name: windows-kernel-security
description: Guide for Windows kernel internals and security mechanisms used in game protection and low-level research. Use this skill when working with drivers, IRQL-sensitive callbacks, EPROCESS, ETHREAD, MMVAD internals, IOCTL paths, DSE, PatchGuard, HVCI, PiDDBCache, MmUnloadedDrivers, or kernel memory inspection.
---

# Windows Kernel Security

## Overview

This skill covers Windows kernel internals that matter for game security research: object callbacks, process and image notifications, APC behavior, driver loading, trust enforcement, memory manager structures, and the bookkeeping anti-cheats inspect to detect hostile drivers or hidden executable code.

Treat undocumented structures, offsets, globals, and allocator internals as
build-specific. Verify them against symbols and runtime observations for the
exact Windows build; use [`research-rigor`](research-rigor.md) before
generalizing a PoC or forensic heuristic.

## README Coverage

- `Cheat > PatchGuard-related`
- `Cheat > Driver Signature enforcement`
- `Cheat > Windows Kernel Explorer`
- `Cheat > EFI Driver` (cross-reference with game-hacking skill)
- `Cheat > Vulnerable Driver`
- `Anti Cheat > Detection:Attach`
- `Anti Cheat > Detection:Hide`
- `Anti Cheat > Detection:Vulnerable Driver`
- `Anti Cheat > Detection:Spoof Stack`
- `Anti Cheat > Windows Ring3 Callback`
- `Anti Cheat > Windows Ring0 Callback`
- `Anti Cheat > Information System & Forensics`
- `Some Tricks > Windows Ring0`
- `Windows Security Features`

## Core Kernel Concepts

### Important Structures
- EPROCESS / ETHREAD
- KTHREAD / KAPC / KAPC_STATE
- MMVAD / VAD tree nodes
- PEB / TEB
- DRIVER_OBJECT
- DEVICE_OBJECT
- IRP (I/O Request Packet)

### Key Tables
- SSDT (System Service Descriptor Table)
- IDT (Interrupt Descriptor Table)
- GDT (Global Descriptor Table)
- PspCidTable (Process/Thread handle table)
- PiDDBCacheTable / MmUnloadedDrivers / PoolBigPageTable

## User-Mode Kernel Symbol Walking

### Methodology
```
- Load local ntoskrnl image (typically C:\Windows\System32\ntoskrnl.exe)
- Use dbghelp + symbol server path (srv*cache*https://msdl.microsoft.com/download/symbols)
  to resolve exported symbol RVAs and type information
- Build structure-aware field lookup:
  - Query field offset directly (e.g., _EPROCESS.Token)
  - Enumerate all members of a target struct (_TOKEN, _EPROCESS, etc.)
  - Search a field name across all known structs (useful when parent type is unknown)
- Keep symbol path configurable for offline/private symbol repositories
```

### Why It Matters in Game Security
```
- Reduces hardcoded-offset fragility across Windows builds
- Helps map kernel object layouts used by anti-cheat and drivers
- Supports rapid adaptation when anti-cheat-relevant fields shift
  (EPROCESS, ETHREAD, token/handle/security-related members)
```

### Gadget Scanning Workflow
```
- Map executable sections of ntoskrnl image in user mode
- Scan for short control-flow gadgets (e.g., pop rcx ; ret, jmp rax)
- Use as a research primitive for:
  - ROP chain feasibility analysis
  - Kernel exploit mitigation evaluation
  - Anti-cheat hardening review against gadget-dependent attack paths
```

## Security Features

### PatchGuard (Kernel Patch Protection)
```
- Protects critical kernel structures
- Periodic verification checks
- BSOD on tampering detection
- Multiple trigger mechanisms
```

### Driver Signature Enforcement (DSE)
```
- Requires signed drivers
- CI.dll verification
- Test signing mode
- WHQL certification
```

### Virtualization-Based Security (VBS)
```
Architecture:
- Uses the Windows hypervisor to create an isolated execution environment
- Splits the system into Virtual Trust Levels (VTLs)
  - VTL0: Normal world — standard Windows kernel and user-mode processes
  - VTL1: Secure world — Secure Kernel, security policy enforcement
- VTL1 is designed to remain isolated from a compromised VTL0, assuming the
  hypervisor, secure kernel, hardware, and configuration path remain trustworthy
- Three main buckets:
  - Memory-protection features (HVCI)
  - Virtual Trust Levels (VTL0/VTL1 separation)
  - VBS enclaves (isolated execution for selected workloads)
```

### Hypervisor-Enforced Code Integrity (HVCI)
```
- Also known as Memory Integrity
- Ensures only trusted, validated code executes in kernel mode
- Combines Windows hypervisor + Secure Kernel (VTL1) for enforcement
- Key mechanism: W→X transition restriction
  - Enforced code pages are not intended to be writable from VTL0
  - Executability is granted only after the configured code-integrity checks
- Enforcement pipeline:
  - Code integrity policy defines what is trusted
  - Hypervisor memory enforcement via second-stage address translation (EPT/SLAT)
  - Once a kernel page is validated, strict execution rules are enforced
- Driver compatibility requirements: drivers must be HVCI-compatible
```

### Secure Boot
```
- UEFI-based boot verification
- Boot loader chain validation
- Kernel signature checks
- DBX (forbidden signatures)
- Foundation for attestation and DMA-hardening assumptions
```

## Kernel Callbacks

### Process Callbacks
```cpp
PsSetCreateProcessNotifyRoutine
PsSetCreateProcessNotifyRoutineEx
PsSetCreateProcessNotifyRoutineEx2
```

### Thread Callbacks
```cpp
PsSetCreateThreadNotifyRoutine
PsSetCreateThreadNotifyRoutineEx
```

### Image Load Callbacks
```cpp
PsSetLoadImageNotifyRoutine
PsSetLoadImageNotifyRoutineEx
```

### Object Callbacks
```cpp
ObRegisterCallbacks
// OB_OPERATION_HANDLE_CREATE
// OB_OPERATION_HANDLE_DUPLICATE
```

### APC / Execution Context
```cpp
KeInitializeApc
KeInsertQueueApc
KeStackAttachProcess
RtlWalkFrameChain
```

### Registry Callbacks
```cpp
CmRegisterCallback
CmRegisterCallbackEx
```

### Minifilter Callbacks
```cpp
FltRegisterFilter
// IRP_MJ_CREATE, IRP_MJ_READ, etc.
```

## Driver Development

### Basic Structure
```cpp
NTSTATUS DriverEntry(
    PDRIVER_OBJECT DriverObject,
    PUNICODE_STRING RegistryPath
) {
    DriverObject->DriverUnload = DriverUnload;
    DriverObject->MajorFunction[IRP_MJ_CREATE] = DispatchCreate;
    DriverObject->MajorFunction[IRP_MJ_DEVICE_CONTROL] = DispatchIoctl;
    // Create device, symbolic link...
    return STATUS_SUCCESS;
}
```

### Communication Methods
- IOCTL (DeviceIoControl)
- Direct I/O
- Buffered I/O
- Shared memory

## Vulnerable Driver Exploitation

### Common Vulnerability Types
- Arbitrary read/write primitives
- IOCTL handler vulnerabilities
- Pool overflow
- Use-after-free

### Notable Vulnerable Drivers
```
- gdrv.sys (Gigabyte)
- iqvw64e.sys (Intel)
- MsIo64.sys
- Mhyprot2.sys (Genshin Impact)
- dbutil_2_3.sys (Dell)
- RTCore64.sys (MSI)
- Capcom.sys
```

### Exploitation Steps
1. Load vulnerable signed driver
2. Trigger vulnerability
3. Achieve kernel read/write
4. Disable DSE or load unsigned driver
5. Execute arbitrary kernel code

## PatchGuard Bypass Techniques

### Timing-Based
- Predict PG timer
- Modify between checks

### Context Manipulation
- Exception handling
- DPC manipulation
- Thread context tampering

### Hypervisor-Based
- EPT manipulation
- Memory virtualization
- Intercept PG checks

## Kernel Hooking

### ETW (Event Tracing for Windows)
```
- InfinityHook technique
- HalPrivateDispatchTable
- System call tracing
```

## ETW Internals

### Provider / Consumer Model
```
Architecture:
- Providers: kernel or user-mode components that emit events
  - Manifest-based providers (registered via wevtutil)
  - TraceLogging providers (self-describing, no manifest)
  - MOF providers (legacy WMI-based)
- Consumers: tools that subscribe to and process events
  - Real-time consumers (ETW sessions)
  - Log file consumers (.etl files)
- Controllers: manage sessions (xperf, tracelog, logman)

Key kernel providers:
  Microsoft-Windows-Kernel-Process (process/thread lifecycle)
  Microsoft-Windows-Kernel-File (file I/O)
  Microsoft-Windows-Kernel-Audit-API-Calls (security-sensitive APIs)
```

### ThreatIntel ETW Provider
```
- Microsoft-Windows-Threat-Intelligence
- Available to PPL (Protected Process Light) and above
- Events: NtReadVirtualMemory, NtWriteVirtualMemory, NtMapViewOfSection on protected processes
- Used by EDR and anti-cheat for detecting memory access to protected processes
- Attackers target: patch EtwThreatIntProvRegHandle or EtwpEventWriteFull
```

### Common ETW Bypass Patterns
```
- Patch EtwEventWrite in ntdll.dll (user-mode ETW silencing)
- Patch nt!EtwpEventWriteFull in kernel (kernel-mode ETW silencing)
- NtSetInformationThread(ThreadHideFromDebugger) — hides thread from ETW
- Remove provider registration by walking EtwRegistration list
- EPT-based protection can defend ETW structures from tampering
```

## Kernel Segment Heap Architecture

### Timeline
```
Windows NT ~ 1809   : Legacy NT Pool Manager (ExAllocatePoolWithTag)
Windows 10 19H1     : Kernel Segment Heap introduced (March 2019, build 1903)
                      └─ User-mode Segment Heap ported to the kernel
Windows 10 2004     : ExAllocatePool2 / ExAllocatePool3 added
                      └─ ExAllocatePoolWithTag officially deprecated
Windows 10 20H2~    : Dynamic KDP (Kernel Data Protection) stabilized
Windows 11          : VBS/HVCI enabled by default; Secure Pool usage expanded

Common misconception: Many sources claim "the Segment Heap was introduced
in Windows 10 2004," but the kernel segment heap was actually introduced
in 19H1 (1903). Windows 10 2004 added the new Pool APIs built on top of it.
```

### Legacy NT Pool Structure (_POOL_HEADER, pre-19H1)
```
_POOL_HEADER (16 bytes, x64):
Offset  Field           Size   Description
0x00    PoolIndex        1 B    Pool descriptor index
0x01    PreviousSize     1 B    Previous chunk size
0x02    PoolType         1 B    Pool type (Paged, NonPaged, etc.)
0x03    BlockSize        1 B    Current chunk size (>> 4)
0x04    PoolTag          4 B    4-byte ASCII tag
0x08    ProcessBilled    8 B    KPROCESS pointer (valid only with PoolQuota)

Memory layout:
[POOL_HEADER 16B][user data ...][POOL_HEADER 16B][user data ...]
      ↑ plaintext, predictable        ↑ adjacent → overwritable

Security weaknesses:
- Pool Walking: traverse chunks linearly via BlockSize
- Pool Overflow: corrupt adjacent header for arbitrary write on free
- PoolIndex Overwrite: OOB dereference into pool descriptor array
- ProcessBilled Overwrite: arbitrary address dereference on free path

Windows 8 partial mitigation:
  ProcessBilled = KPROCESS_PTR ^ ExpPoolQuotaCookie ^ CHUNK_ADDR
  But plaintext _POOL_HEADER remained until 19H1.
```

### _SEGMENT_HEAP Core Structure
```
Each pool type is managed by its own independent _SEGMENT_HEAP instance.

_SEGMENT_HEAP (illustrative kernel offsets observed for 20H2; verify symbols):
0x000   EnvHandle (10 B)     — heap environment handle
0x010   Signature (4 B)      — commonly 0xDDEEDDEE on this layout
0x028   UserContext (8 B)
0x048   AllocatedBase (8 B)  — LFH structure allocation base
0x058   SegContexts[2] (0x180 B) — segment context array
0x100   VsContext (0xC0 B)   — VS allocator context
0x280   LfhContext (0x4C0 B) — LFH allocator context
higher  LargeAllocMetadata   — large allocation metadata
higher  LargeReservedPages / LargeCommittedPages

Per pool type instances (nt!PoolVector / HEAP_POOL_NODES):
├── NonPagedPool (NP)       → _SEGMENT_HEAP instance #1
├── NonPagedPoolNx (NPNx)   → _SEGMENT_HEAP instance #2  ← primary target
├── PagedPool (PP)          → _SEGMENT_HEAP instance #3
├── PagedPoolSession        → _SEGMENT_HEAP stored in current thread
└── (other special pools)
```

### Allocation Routing Flow
```
ExAllocatePoolWithTag / ExAllocatePool2 / ExAllocatePool3
        │
        ▼
  ExAllocateHeapPool (internal)
        │
        ├─ size ≤ 0x200 AND LFH activated  ──▶  kLFH
        │   └─ RtlpHpLfhContextAllocate
        │
        ├─ 0x1e1 ≤ size ≤ 0xfe0            ──▶  VS Allocator
        │   └─ RtlpHpVsContextAllocateInternal
        │
        ├─ page-aligned (0x20000~0x7f0000)  ──▶  Segment Allocator
        │   └─ RtlpHpSegAlloc
        │
        └─ large (> 0x7f0000)              ──▶  Large Allocator
            └─ RtlpHpLargeAlloc
```

### kLFH (Low Fragmentation Heap)
```
Size range:       ≤ 0x200 bytes (512 B), when LFH activated for that size class
Activation:       After 18 consecutive allocations of the same size
Key function:     RtlpHpLfhContextAllocate
Chunk header:     _POOL_HEADER (16 B, still present)
Metadata:         _HEAP_LFH_SUBSEGMENT (isolated, not inline)
Bucket count:     129 (Buckets[129])

Bucket structure:
_HEAP_LFH_CONTEXT
└── Buckets[129]
     ├── Bucket #0:   size 1~8 B
     ├── Bucket #1:   size 9~16 B
     ├── ...
     └── Bucket #128: size ~0x1FF B
         (each bucket has AffinitySlots → _HEAP_LFH_SUBSEGMENT)

Security properties:
- Block placement within subsegment is randomized
- Next allocation position managed through FreeHint, encoded with LfhKey
- Adjacent chunk overflow cannot directly corrupt management structure
```

### VS Allocator (Variable Size)
```
Size range:       (a) ≤ 0x1e0 && LFH inactive; (b) 0x1e1~0xfe0;
                  (c) 0x1001~0xffff && non-page-aligned
Key function:     RtlpHpVsContextAllocateInternal
Chunk header:     _HEAP_VS_CHUNK_HEADER (16 B, HeapKey XOR encoded)
Free management:  Red-Black Tree (FreeChunkTree)
Algorithm:        Best-fit

_HEAP_VS_CHUNK_HEADER (allocated state):
┌──────────────────────────────────────────────────────────┐
│  Sizes (8 B) — XOR encoded: HeaderBits ^ self_addr ^ HeapKey
│    ├─ UnsafeSize      : chunk size / 16
│    ├─ UnsafePrevSize  : previous chunk size / 16
│    ├─ MemoryCost      : pages occupied
│    └─ UnusedBytes     : whether unused bytes exist
│  EncodedSegmentPageOffset (1 B)
│    — (self_addr ^ self ^ HeapKey) & 0xFF
│    — page distance to VS subsegment start
└──────────────────────────────────────────────────────────┘

Memory layout:
[_HEAP_VS_CHUNK_HEADER 16B][_POOL_HEADER 16B][user data ...]
       ↑ HeapKey XOR             ↑ PoolTag etc. still present

VS subsegment structure (_HEAP_VS_SUBSEGMENT):
├── ListEntry      — subsegment linked list
├── CommitBitmap   — page commit state bitmap
├── CommitLock     — lock used during commit
├── Size (2 B)     — subsegment size (>> 4)
└── Signature (15 bit) + FullCommit (1 bit) — integrity check
```

### Segment Allocator (Backend)
```
Size range #1:    0x20000 < size ≤ 0x7f000 (128 KB ~ 508 KB)
Size range #2:    0x7f000 < size ≤ 0x7f0000 (508 KB ~ ~7 MB)
Core structure:   _HEAP_PAGE_SEGMENT + 256 page descriptors
Segment mask:     0xFFFFFFFFFFF00000

The kernel uses two independent SegContexts (unlike user-mode's single context).

Page segment signature encoding:
check = page_segment ^ page_segment->Signature
      ^ 0xA2E64EADA2E64EAD ^ RtlpHpHeapGlobals.HeapKey
```

### Large Allocator
```
Size range:       > 0x7f0000 (typically page-aligned)
Key function:     RtlpHpLargeAlloc
Metadata:         _SEGMENT_HEAP.LargeAllocMetadata
Tracking:         BigPagePoolTable (PoolTrackTable)
No inline header; metadata recorded externally.
```

### Header Layout Per Allocation Path
```
Path          Memory layout (chunk start → user data)
────────────────────────────────────────────────────────────────
kLFH          [_POOL_HEADER 16B] [data]
VS            [_HEAP_VS_CHUNK_HEADER 16B] [_POOL_HEADER 16B] [data]
Segment       [_HEAP_PAGE_SEGMENT header] ... [page descriptors]
Large         Metadata in BigPagePoolTable; no inline header
CacheAligned  [_POOL_HEADER #1] ... [_POOL_HEADER #2 (CacheAligned)] [data]
```

### Residual _POOL_HEADER Under Segment Heap
```
_POOL_HEADER was not fully removed. Remaining usage:

Field           Status under Segment Heap
PoolTag         Still recorded (for debugging/tracing)
PoolType        Recorded, not used for allocator selection on free
BlockSize       Unused in VS path; still present in kLFH
PreviousSize    Unused, set to 0
PoolIndex       Unused, set to 0
ProcessBilled   Valid only with PoolQuota flag (encoded with ExpPoolQuotaCookie)
```

### Pointer Encoding Mechanisms
```
Global key structure: _RTLP_HP_HEAP_GLOBALS (nt!RtlpHpHeapGlobals)
Generated randomly at boot time; global in ntoskrnl.

{
    UINT64 HeapKey;   // VS Allocator + Segment Allocator header encoding
    UINT64 LfhKey;    // LFH callback pointer encoding
}

Encoding formulas:

VS chunk header — Sizes field:
  encoded = (real Sizes) ^ (address of vs_chunk_header) ^ HeapKey

VS chunk — EncodedSegmentPageOffset:
  encoded = ((real page distance) ^ vs_chunk_header ^ HeapKey) & 0xFF

Segment context signature:
  check = page_segment ^ page_segment->Signature
        ^ 0xA2E64EADA2E64EAD ^ HeapKey

LFH callback function pointer:
  encoded = real function address ^ HeapKey ^ address of LfhContext

ProcessBilled (POOL_HEADER, Windows 8+):
  encoded = KPROCESS_PTR ^ ExpPoolQuotaCookie ^ CHUNK_ADDR

Implications for attackers:
- Must leak HeapKey and LfhKey from RtlpHpHeapGlobals
- Must know chunk's own virtual address (self-referential XOR)
- Failing encoding validation triggers:
  BugCheck 0x139 (KERNEL_SECURITY_CHECK_FAILURE) or
  BugCheck 0x13A (KERNEL_MODE_HEAP_CORRUPTION)
```

### Dynamic Lookaside and Delay Free
```
Dynamic Lookaside:
_HEAP_VS_CONTEXT
└── Lookaside buckets (_RTL_DYNAMIC_LOOKASIDE)
     ├── Per-size singly-linked lists
     ├── Depth (2 B)     — current list depth
     └── NextEntry (8 B) — pointer to next cached chunk

Rebalancing (every 3 Balance Set Manager scans):
- alloc count < 25 → Depth decreases by 10
- miss ratio ≥ 0.5% → Depth increases
- miss ratio < 0.5% → Depth decreases by 1
- Range: minimum 4 ~ MaximumDepth

Delay Free (VS Allocator):
- size < 1 KB AND Config.Flags bit 4 == 1:
  → stored in DelayFreeContext list
  → batch freed after 32 entries accumulate
- Otherwise: inserted immediately into FreeChunkTree
- Security: disrupts UAF timing (cannot immediately reuse freed chunk)
```

### New Pool APIs: ExAllocatePool2 / ExAllocatePool3
```
Evolution:
ExAllocatePool                 (legacy, no tag)
ExAllocatePoolWithTag          (pre-19H1 standard, deprecated in 2004)
ExAllocatePoolWithTagPriority  (priority support)
ExAllocatePoolWithQuotaTag     (quota tracking)
        ↓
ExAllocatePool2                (general case, zero-initialized by default)
ExAllocatePool3                (extended parameters, priority + Secure Pool)

ExAllocatePool2:
  PVOID ExAllocatePool2(POOL_FLAGS Flags, SIZE_T NumberOfBytes, ULONG Tag);
  - Zero-initialized by default (no RtlZeroMemory needed)
  - Returns NULL on failure by default
  - POOL_FLAG_RAISE_ON_FAILURE converts to exception
  - POOL_FLAG_USE_QUOTA integrates legacy PoolQuota

ExAllocatePool3:
  PVOID ExAllocatePool3(POOL_FLAGS Flags, SIZE_T NumberOfBytes, ULONG Tag,
                        PCPOOL_EXTENDED_PARAMETER ExtendedParameters, ULONG Count);
  Extended parameter types:
  - PoolExtendedParameterPriority: allocation priority (e.g., HighPoolPriority)
  - PoolExtendedParameterSecurePool: KDP Secure Pool (VTL0 write-protected)

Down-level compatibility:
  #define POOL_ZERO_DOWN_LEVEL_SUPPORT
  ExInitializeDriverRuntime(DriversRuntimeInitSupportFlags);
  → ExAllocatePool2 internally falls back to alloc + memset on older OS
```

### Kernel Data Protection (KDP) and Secure Pool
```
KDP leverages Segment Heap's Secure Pool feature to allocate
kernel memory whose ordinary VTL0 writes are blocked while the VTL1 policy,
hypervisor, and configuration path remain trustworthy.

Illustrative implementation layout (verify on the target build):
  Dedicated Secure Pool region (reported as one PML4 entry on relevant builds)
  Base address: randomized at boot
  Managed by: Secure Kernel (VTL1)
  VTL0 writes: blocked via NAR (Node Address Range)

Initialization flow:
1. NT Memory Manager boot Phase 1
2. Randomly calculate 512 GB Secure Pool virtual address
3. INITIALIZE_SECURE_POOL Secure Call → Secure Kernel
4. Secure Kernel creates NAR + initializes NTE (Node Table Entry)

Anti-cheat usage:
  // Create Secure Pool context
  ExCreatePool(POOL_FLAG_NON_PAGED, tag, &securePoolHandle);

  // Allocate detection rule table (immutable after init)
  POOL_EXTENDED_PARAMS_SECURE_POOL sp = {
      .Cookie           = MY_COOKIE,
      .SecurePoolHandle = securePoolHandle,
      .Buffer           = &detectionRuleTable,
      .SecurePoolFlags  = SECURE_POOL_FLAGS_FREEABLE
      // MODIFIABLE flag omitted → write-protected after init
  };
  g_DetectionRules = ExAllocatePool3(POOL_FLAG_NON_PAGED,
      sizeof(detectionRuleTable), 'DRul', &extParams, 1);
  // Protected from ordinary VTL0 writes while KDP policy remains intact
```

### Attack Technique Evolution (Segment Heap Era)
```
Technique comparison:
Technique                    NT Pool (pre-19H1)    Segment Heap (19H1+)
─────────────────────────────────────────────────────────────────────────
Adjacent header overwrite    Direct metadata       Encoding/cookies complicate use
Pool Walking                 Legacy linear walk    Path-specific metadata/symbols needed
ProcessBilled overwrite      Requires Win8+ cookie Requires cookie + HeapKey
kLFH pool spray              Predictable           Possible but needs precise control
VS FreeChunkTree corruption  N/A                   Requires HeapKey bypass
Large chunk BigPool tracking PoC exists             PoC exists (PoolTrackTable)

Modern kLFH exploit requirements:
1. Find target object of same size (same kLFH bucket)
2. Target must contain exploitable members (pointer, function table)
3. Target allocation must be triggerable from user mode
4. Vulnerable and target objects must be in same pool type
   (NonPagedPoolNx and PagedPool use separate _SEGMENT_HEAP instances)

VS chunk overflow recovery (must restore to avoid BugCheck):
  ghost_chunk->Sizes.HeaderBits =
      (real_sizes) ^ (ULONG_PTR)ghost_chunk ^ HeapKey;
  ghost_chunk->EncodedSegmentPageOffset =
      ((real_page_offset) ^ (ULONG_PTR)ghost_chunk ^ HeapKey) & 0xFF;
  // Failure → BugCheck 0x13A

Required pre-exploit leak values:
Symbol                          Purpose               Source
nt!RtlpHpHeapGlobals           HeapKey, LfhKey        Pattern scan ExFreePoolWithTag
nt!ExpPoolQuotaCookie           Decode ProcessBilled   Pattern scan ExAllocatePoolWithQuotaTag
nt!PsInitialSystemProcess      EPROCESS chain         ntoskrnl import analysis
Chunk's own virtual address    Self-referential XOR   Requires info-leak primitive
```

### BugCheck Codes (Segment Heap Related)
```
Code    Name                               Trigger
0x139   KERNEL_SECURITY_CHECK_FAILURE      VS/LFH header integrity check failure
0x13A   KERNEL_MODE_HEAP_CORRUPTION        Heap metadata corruption detected
0xC5    DRIVER_CORRUPTED_EXPOOL            Pool accessed at incorrect IRQL
0x19    BAD_POOL_HEADER                    _POOL_HEADER validation failure (LFH path)
```

## Pool Allocation & Forensics

### Pool Forensics Artifacts
```
PiDDBCacheTable:
- Tracks historically loaded drivers by hash + timestamp
- Anti-cheat inspects this to detect BYOVD or test-signed driver loads
- Attackers attempt to remove entries post-load

MmUnloadedDrivers:
- Circular buffer of recently unloaded drivers (name + address range)
- Cannot be cleared from user mode
- Anti-cheat uses to detect load-unload-reload patterns

PoolBigPageTable:
- Maps large pool allocations (>= PAGE_SIZE) to owning driver tag
- Used for: identifying hidden drivers, finding leaked pool allocations
- Anti-cheat walks this to detect manually mapped driver memory
```

### Pool Tag Forensics
```
- ExAllocatePoolWithTag / ExAllocatePool2: every allocation carries a 4-byte tag
- Pool tag scanning: identify driver presence by known tags
- Tool: pooltag.txt (Microsoft), PoolMon, WinDbg !poolfind
- Anti-cheat technique: scan pool tags for known cheat driver signatures
```

### Modern Pool Scanning (Segment Heap Era)
```
Legacy method (pre-19H1) — NO LONGER WORKS:
  Follow BlockSize in inline header to traverse linearly.
  PPOOL_HEADER h = startAddr;
  while (h->BlockSize != 0) {
      if (h->PoolTag == TARGET_TAG) { /* ... */ }
      h += h->BlockSize;  // Invalid under segment heap
  }

Modern alternatives:

BigPool detection (Large Alloc path):
  Reference nt!PoolBigPageTable (or nt!PoolTrackTable)
  └─ Traverse BigPagePoolTable entries
  └─ Find allocations without corresponding driver objects

Small allocation detection:
  _SEGMENT_HEAP → VsContext → SubsegmentList traversal
  _SEGMENT_HEAP → LfhContext → Buckets[] → AffinitySlots → Subsegments

VS Chunk Header decoding (requires HeapKey):
  real_sizes = encoded_header ^ chunk_address ^ HeapKey
  → Decode to determine chunk size, PoolTag, allocation legitimacy

Anti-cheat scanning targets:
- Suspicious PoolTags: cheat drivers use custom/rare tags; maintain blacklist
- Executable permission pages: NonPagedPool chunks with X permission
  from suspicious sources (no corresponding loaded module)
- Shellcode patterns: scan decoded chunk contents for known cheat signatures,
  ROP gadgets, specific syscall sequences
- kLFH allocation pattern anomalies: unusual allocation patterns in
  specific size buckets can indicate pool grooming

WinDbg commands:
  dt nt!_RTLP_HP_HEAP_GLOBALS nt!RtlpHpHeapGlobals  // HeapKey, LfhKey
  dt nt!_SEGMENT_HEAP <address>
  dt nt!_HEAP_VS_CHUNK_HEADER <address>
  dt nt!_HEAP_LFH_CONTEXT <address>
  !pool <address>
  !poolfind <Tag> [pool_type]
  !poolused [flags]                    // stats by PoolTag
  dt nt!_POOL_TRACKER_BIG_PAGES nt!PoolBigPageTable

VS chunk header decode (manual):
  HeaderBits_raw = poi(<chunk_addr>)
  real Sizes = HeaderBits_raw ^ <chunk_addr> ^ HeapKey
```

### Driver Development Migration Checklist
```
□ ExAllocatePoolWithTag          → ExAllocatePool2
□ ExAllocatePool (without tag)   → Remove or ExAllocatePool2
□ ExAllocatePoolWithTagPriority  → ExAllocatePool3 + Priority param
□ ExAllocatePoolWithQuotaTag     → ExAllocatePool2 + POOL_FLAG_USE_QUOTA
□ RtlZeroMemory after alloc     → Remove (ExAllocatePool2 zero-initializes)
□ Review POOL_FLAG_RAISE_ON_FAILURE (NULL check vs exception)
□ Critical read-only data       → ExAllocatePool3 + Secure Pool
```

### SSDT Hooking (Legacy)
```
- Modify service table entries
- Requires PG bypass
- High detection risk
```

### IRP Hooking
```
- Hook driver dispatch routines
- Less monitored than SSDT
- Per-driver targeting
```

## Memory Manipulation

### Physical Memory Access
```cpp
MmMapIoSpace
MmCopyMemory
\\Device\\PhysicalMemory
```

### Virtual Memory
```cpp
ZwReadVirtualMemory
ZwWriteVirtualMemory
KeStackAttachProcess
MmCopyVirtualMemory
```

### MDL Operations
```cpp
IoAllocateMdl
MmProbeAndLockPages
MmMapLockedPagesSpecifyCache
```

## Research Tools

### Analysis
- WinDbg / WinDbg Preview
- Process Hacker / System Informer
- OpenArk
- WinArk

### Utilities
- KDU (Kernel Driver Utility)
- OSR Driver Loader
- DriverView

### Monitoring
- Process Monitor
- API Monitor
- ETW consumers

## EFI/Boot-Time Threats

### EFI Driver Cross-Reference
```
The README's > EFI Driver subcategory (under Cheat) contains 30+ projects:
- EFI bootkit frameworks: UEFI DXE drivers that persist across boots
- Boot-time memory mappers: inject code before Windows kernel initializes
- ExitBootServices hooks: intercept Windows boot handoff
- EFI runtime service abuse: GetVariable/SetVariable for kernel ↔ EFI comm

See also: game-hacking skill for EFI cheat workflows
```

### Boot-Time Access
```
- EFI runtime services persist after ExitBootServices
- DXE (Driver Execution Environment) phase: full hardware access
- Pre-kernel execution: no DSE, no PatchGuard, no HVCI enforcement
- Secure Boot is the primary mitigation (firmware signature verification)
```

### Memory Access
```
- GetVariable/SetVariable: pass data between EFI and OS runtime
- Runtime memory mapping via EFI memory map
- Physical memory access before Windows memory manager initializes
- ACPI table injection for persistent low-level modifications
```

## Hypervisor Development

### Hypervisor Types
```
Type 1 (bare-metal):
- Runs directly on hardware
- Examples: VMware ESXi, Microsoft Hyper-V, Xen
- Used for VBS, production security enforcement

Type 2 (hosted):
- Runs on top of a host operating system
- Examples: Oracle VirtualBox, VMware Workstation
- Common for research, development, and testing
```

### Hardware Virtualization Platforms
```
Intel VT-x:
- Introduced 2005, widely supported on modern Intel CPUs
- Foundation for VMCS, EPT, VM exits

AMD-V (SVM):
- AMD's counterpart to VT-x, also introduced 2005
- VMCB structure, NPT (Nested Page Tables)

ARM Virtualization Extensions:
- EL2 (hypervisor mode) and stage-2 memory translation
- Used on ARM platforms for mobile and embedded security
```

### Intel VT-x Core Concepts

#### VMCS (Virtual Machine Control Structure)
```
Central data structure for Intel VT-x:
- Describes guest state, host state, and virtualization controls
- Tells the processor:
  - What state to restore on VM entry
  - What state to save on VM exit
  - Which events transfer control back to the hypervisor

Guest/Host State Areas:
- Control registers (CR0, CR3, CR4)
- Segment registers (CS, SS, DS, ES, FS, GS)
- Debug registers (DR7 — hardware breakpoints)
- Descriptor-table registers (GDTR, IDTR)
- Key fields:
  - CR3: root of guest page tables, central to virtual memory
  - GDTR/IDTR: Global/Interrupt Descriptor Tables
  - CS/SS: code and stack segments
  - DR7: hardware breakpoint control

Control Fields:
- Pin-based controls
- Primary processor-based controls
- Secondary processor-based controls
- Events that cause VM exits:
  - CPUID interception
  - INVLPG interception
  - Control-register access
  - EPT violations
  - MSR access
```

#### EPT (Extended Page Tables)
```
Intel's implementation of SLAT (Second-Level Address Translation):
- Gives the hypervisor independent control over guest memory
- Two-stage address translation pipeline:
  1. GVA → GPA: Guest Virtual → Guest Physical (via guest page tables, rooted at CR3)
  2. GPA → HPA: Guest Physical → Host Physical (via EPT, rooted at EPTP in VMCS)
- Guest believes it owns its own memory mappings
- Hypervisor has a second, independent layer controlling:
  - What physical memory is reachable
  - What permissions apply (read/write/execute)

EPT Hierarchy:
- PML4 → PDPT → PD → PT (4-level page table)
- Each entry carries read/write/execute permissions
- EPT violations trigger VM exits when access permissions are violated

Page Table Entries (PTE):
- Maps GVA to GPA
- Carries: read/write, supervisor-only, caching, software-defined bits
- Guest PTEs and EPT serve different roles:
  - Guest PTE: controls guest's view of memory
  - EPT: controls hypervisor's view of the guest
```

#### VM Exits & VMCALL
```
VM Exits:
- Occur when configured events happen in the guest
- Triggers: CPUID, CR access, I/O instructions, EPT violations, MSR access
- On exit: processor saves guest state (per VMCS), restores host state,
  records exit reason for hypervisor handler

VMCALL:
- Guest intentionally transfers control to hypervisor
- Similar in concept to a system call (guest → hypervisor)
- Used for guest-hypervisor communication interfaces
```

#### Nested Virtualization
```
- Running a hypervisor inside a VM managed by another hypervisor
- Useful for research, testing, and development
- Adds complexity: multiple layers participate in the same virtualization flow
- Relevant for testing hypervisor-based defense under VMware/Hyper-V
```

### AMD-V (SVM)
- VMCB (Virtual Machine Control Block) structure
- NPT (Nested Page Tables) — AMD's SLAT equivalent
- SVM operations (VMRUN, VMSAVE, VMLOAD)

### Use Cases
- Memory hiding
- Syscall interception
- Security monitoring
- Anti-cheat evasion
- EPT-based memory protection and introspection

### Windows Hypervisor Platform (WHP) API
```
User-mode hypervisor interface (Windows 10+):
- WHvCreatePartition / WHvSetupPartition: create VM partition
- WHvCreateVirtualProcessor: add vCPU
- WHvMapGpaRange: map host memory into guest physical address space
- WHvRunVirtualProcessor: enter guest execution, blocks until VM exit
- WHvGetVirtualProcessorRegisters / Set: read/write guest CPU state

Key capability:
- Enables hypervisor-assisted analysis from user mode (no kernel driver)
- Page-level trap handling: set R/W/X permissions per guest page
- VM exit reasons: memory access violation, CPUID, MSR access, I/O port, syscall
- Controlled execution: the host controls modeled guest CPU state and mapped
  memory; external timing, devices, concurrency, and unmodeled dependencies
  still need explicit handling

Prerequisites:
- Enable Windows features: Microsoft-Hyper-V-Hypervisor + HypervisorPlatform
- Hardware: VT-x or AMD-V support
- Note: WHP coexists with Hyper-V but conflicts with some third-party hypervisors

See also: reverse-engineering skill → User-Mode Hypervisor-Assisted Tracing
for analysis workflows built on WHP
```

## Hypervisor-Based Defense

### Concept
```
- Security approach using virtualization primitives to enforce protections
  from a higher privilege level than the guest kernel
- Moves security decisions into an isolated execution environment
  that a compromised kernel cannot easily tamper with
- Present across major OS platforms:
  - Windows: Virtualization-Based Security (VBS)
  - Android: Android Virtualization Framework (AVF)
  - Apple: Secure execution environments, hardware-backed isolation
```

### EPT Hooks as Defensive Primitives
```
Mechanism:
- Instead of patching the guest kernel, modify EPT permissions
- Specific memory accesses trigger EPT violations → VM exit
- Hypervisor inspects the access and decides: allow, deny, or log

Example: Watching writes to a sensitive region
1. Remove write permission from the EPT entry for target region
2. Guest runs normally until it attempts a write to that region
3. EPT violation → VM exit → hypervisor receives control
4. Hypervisor evaluates context:
   - Which module performed the access
   - What memory was touched
   - Whether the access is authorized
5. Decision: allow write, deny and return, or log and continue

Advantages over traditional kernel hooks:
- Operate outside the guest OS
- Can remain effective after guest-kernel compromise if the hypervisor and
  policy/configuration channel remain trustworthy
- Avoid guest-kernel patching, although hypervisor presence and effects may be
  observable
- Ordinary guest-kernel writes cannot directly remove correctly enforced
  second-stage permissions
```

### Protectable Assets via EPT
```
- Executable pages of EPP (Endpoint Protection Platform) drivers
  → Prevents silent patching of security software
- ETW-related structures
  → Unauthorized writes fault into hypervisor
- Callback/callout/routine lists (PsSetCreateProcessNotifyRoutine, etc.)
  → Write authorization moved outside the guest kernel
- Critical kernel data structures
  → PatchGuard-protected regions, SSDT, IDT
```

### Threat Model for Hypervisor Defense
```
Assumes kernel compromise has already happened:
- Attacker has kernel code execution
- Attacker can load vulnerable drivers (BYOVD)
- Attacker can modify kernel memory
- Traditional kernel-resident protections are untrustworthy

Hypervisor advantage:
- Sits above the guest kernel in privilege hierarchy
- Enforces policies from a higher privilege layer
- Guest-kernel rootkits cannot directly rewrite hypervisor policy under the
  stated threat model; hypervisor vulnerabilities, DMA/SMM, configuration
  weaknesses, and hardware compromise remain separate attack paths
```

### Attack Scenario: BYOVD vs EPT Protection
```
Without hypervisor defense:
1. Attacker loads vulnerable signed driver
2. Gains kernel R/W primitives
3. Patches callback list to remove EPP callbacks
4. EPP is blinded — attacker operates undetected

With EPT-based defense:
1. Attacker loads vulnerable signed driver
2. Gains kernel R/W primitives
3. Attempts to patch callback list
4. EPT violation triggers VM exit
5. Hypervisor catches the write, evaluates context
6. Write is denied — callback list remains intact
```

## Resource Organization

The README contains categorized links for:
- PatchGuard research and bypasses
- DSE bypass techniques
- Vulnerable driver exploits
- Kernel callback enumeration
- ETW/PMI/NMI handlers
- Intel PT integration

---
