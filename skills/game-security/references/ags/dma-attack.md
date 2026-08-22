> **reverse-skill adapter** - AGS `dma-attack-techniques` under PRIMARY `game-security/` (routing **R43**). Not a second PRIMARY.
>
> **Gates that already exist (do not add more here):** reverse-skill `case-init` / `auth.status=granted` before ACT; AGS Ethical Use / authorized-testing text in this file if the upstream skill has it.
> **Handoff:** defensive AC mapping -> ``anti-cheat.md``. Kernel/IOMMU -> ``windows-kernel.md`` + ``kernel-driver-reverse.md``.
> **Fetch:** [fetch-upstream.md](fetch-upstream.md). Wiki: `wiki/overviews/dma-attack.md`.
> **Distill:** duplicated Data Source footer only. Taxonomy and workflows kept.
>
> Source: [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) (MIT, Copyright 2022 gmh).
---
name: dma-attack-techniques
description: Guide for PCIe DMA threat modeling, FPGA-based memory access, and defensive implications in game security. Use this skill when researching pcileech, BAR and TLP behavior, page-table walking, IOMMU or VT-d, device impersonation, firmware mimicry, or DMA detection and mitigation in game security research.
---

# DMA Attack Techniques

## Overview

This skill covers Direct Memory Access research from the awesome-game-security collection, focusing on FPGA-based PCIe attacks, pcileech usage, physical-memory access workflows, and the defensive limits of software anti-cheat once a hostile device can read memory below the OS.

## README Coverage

- `Cheat > DMA`
- `Anti Cheat > Detection:DMA`
- `Anti Cheat > Detection: Hacked Hypervisor`
- `Anti Cheat > Detection:Virtual Environments`
- `Anti Cheat > Detection:HWID`
- `Windows Security Features`

## Threat Model

### External DMA Cheat Architecture
```
A modern external DMA cheat consists of three components:

1. Cheat PC — runs the cheat application, signature databases,
   aim assistance, ESP rendering, and a network/USB link to the gaming PC.

2. DMA Card — an FPGA-based PCIe endpoint installed in the gaming PC
   (typically M.2 NVMe slot). Exposes a memory-read/write interface to
   the cheat PC. Uses Bus Master capability to issue Memory Read TLPs
   against the gaming PC's RAM.

3. Actuator (optional) — a USB HID emulator (microcontroller-based) that
   injects keyboard/mouse input on the gaming PC according to commands
   from the cheat PC, closing the loop.

The structural property that makes this threat distinctive:
no attacker code executes on the gaming PC. The DMA card performs
hardware-level transactions between the FPGA and the gaming PC's
memory controller, mediated by the chipset and (when configured) the IOMMU.
The gaming PC's OS, drivers, and anti-cheat see only a PCIe device
announcing itself through Configuration Space and performing what looks
like ordinary DMA.
```

### Three Defense Layers
```
Layer              Mechanism                    What It Catches
─────────────────────────────────────────────────────────────────────────────
PCIe-layer         Inspect Config Space &        Identity mismatch — spoofed
fingerprinting     behavior at the bus level     device that doesn't match
                                                 real silicon's full signature

IOMMU              Use the IOMMU to bound        Out-of-domain DMA — device
enforcement        what physical memory the       trying to read game memory
                   device can touch               it wasn't allocated

External           TPM-anchored measured boot,   Boot-chain compromise — IOMMU
attestation        cloud-verified                or kernel itself subverted
```

## PCIe Protocol Stack

### Three Protocol Layers
```
Layer              Unit                Function
────────────────────────────────────────────────────────────────
Transaction        TLP                 Memory/IO/Config reads & writes,
                                       completions, messages
Data Link          DLLP                Acknowledgements, flow control
                                       credits, power management
Physical           Ordered Sets        Link training, equalization,
                                       clock recovery

A real device's behavior is shaped by all three layers.
Many FPGA designs primarily customize Transaction-Layer behavior; Physical and
Data Link behavior may retain implementation fingerprints unless the selected
IP, configuration, and surrounding behavior closely match the claimed device.
Whether a fingerprint is usable must be validated on the actual link.
```

### TLP (Transaction Layer Packet) Format
```
Every TLP contains a 3 DW (12-byte) or 4 DW (16-byte) base header; optional
TLP Prefixes may precede it. 4 DW headers are used for 64-bit addresses and
certain message types.

First DWord (DW0) encoding:
Bits       Field         Notes
[31:29]    Fmt[2:0]      Header format + data presence
[28:24]    Type[4:0]     TLP type (combined with Fmt)
[22:20]    TC[2:0]       Traffic Class (default 0)
[18]       Attr[2]       ID-Based Ordering (IDO)
[15]       TD            TLP Digest (ECRC trailer)
[14]       EP            Poisoned data
[13:12]    Attr[1:0]     Relaxed Ordering, No Snoop
[11:10]    AT[1:0]       Address Type (critical for ATS bypass)
[9:0]      Length[9:0]   Payload length in DWords (0x000 = 1024 DW = 4 KB)

Fmt[2:0] encoding:
000 = 3 DW header, no data
001 = 4 DW header, no data
010 = 3 DW header, with data
011 = 4 DW header, with data
100 = TLP Prefix

Key TLP types (Fmt + Type combinations):
Fmt  Type     TLP
000  0_0000   MRd (Memory Read, 3DW / 32-bit addr)
001  0_0000   MRd (Memory Read, 4DW / 64-bit addr)
010  0_0000   MWr (Memory Write, 3DW)
011  0_0000   MWr (Memory Write, 4DW)
000  0_0100   CfgRd0 (Config read — terminate at this device)
010  0_0100   CfgWr0
000  0_0101   CfgRd1 (Config read — forwarded by bridges)
010  0_0101   CfgWr1
000  0_1010   Cpl (Completion without data)
010  0_1010   CplD (Completion with data)
001  1_0rrr   Msg (Message, no data)
011  1_0rrr   MsgD (Message with data)
```

### Detection-Relevant DW0 Fields
```
TC[2:0] — Traffic Class. Default traffic commonly uses TC0, but non-zero TC is
valid when platform and device policy configure it. Compare usage with the
claimed device, driver, and workload rather than flagging it in isolation.

Attr[2:0] — RO/NS/IDO. A device emulating a NIC must follow that NIC's
typical NS/RO usage pattern; mismatches are visible.

AT[1:0] — Address Type:
  00 = Untranslated (IOMMU will translate)
  01 = Translation Request (ATS only)
  10 = Translated (device claims it has already translated via ATS)
This field is the basis of ATS bypass attacks.

TD — TLP Digest. If set, an ECRC trailer is present.
EP — Poisoned. Indicates data is known-bad.
```

### TLP Routing and Requester ID
```
Three routing modes:
- Address routing — Memory and IO TLPs, matched against bridge apertures
- ID routing — Config TLPs and Completions, by BDF
- Implicit routing — Some Messages (broadcast, terminate at root)

DW1 carries the Requester ID (16 bits = Bus:Device:Function, "BDF")
and an 8-bit Tag for matching completions to requests.

Requester ID is a key input to IOMMU lookup, ACS source validation, AER source
identification, and interrupt-remapping policy. If spoofed IDs are accepted
without topology or source validation, per-function isolation can be
undermined; the exact effect depends on the platform and remapping path.

Transaction categories:
- Posted (P) — fire-and-forget (Memory Writes, Messages)
- Non-Posted (NP) — requires completion (Memory Reads, IO/Config R/W)
- Completion (Cpl/CplD) — response to Non-Posted requests

Completion Status codes:
000 = Successful Completion (SC)
001 = Unsupported Request (UR)
010 = Configuration Request Retry Status (CRS)
100 = Completer Abort (CA)

UR vs CA distinction matters for spoofing detection — real silicon
responds differently to malformed config accesses vs accesses to
unimplemented offsets. Many spoofed firmwares hard-code one or the other.
```

### Memory Read Completion Splitting
```
A single Memory Read TLP returns up to Max_Read_Request_Size (MRRS) bytes.
The completer splits the payload at any boundary >= RCB
(Read Completion Boundary, 64 or 128 bytes).
Each fragment cannot exceed Max_Payload_Size (MPS).

Each Completion carries:
- Lower Address[6:0] — lowest 7 bits of first byte address
- Byte Count[11:0] — bytes remaining (last fragment's Byte Count
  equals its own payload length)
- BCM — PCI-X compatibility (typically 0)
- Tag — matches originating MRd's Tag

The split pattern (fragment count, boundary positions) is a
strong fingerprint: real memory controllers produce characteristic
distributions of fragment sizes and inter-fragment gaps.
BRAM-backed emulators producing perfectly uniform 64-byte fragments
at constant cadence are anomalous.
```

### Tag Space and Fingerprinting
```
- 5-bit Tag (original): 32 outstanding non-posted requests per Requester ID
- Extended Tag (PCIe 1.1+, Device Control[8]): 8-bit / 256 outstanding
- 10-Bit Tag (PCIe 4.0+, Device Control 2[12]): 1024 outstanding

Tag turnover discipline — which tags get reissued and how quickly —
reflects the device's internal request tracking pipeline.
Firmware that issues reads with no tag turnover (same tag, or monotonic
beyond negotiated limit) is observably distinct from real silicon.
```

### MPS and MRRS as Fingerprints
```
Both are negotiated once at link bring-up and fixed for the session.
- Device Capabilities[2:0]: Max_Payload_Size_Supported
  (0=128, 1=256, 2=512, 3=1024, 4=2048, 5=4096 bytes)
- Device Control[7:5]: current MPS (must be <= Supported,
  set to minimum of all devices in hierarchy)
- Device Control[14:12]: Max_Read_Request_Size (same encoding)

The discriminator is donor consistency: a device claiming a donor
that is known to support larger payloads, different tag behavior,
or a different negotiated profile should match that donor under
the same root-port constraints.
```

### Data Link Layer
```
DLLPs provide reliable delivery between Physical and Transaction layers.

DLLP          Purpose
─────────────────────────────────────────
Ack           TLP received correctly
Nak           TLP received with error; sender must replay
InitFC1/2     Flow control credit initialization at link bring-up
UpdateFC      Ongoing flow control credit updates
PM_*          Power management (L0s, L1 entry/exit)
Vendor        Vendor-defined

Flow control credits are per TLP category:
- PH / PD — Posted Header / Data
- NPH / NPD — Non-Posted Header / Data
- CplH / CplD — Completion Header / Data

Negotiated credit values are not generally exposed through standard
Link Capabilities register. They are visible in protocol-level traces,
some root-port/vendor performance counters, or FPGA-side debug.
Useful for lab fingerprinting and forensic captures, not normal
runtime config-space detection.
```

### Physical Layer
```
Two details matter even without PHY-level instrumentation:

LTSSM (Link Training and Status State Machine):
- States: Detect → Polling → Configuration → L0 (operational)
  → L0s, L1, L2 (low-power) → Recovery → Hot Reset → Disabled → Loopback
- Observable via Link Status Register and root-port performance counters

Detection-relevant:
- Negotiated Link Width (Link Status[9:4]):
  Compare with slot wiring, platform policy, signal quality, and matched donor
  deployments; devices can legitimately train below maximum width
- Current Link Speed (Link Status[3:0]):
  A lower negotiated generation is contextual, not a contradiction by itself
- Recovery cycle frequency:
  Comparative signal; materially different from donor reference is anomalous

ASPM (Active State Power Management):
- L0s and L1 are link-level low-power states
- Capability does not imply the platform enabled ASPM; evaluate transitions only
  under verified policy and workload conditions that should exercise them
```

### Configuration Access Mechanisms
```
Two mechanisms on x86:

CAM (Legacy I/O-port path):
1. CPU writes to I/O port 0xCF8 (Bus:Device:Function:Register)
2. CPU reads/writes at I/O port 0xCFC
- Reaches only first 256 bytes
- Still used during early BIOS/UEFI boot

ECAM (Enhanced, MMIO path):
1. Read MCFG ACPI table for segment base addresses
2. Compute: addr = base + ((bus << 20) | (dev << 15) | (func << 12) | offset)
3. OS maps physical address into kernel virtual memory
- Required for Extended Configuration Space (0x100–0xFFF)
- Where AER, DSN, LTR, VSEC, ATS, PASID, SR-IOV live

On Windows, supported paths are:
- IRP_MN_READ_CONFIG / IRP_MN_WRITE_CONFIG
- BUS_INTERFACE_STANDARD.GetBusData / SetBusData
Production anti-cheat should use documented bus interfaces;
direct MCFG mapping is a lab-only technique.
```

## PCIe Configuration Space

### Legacy 256-Byte Header (Type 0 Endpoint)
```
Offset  Field                    Notes
0x00    Vendor ID (2B)           Chip manufacturer (e.g., 0x8086 Intel)
0x02    Device ID (2B)           Specific product
0x04    Command (2B)             BME (bit 2), MemSpace (bit 1), IOSpace (bit 0)
0x06    Status (2B)              Capabilities List (bit 4)
0x08    Revision ID + Class Code Class triplet: Base / Sub / ProgIF
0x0C    Cache Line / Latency /   Header Type 0x00 = endpoint,
        Header Type / BIST       0x01 = bridge, 0x80 = multi-function
0x10–27 BAR0–BAR5               Memory or I/O windows
0x2C    Subsystem Vendor ID      Often distinguishes board manufacturers
0x2E    Subsystem Device ID
0x30–33 Expansion ROM Base
0x34    Capabilities Pointer     Offset of first capability in linked list
0x3C    IRQ Line/Pin/Min/Max     Legacy INTx routing

BAR encoding (32-bit BAR):
bit 0:    0 = Memory BAR, 1 = I/O BAR
bits 2:1: 00 = 32-bit, 10 = 64-bit (BAR pair)
bit 3:    Prefetchable

BAR size discovery: write 0xFFFFFFFF to BAR, read back.
Lower bits (except type bits) come back as 0; rest form a size mask.
Real silicon's size masks are device-specific; a spoofed BAR with
64 KB mask when the donor uses 4 KB is detectable in one operation.
```

### Capabilities Chain
```
If Status[4] is set, 0x34 points to the first capability.
Each capability has a 2-byte header: [ID | Next].
Next is DWord-aligned in 0x40–0xFF, or 0x00 to terminate.

Common capability IDs:
ID    Capability
0x01  PCI Power Management
0x05  MSI
0x10  PCI Express
0x11  MSI-X
0x12  SATA Configuration
0x13  PCI Advanced Features
0x14  Enhanced Allocation

Detection: walk the chain, validate each capability's declared size
doesn't overlap the next, Next is DWord-aligned and within bounds,
no cycle exists. A malformed chain is itself a signal.
```

### PCIe Express Capability (ID 0x10)
```
The single most important capability for spoofing detection.

Offset  Field                    Notes
+0x02   PCIe Capabilities        Cap Version, Device/Port Type, Slot Impl
+0x04   Device Capabilities      MPS Supported, FLR, Phantom Functions
+0x08   Device Control           MPS current, MRRS, Error Enables
+0x0A   Device Status            CED, NFED, FED, URD, Transactions Pending
+0x0C   Link Capabilities        Max Link Speed/Width, ASPM, L0s/L1 latencies
+0x10   Link Control             ASPM Control, RCB, Link Disable, Retrain
+0x12   Link Status              Current Link Speed/Width, Link Training
+0x24   Device Capabilities 2    Completion Timeout Ranges, AtomicOp,
                                 OBFF, LTR mechanism
+0x28   Device Control 2         Completion Timeout Value, AtomicOp, LTR Enable
+0x2C   Link Capabilities 2      Supported Link Speeds Vector
+0x30   Link Control 2           Target Link Speed, Compliance
+0x32   Link Status 2            De-emphasis, EQ Phase status

Detection leverage per field:
- Device Type (+0x02[7:4]): must match donor's role
- MPS Supported (+0x04[2:0]): hard-IP ceiling contradicts donor
- FLR support (+0x04[28]): verify FLR changes same sticky/non-sticky
  state as claimed donor; naive firmware acknowledges FLR but continues
  unchanged, producing state inconsistent with donor-defined reset semantics
- Link Status (+0x12): Width/Speed are negotiated, observable, hard to
  lie about — hard IP reports what LTSSM actually achieved
- Slot Clock Config (+0x12[12]): must match real platform behavior
- Completion Timeout ranges (+0x24): selecting outside claimed ranges
  is a discriminator
- AtomicOp (+0x24[6-9]): server-class GPUs/NICs may support; FPGA
  support depends on IP generation and configuration; compare advertised and
  exercised behavior with the claimed donor
```

### MSI and MSI-X Capabilities
```
MSI (ID 0x05):
Message Control bits:
  [0]    MSI Enable
  [3:1]  Multiple Message Capable (0–5, representing 1–32 vectors)
  [6:4]  Multiple Message Enable (cannot exceed Capable)
  [7]    64-bit Address Capable
  [8]    Per-Vector Masking Capable

x86 MSI Address: bits [31:20] fixed at 0xFEE (LAPIC prefix)
  [19:12] Destination ID, [3] Redirection Hint, [2] Destination Mode
Message Data: [15] Trigger Mode, [10:8] Delivery Mode, [7:0] Vector

MSI-X (ID 0x11):
- Supports up to 2,048 vectors
- Table stored in BAR-mapped region (not Config Space)
- Each entry: 16 bytes (Addr Low, Addr High, Data, Vector Control)
- PBA (Pending Bit Array): bit-per-vector pending state

Naive MSI-X emulation failures:
- Ignores Vector Control Mask writes
- Sets PBA bits but never clears on unmask
- Returns hardcoded PBA values
- Doesn't retire pending interrupts when masks clear
Detection probe: mask vector → induce interrupt condition →
observe PBA bit → unmask → observe interrupt firing.
A conforming implementation should satisfy the relevant MSI-X semantics;
incomplete emulations may fail, while sophisticated emulations can pass.
```

### AER Extended Capability (ID 0x0001)
```
Three error classes:
- Correctable: Receiver Error, Bad TLP, Bad DLLP, Replay Timer Timeout
- Uncorrectable Non-Fatal: Completion Timeout, Completer Abort, UR, ACS Violation
- Uncorrectable Fatal: Malformed TLP, DLL Protocol Error, Surprise Down

Each has Status (sticky, W1C), Mask, and Severity registers.
Header Log (16B) captures full TLP header of first logged uncorrectable error.

Detection:
- Absence of AER when donor model is known to expose it = mismatch
- Zero correctable-error count over long window when donor's silicon
  normally produces a baseline rate = anomalous
- Anomalous UR response patterns to probes of unimplemented offsets
```

### Extended Capabilities
```
4-byte header at each offset:
[31:20] Next Capability Offset (0 to terminate)
[19:16] Capability Version
[15:0]  Extended Capability ID

Key Extended Capability IDs:
0x0001  AER
0x0002  Virtual Channel (VC)
0x0003  DSN (Device Serial Number, 8 bytes)
0x000B  Vendor-Specific Extended Capability (VSEC)
0x000D  ACS (Access Control Services)
0x000E  ARI
0x000F  ATS (Address Translation Services)
0x0010  SR-IOV
0x0015  Resizable BAR (RBAR)
0x0018  LTR (Latency Tolerance Reporting)
0x001B  PASID
0x001D  DPC (Downstream Port Containment)
0x001E  L1 PM Substates
0x001F  Precision Time Measurement (PTM)

Detection-relevant:
- DSN: 8-byte unique serial; donor-cloned firmware can collide
  with another player's identical card
- VSEC: Xilinx PCIe IP optionally emits VSEC blocks with
  characteristic Vendor ID + VSEC ID combinations
- ATS/PASID/SR-IOV presence on consumer-class donor is
  demographically suspicious — rare outside server-class hardware
```

## IOMMU Architecture

### Translation Flow
```
1. Device issues Memory TLP with target IOVA.
   TLP header carries 16-bit Requester ID (BDF).
2. TLP travels upstream through switches/bridges to root complex.
3. IOMMU intercepts, uses Requester ID to look up translation context.
4. IOMMU walks device's I/O page tables: IOVA → physical address.
5. Permission bits (Read, Write) checked against access type.
6. Success: TLP forwarded with translated physical address.
7. Failure: fault logged, device receives UR or CA completion.
```

### Intel VT-d Internals
```
Two-level table lookup:

BDF → Root Table (256 entries, 16B each, indexed by Bus)
    → Context Table (256 entries, 16B each, indexed by Dev:Func)
      → Second-Level Page Tables (3–5 levels)
        → Final 4 KB physical page

Context Entry fields:
- SLPTPTR: Second-Level Page Table Pointer
- Domain ID: 16-bit (multiple devices can share a domain)
- AW: Address Width (3/4/5-level = 39/48/57-bit IOVA)
- T: Translation Type (untranslated-only, translated-only, or both)
- P: Present
- FPD: Fault Processing Disable

Page table entries (PTE, EPT-like format):
[0]      R - Read permission
[1]      W - Write permission
[7]      PS - Page Size (1=leaf super-page, 0=next-level table)
[N-1:12] Physical address of next-level table or 4 KB page

Super-pages: level-2 leaf = 2 MB, level-3 leaf = 1 GB.

Scalable Mode (VT-d 3.0+):
Context Entry → PASID Directory → PASID Table → per-PASID
first-level page-table roots. Enables Shared Virtual Memory (SVM).
Check RTADDR_REG.TTM to determine which mode is in effect.
```

### AMD-Vi Internals
```
Single-level Device Table indexed directly by BDF:

BDF → Device Table Entry (32 bytes)
    → I/O Page Tables (1–6 levels)
      → Final page

DTE encodes:
- Page Table Root Pointer
- Mode (0–6, selects paging levels)
- Domain ID (16 bits)
- IR, IW — Default Read/Write permission
- GV — Guest Valid (nested translation)
- PASID-related fields

Page sizes: 4 KB, 2 MB, 1 GB.
```

### IOTLB and Invalidation
```
Translations cached in IOTLB (I/O Translation Lookaside Buffer).
When mappings change, IOTLB must be invalidated.

Two distinct caches when ATS is in use:
- IOMMU's own IOTLB
- Device-side TLB (DevTLB) caching prior translations

Full invalidation with ATS requires:
1. IOMMU invalidates own IOTLB
2. IOMMU sends ATS Invalidate Request Message to device
3. Device drops affected DevTLB entries, replies with Invalidate Completion

If step 2 or 3 is skipped, device retains stale translations
and can DMA to unmapped addresses.

VT-d invalidation granularities:
- Global: flush entire IOTLB
- Domain-Selective: flush all entries for a Domain ID
- Page-Selective: flush specific IOVA range in a domain

Strict vs lazy invalidation:
Lazy mode defers IOTLB invalidation, batching them for performance.
Opens a window where stale translations remain valid — a device
whose driver has unmapped a buffer can still DMA to the old IOVA.
```

### Fault Recording
```
VT-d: Fault Recording Registers — circular array capturing
  Requester ID, faulting IOVA, fault reason, TLP type.

AMD-Vi: Event Log Buffer — producer-consumer ring buffer of
  IO_PAGE_FAULT, INVALID_DEVICE_REQUEST, ATS-related events.

Both surface faults via interrupts and event-log entries.
On Windows, some IOMMU violations observable through WHEA/bug-check
paths and Driver Verifier DMA-violation telemetry.

Per-device fault rate is one of the most operationally useful
IOMMU-layer signals, but its baseline is platform-, device-, driver-, firmware-,
and workload-specific. Sustained faults show failed or invalid DMA requests;
driver bugs, resets, stale mappings, or hardware faults must be excluded before
attributing malicious out-of-domain access.

RMRR/IVMD:
ACPI DMAR table contains RMRR (Reserved Memory Region Reporting)
sub-tables declaring physical ranges devices need identity-mapped.
AMD-Vi has analogous IVMD (I/O Virtualization Memory Definition)
in the IVRS table. A defender should enumerate these and reject
configurations where suspect BDFs appear in RMRR scope or
RMRR ranges overlap game memory regions.
```

## IOMMU Topology and Isolation

### IOMMU Groups
```
Devices in the same IOMMU group may not be safely isolated from
one another. Group membership determined by:
- PCIe topology — devices behind a switch share a group
  unless the switch supports and enables ACS
- ACS state of upstream bridges
- Quirks for known-broken hardware

Linux: /sys/kernel/iommu_groups/N/devices/
Windows: equivalent constraints but no simple public group filesystem
```

### ACS (Access Control Services, Extended Cap ID 0x000D)
```
ACS is a PCIe capability that switches/root ports advertise
to declare they can enforce isolation between downstream ports.

ACS Capability register enable bits:
Bit  Feature                      Effect
0    Source Validation (SV)        Drop TLPs with wrong Requester ID
1    Translation Blocking (TB)    Block AT=10 (Translated) TLPs
2    P2P Request Redirect (RR)    Force P2P requests upstream for IOMMU
3    P2P Completion Redirect (CR) Force P2P completions upstream
4    Upstream Forwarding (UF)     Forward upstream regardless
5    P2P Egress Control (EC)      Allow/deny P2P routing per-port
6    Direct Translated P2P (DT)   Allow P2P with translated addresses

Critical for untrusted endpoints: SV, TB, RR, and CR.
A switch missing Source Validation lets a malicious device spoof
its Requester ID, defeating per-BDF IOMMU translation.
A switch missing P2P Request Redirect allows devices on the same
switch to DMA directly to each other without IOMMU involvement.
```

### Peer-to-Peer DMA
```
Devices on the same PCIe tree can send Memory TLPs directly to
each other's BAR ranges without involving system memory.
Without ACS redirection, peer traffic may remain below the root complex and
bypass the host IOMMU translation path. Routing behavior is topology- and
platform-specific, so confirm it with the actual root complex and switches.

Plausible P2P DMA targets for cheat:
- GPU framebuffer — rendered game state
- Network adapter ring buffers — game traffic
- USB controller queues — input device data

Mitigation: ACS Translation Blocking + P2P Request Redirect
on every intermediate bridge. Defender must walk topology and
confirm both bits are active.
```

### Interrupt Remapping
```
MSI/MSI-X interrupts are Memory Writes to 0xFEE00000–0xFEEFFFFF.
Without Interrupt Remapping (IR), any device with Bus Master enabled
can write to this range and trigger arbitrary interrupts — NMIs, SMIs,
or vectors targeting wrong CPU.

With IR enabled, IOMMU validates MSI/MSI-X writes and uses
remapping-table state to determine permitted destination.
IR is part of VT-d's broader DMA Remapping architecture.
Both VT-d and AMD-Vi have integrated equivalents.
Both should be mandatory in any anti-cheat threat model.
```

## ATS, PASID, and Address Translation Trust

### ATS (Address Translation Services, Extended Cap ID 0x000F)
```
ATS lets a device cache IOMMU translations locally:
1. Device issues Translation Request TLP (AT=01) with IOVA
2. IOMMU translates and responds with Translation Completion
   carrying physical address
3. Device caches translation in Device-side TLB (DevTLB)
4. Subsequent accesses issued with AT=10 (Translated) —
   IOMMU bypasses page-walk, trusting device's cached translation
5. On mapping changes, IOMMU sends Invalidation Request

Attack surface: malicious device claiming ATS can present
arbitrary AT=10 TLPs whose addresses were never approved
by the IOMMU. The IOMMU forwards them trusting the device's claim.
```

### PASID (Extended Cap ID 0x001B)
```
Extends ATS to per-process address spaces. 20-bit PASID carried
in a TLP Prefix. IOMMU uses (Requester ID, PASID) jointly
to select translation context.

PASID enables Shared Virtual Memory (SVM) — primarily found in
datacenter NICs, AI accelerators. Presence on a consumer card
is anomalous.
```

### ATS Trust Model and "ATS Untrusted" Mode
```
The fundamental trust assumption: device honestly reports
translations it has been granted. Unreasonable for external
Thunderbolt enclosures, FPGAs in M.2 slots, or untrusted
accelerator cards.

Modern OS/IOMMU stacks can treat endpoints as ATS-untrusted:
ATS is disabled, blocked by policy, or stripped.
Linux: pci=noats plus per-device quirks.
Windows: Kernel DMA Protection / DMAGuard matters, but don't
treat "Kernel DMA Protection: On" as proof every internal
endpoint is ATS-untrusted. Verify ATS state per endpoint.
```

## Driver–IOMMU Contract and Bypass Catalog

### Legitimate DMA Path (Windows)
```
1. Acquire DMA adapter: IoGetDmaAdapter / WDF wrapper
2. Allocate buffer: MmAllocateContiguousMemorySpecifyCacheNode
   or WdfCommonBufferCreate
3. Map for DMA: AllocateCommonBuffer / MapTransferEx
   - OS allocates IOVA from device's domain
   - Creates IOMMU page-table entries: [IOVA, IOVA+size) → physical pages
   - Returns IOVA to driver
4. Program device: driver writes IOVA into device's BAR registers
5. Device DMAs: TLPs arrive at IOMMU with BDF + IOVA
6. IOMMU translates: page-walk produces physical address
7. Completion and unmap: teardown IOMMU entries + IOTLB invalidation

In this model, device can DMA only to addresses the driver
explicitly mapped. Game memory is not in that range.
```

### Six Paths to Out-of-Domain Access
```
1. IOMMU not active or not applied to this path
   VT-d/AMD-Vi disabled, OS not enforcing, device outside protected ports

2. Pre-boot DMA injection
   Inject before IOMMU initialized; requires firmware-level exploit

3. Identity-mapped / passthrough domains
   Legacy drivers request 1:1 mapping; modern strict-mode rejects it

4. Driver mapping over-allocation (Thunderclap class)
   OS maps full 4 KB page when buffer is smaller; adjacent kernel data exposed

5. Legitimate-path data exfiltration
   Cheat spoofed as NIC; OS network stack passes game packets through
   NIC's RX ring buffer (legitimately IOMMU-mapped). Cheat reads game data
   without leaving allowed mappings. Undetectable at IOMMU layer.

6. IOMMU page-table manipulation via kernel compromise
   BYOVD / vulnerable driver reprograms IOMMU tables.
   Requires code execution on gaming PC.

Approaches 1–3 are the foundation of most current DMA cheats.
```

### IOMMU Bypass Catalog (16 Techniques)
```
#   Technique                   Mechanism                           Mitigation
─────────────────────────────────────────────────────────────────────────────────
1   IOMMU disabled              VT-d/AMD-Vi off in BIOS             Refuse misconfigured platforms
2   Pre-boot DMA                Firmware leaves injection window     UEFI updates; verify ACPI indicators
3   Identity/passthrough        1:1 IOVA-to-physical mapping        Strict-mode IOMMU policy
4   Driver over-allocation      Full 4 KB page, adjacent data       OS bounce buffers; strict mappings
5   ATS abuse                   AT=10 TLPs with arbitrary addrs     ATS Untrusted mode for non-allowlisted
6   ACS missing on bridge       P2P or spoofed Requester ID         Verify ACS state on all bridges
7   Lazy IOTLB invalidation    Stale translations valid briefly    Strict invalidation mode
8   FLR race                    FLR/Hot Reset race window           Synchronized FLR handling
9   SMM bypass                  SMM code exempt from IOMMU          Boot Guard / Platform Secure Boot
10  DMA-remapping driver bugs   Bugs in OS IOMMU manager            OS patching
11  Hypervisor escape           Compromised hypervisor              VBS / measured boot; TPM attestation
12  Interrupt injection (no IR) Write arbitrary interrupts           Mandatory IR enforcement
13  RMRR/IVMD scope abuse       Fake ACPI tables cover attacker     Measured boot; runtime RMRR audit
                                physical ranges
14  Snoop-bit manipulation      Stale cache lines visible           Strict snoop enforcement
15  PASID confusion             Misconfigured PASID Table           PASID-aware IOMMU programming
16  DMAR/IVRS spoofing          Compromised firmware, fake tables   Measured boot covering firmware

Techniques 1–6: active attack surface for current commercial DMA cheats
Techniques 7–13: academic, APT, firmware-level contexts
Techniques 14–16: largely theoretical
```

## FPGA Hardware

### Xilinx PCIe Integrated Block
```
Hardened IP block handling:
- Physical Layer (PHY, 8b/10b or 128b/130b, LTSSM, equalization)
- Data Link Layer (sequence numbers, replay buffer, flow control)
- Transaction Layer framing and parsing
- Subset of Configuration Space

IP core documentation:
- PG054 for 7-series
- PG156 for UltraScale Gen3
- PG213 for UltraScale+ Gen4

User logic interfaces over AXI-Stream (TX/RX) and separate
config management: cfg_mgmt_* (7-series), cfg_ext_* (UltraScale).

Detection consequences:
- Default fingerprints leak through: hard block populates Config Space
  with Xilinx-characteristic byte patterns
- 7-series firmware authors who don't understand cfg_mgmt_* leave
  subtle behavioral differences (some CfgTLPs return hard-block defaults)
```

### FPGA Family Hierarchy
```
Artix-7 (consumer/mid-range, GTP transceivers, PCIe Gen2):
Chip       LUTs      BRAM(Kbit)  PCIe Hard Block
XC7A35T    20,800    1,800       Gen2 x4
XC7A50T    32,600    2,700       Gen2 x4
XC7A75T    46,200    3,780       Gen2 x4
XC7A100T   63,400    4,860       Gen2 x4
XC7A200T   134,600   13,140      Gen2 x4
(Smaller than T35 have no hard PCIe block)

Kintex-7 (high-end, GTX transceivers):
XC7K70T    41,000    4,860       Gen2 x8
XC7K160T   101,400   11,700      Gen2 x8
XC7K325T   203,800   16,020      Gen2 x8 / Gen3 x4
XC7K410T   254,200   28,620      Gen3 x8

Zynq UltraScale+ (ARM Cortex-A53 cores, GTH/GTY):
ZU2EG/CG   ~47,000   ~5.3M      Gen3 x4
ZU3EG/CG   ~70,000   ~7.6M      Gen3 x4
ZU4EG/EV   ~88,000   ~11.0M     Gen3 x8
ZU5EG/EV   ~117,000  ~18.0M     Gen3 x8
ZU6EG/CG   ~230,000  ~32.1M     Gen3 x16
(EV-suffixed: hardened H.265 codec for DMA + video-capture boards)
```

### Resource Constraints and Capability
```
BRAM size caps:
  shadow config + writable overlay + BAR emulation + state machines.
  T35 (1.8 Mbit) struggles with full 4 KB shadow + 64 KB BAR + jitter buffers.
  T100 (4.86 Mbit) fits comfortably.
  Zynq ZU3 (7+ Mbit) has effectively unlimited room.

LUT count caps behavioral complexity:
  Each subsystem (MSI generator, ASPM FSM, AER counter, BAR responder)
  costs thousands of LUTs. T35 holds 1–2; T100 the full set;
  Kintex/Zynq adds runtime-reconfigurable parameter tables.

PHY transceiver family (GTP/GTX/GTH/GTY) has measurably different
signal characteristics; can sometimes be inferred from root-port
performance counters independent of firmware spoofing.
```

### Form Factors
```
Form Factor           Description                 Detection
────────────────────────────────────────────────────────────────────
M.2 NGFF Key M        Internal NVMe slot           Dominant modern form;
                                                    physically invisible
M.2 + USB3 bridge     M.2 board with FT601         Gaming PC sees only M.2
PCIe x1/x4 add-in     Traditional add-in card      More physically visible
External USB3          USB3-to-PCIe (legacy)        Mostly obsolete
Combo boards           DMA + HDMI capture +         Complex device tree;
                       input injection              HDMI activity is fingerprint

M.2 slot populations are partially auditable from software through
PCI topology, ACPI, SMBIOS, storage inventory, and vendor board databases.
SMBIOS slot records are often incomplete for M.2, so detection should
be probabilistic and board-model-aware.
```

## pcileech Framework

### Project Lineage
```
Five upstream repositories:
- pcileech:       Host-side C application with attack modules
- pcileech-fpga:  FPGA firmware in Verilog/SystemVerilog, per-board variants
- MemProcFS:      Virtual filesystem mounting target memory as /proc-like tree
- LeechCore:      Low-level device abstraction library
- vmm:            Memory analysis engine (vmm.dll API)

Pipeline: FPGA → LeechCore → PCILeech attack modules / MemProcFS analysis
```

### FPGA Firmware Architecture
```
Key modules:
- pcileech_pcie_a7.v / _us.v:        Top-level Artix-7 / UltraScale integration
- pcileech_pcie_tlps128_bram_rdwr.v:  128-bit TLP source/sink (AXI-Stream)
- pcileech_pcie_cfgspace_shadow.v:    Shadow config space in BRAM
- pcileech_cfgspace.coe:              Init data (stock: Xilinx 10EE:0666)
- pcileech_bar_impl_zerowrite4k.v:    Default BAR — absorbs writes, returns zero
- pcileech_bar_impl_loopaddr.v:       Alternative BAR — echoes address
- pcileech_bar_impl_none.v:           Disables BAR (returns UR)
- pcileech_pcie_cfg_a7.v:             Config management via cfg_mgmt_*
- pcileech_mux.v:                     TLP multiplexer
- pcileech_fifo.v:                    Internal staging FIFO

Two key architectural choices:
1. Shadow config is spoofable but not spoofed by default.
   .coe ships with placeholder Xilinx IDs. User must overwrite
   with real donor's dump and resynthesize.
2. BAR controller is functionally inert.
   zerowrite4k doesn't emulate device behavior.
   Active BAR probing catches stock builds in one operation.
```

### Host-Side MemProcFS
```
Mounts target memory as filesystem:
M:\
├── pid\1234\
│   ├── name.txt
│   ├── modules\       ← loaded module list
│   ├── handles\
│   ├── vad\           ← virtual address descriptors
│   ├── memmap.txt
│   └── minidump\
├── sys\
├── name\game.exe\     ← lookup by process name
└── forensic\
    ├── yara\
    ├── timeline\
    └── registry\

One possible development/use pattern:
1. Development phase: MemProcFS, signature search, cross-references
   → slow, broad scanning to find entity manager / player array / view matrix
2. Execution phase: custom app via vmm.dll/LeechCore,
   narrower periodic or batched reads of known offsets
Behavioral analysis can test for this pattern, but implementations may cache,
randomize, or use different access strategies.
```

### Stock Firmware Fingerprints
```
Common or older vanilla pcileech-fpga configurations may exhibit the following;
verify the exact commit, FPGA IP configuration, and synthesized design:
- VID/DID 10EE:0666 (Xilinx placeholder)
- Xilinx 7-series PCIe IP signature bytes at characteristic offsets
- DSN Extended Capability absent or default
- No AER, LTR, ARI, ATS, or SR-IOV capabilities
- BAR0 mapped (DMA window); BAR1–5 disabled or all-ones
- BAR reads return zero (zerowrite4k) or echo address (loopaddr)
- MSI capability present but expected interrupts are not generated
- Config reads complete in deterministically uniform time
  (BRAM lookup with fixed pipeline depth, near-zero variance)
- no observed ASPM transitions under a workload and policy that should enter
  lower-power states
- AER correctable-error count stays at zero
- power state remains D0 under tested conditions
- Class Code matches donor placeholder but no class-specific behavior
```

## Configuration Space Spoofing

### Bridge vs Emulated Firmware
```
Bridge firmware:
  Patches identity fields via Vivado's PCIe IP Core GUI
  (VID, DID, Subsystem IDs, Class Code, sometimes DSN).
  Fast to produce, but 7-series hard IP generates internal capability
  blocks at characteristic offsets that retain FPGA-specific fingerprints.

Emulated (1:1) firmware:
  Implements complete shadow Configuration Space in BRAM.
  Entire 4 KB extended config space initialized from real donor device hex dump.
  When OS issues CfgRd TLP, firmware responds from BRAM.
  The design attempts to prevent IP-core defaults from appearing on the bus.

  Common bugs in emulated firmware:
  - First 16 bytes still come from IP block (mux priority)
  - Type 1 config reads not intercepted
  - Capability blocks bypassed in GUI still leak defaults
```

### Shadow Configuration Space Implementation
```
Requirements:
1. Intercept incoming CfgRd0/CfgWr0 TLPs
2. Decode target offset
3. Look up value in BRAM
4. Build Completion TLP with correct Completer ID, status, payload
5. Send Completion through hard IP block

4 KB coverage at 4-byte granularity = 1,024 entries × 4 bytes = 4 KB BRAM.
Well within even T35's resources.
```

### Overlay RAM and Writable Register Emulation
```
Real devices have writable registers. Firmware that returns correct
values on reads but drops writes creates detectable inconsistency.

Detection probe:
  write Command[BME] = 1 → read Command[BME]
  write Command[BME] = 0 → read Command[BME]
  Real silicon: bit toggles. Naive shadow: bit stays at BRAM init value.

Overlay RAM merges at read time:
  response = (base_value & ~writable_mask) | (overlay_value & writable_mask)

The catch: writable mask is register-specific:
- Command Register: different reserved bits than Device Control
- MSI Address Low: bits [1:0] reserved-zero
- BAR: type bits in [3:0] depend on I/O/memory, prefetchable
- Status Register: W1C bits — writing 1 clears, writing 0 no change
- AER Status: W1C across the board

Naive implementations with single global mask fail because
reserved-bit and W1C behavior diverges. Detection probes
W1C cases: write 0x00000000 to Correctable Error Status,
then write known-1 patterns, verify read-back semantics.
```

### Donor Card Extraction
```
A common emulation strategy starts with a donor device and clones more than
VID/DID: configuration-space layout, capabilities, BAR masks, interrupt-table
layout, and device serial behavior where present. Completeness varies by design.

Extraction tools:
- lspci -d [VID:DID] -vvv -xxxx (full ECAM dump)
- setpci -s <BDF> ECAP_AER+0x4.L
- Direct ECAM mapping in kernel-mode tools
- VFIO passthrough + programmatic dump

Donor selection pitfalls:
- Duplicating hardware already in gaming PC → caught instantly
- Must match FPGA's actual PCIe capability (x16 Gen4 on Gen2 x1 fails)
- Silicon generation must align with claimed link speed
- Class-functional A/B testing detects non-functional donors
```

### Firmware Sophistication Tiers
```
Tier  Description              Detection Difficulty
──────────────────────────────────────────────────────────────────
0     Stock                    Trivial — VID/DID blacklist
      Unmodified upstream;
      10EE:0666 IDs

1     Bridge                   Easy — signature residue,
      .coe replaced with       driverless device, BME clearance
      donor VID/DID only

2     Shadow config            Medium — R/W consistency probe
      Full 4 KB shadow;        catches silent write drops
      no overlay RAM

3     Overlay RAM              Medium-hard — BAR probe still fails;
      Shadow + writable layer  class-functional A/B fails
      with per-register masks

4     BAR MMIO + MSI           Hard — interrupt distribution analysis;
      Donor-class BAR memory   BAR-region content baselining
      responder + MSI generator

5     Behavioral emulation     Very hard — multi-session statistical
      Latency jitter, ASPM,    analysis required
      AER counters, donor-
      class-specific behavior

6     Private + randomized     Currently undefeated by hardware-layer
      Per-customer layout,     signatures alone
      capability shuffling,
      custom hard-IP integration

Each tier transition corresponds to a defender technique
that closed the prior tier's escape hatch.
Cost-to-implement is nonlinear: 0–2 are public/trivial,
3 needs moderate Verilog, 4–5 need deep PCIe knowledge,
6 is sustained engineering.
```

### Donor Exhaustion
```
Each detected donor class becomes nonviable. Remaining viable donors
trend toward obscure industrial cards — which themselves become
a behavioral signal on consumer gaming PCs.

Donor Class            Detection Status
─────────────────────────────────────────────────────────
Wi-Fi adapters         Heavily detected; class-spoof checks ubiquitous
Wired NICs             "NIC with loaded driver but zero packets" test
NVMe SSDs              Harder; detected via missing namespace activity
Audio codecs           Lower bandwidth fits FPGA; class checks present
USB host controllers   Child-device enumeration check breaks naive
Capture cards          Harder (genuinely idle when no source)
Industrial / OEM SKUs  Increasingly only viable; demographic signal
Server-class accel.    Physically implausible on consumer boards
```

## Detection at the PCIe Layer

### Configuration Integrity
```
- VID/DID/SVID/SDID against known-real-silicon list
- Capability-chain walk: DWord-aligned Next pointers, no overlaps, no cycles
- Signature-residue scanning: Xilinx 7-series default byte patterns at
  known relative offsets (Device Capabilities field bits, reserved bits,
  VSEC vendor IDs)
- Capability presence consistency: expected capabilities must match the donor's
  exact SKU, firmware, function, and configuration
- BAR mask verification: write 0xFFFFFFFF, compare size mask against donor
```

### BAR Memory Read Probing
```
Send Memory Read TLPs to BAR ranges, validate responses by donor class:

NIC donor BAR0: register layout with receive/transmit ring descriptors,
  interrupt mask, link status. Offset 0x00 returns specific bit pattern.

NVMe donor BAR0: NVMe controller registers — CAP (MQES, DSTRD,
  MPSMIN/MPSMAX), VS, CC, CSTS, AQA, ASQ/ACQ, doorbells at 0x1000.

USB XHCI donor BAR0: Capability Registers (CAPLENGTH, HCSPARAMS, HCCPARAMS).

zerowrite4k returns all-zeros; loopaddr echoes address. These patterns are
conspicuous under donor-specific functional probes, although individual real
register ranges can legitimately contain zeros.
Tier-4 firmwares implement donor-class responders but usually only
cover registers checked at probe time, leaving others divergent.
```

### R/W Consistency Probing
```
- Command Register: toggle Memory Space, I/O Space, Bus Master Enable
- Device Control: change MPS, MRRS, Error Enables
- MSI Control: toggle Enable, change Multiple Message Enable
- Walk every W1C bit (Status, AER Status): write 1s, confirm clear
- Walk reserved bits: write 1s, confirm read-back as 0
- Per-register writable masks must match donor

Tier-2 (no overlay) fails immediately.
Tier-3 (single global mask) fails on W1C and reserved-bit cases.
```

### LTSSM and Link-State Validation
```
Sample PCIe Express Capability Link Status over time:
- Negotiated Width (Link Status[9:4]): consistent with donor deployment
  and FPGA hard block capability
- Current Link Speed (Link Status[3:0]): track slot's actual speed
- A device can legitimately train below its maximum capability; compare the
  result with slot topology, platform policy, signal quality, and matched donor
  deployments
- DLL Active (Link Status[13]): should be 1 during operation
- Slot Clock Config (Link Status[12]): match real common-clock state
```

### ASPM Behavioral Validation
```
Real devices claiming ASPM exhibit characteristic L0 ↔ L1 transitions.

Spoofed device anomalies:
- Claims and enables ASPM but shows no expected transition under a workload,
  policy, and observation window known to exercise it
- Transitions with exit latency inconsistent with claimed value
- Does not reach L1.1/L1.2 when donor, platform, firmware policy, and workload
  are verified to enable those substates

Sample Link Status "DLL Active" bit over time + PMC counters.
```

### AER Baselining
```
- Departure from donor baseline: per-silicon correctable-error footprint
  should be stable. Implausibly clean (zero correctables when donor
  normally produces Bad TLP / Replay Timer Timeout) is anomalous.
- Implausible Header Log content (default/zeroed values)
- Inconsistent UR/CA responses to probes of unimplemented offsets
```

### Completion Latency Fingerprinting
```
Completion latency can reflect memory, arbitration, buffering, power state,
link, driver, and workload behavior. A simplistic BRAM-backed emulator may show
lower variance, but real and emulated distributions can overlap.

Detection signal is distribution shape, not absolute mean.

Statistical methods:
- Kolmogorov–Smirnov test: compare empirical CDFs
- Tail estimators where sample size and distributional assumptions support them
- Anderson-Darling test: sensitive to tail differences

Choose the sample size from power/variance analysis, collect under controlled
conditions, compare with a matched donor reference, and validate any decision
threshold on held-out devices.

Random jitter alone need not reproduce donor behavior. Compare mean, variance,
tails, modes, autocorrelation, and responses to condition changes.
```

### MSI/MSI-X Behavioral Validation
```
A device with MSI enabled, programmed Address/Data, an attached driver, and a
verified interrupt-producing condition should produce interrupts:

- Zero interrupts when driver should exercise device = anomalous
- Uniform arrival times may indicate a timer-driven generator, but legitimate
  periodic workloads must be excluded
- Implausibly bursty patterns not matching donor class

Monitor via OS interrupt accounting, ETW/performance telemetry,
driver counters, kernel instrumentation.
```

### Cheat-Phase Access Pattern Recognition
```
One possible workflow has a broad discovery phase followed by narrower,
periodic reads during use. Implementations can cache, randomize, batch, or avoid
these phases, and legitimate devices can also show periodic access.

Candidate execution features:
  Temporal periodicity, address-space breadth, and alignment to game-frame
  intervals, calibrated against matched benign device/workload behavior.

Distinguishing features:
- Fano factor
- Autocorrelation at frame intervals
- Address-space coverage entropy

Honeypot regions complement this when combined with:
  IOMMU denial/fault logging, hypervisor-managed protected pages,
  device-domain sandboxing, decoy IOVA mappings, or server-side
  behavioral traps tied to fake game objects.
```

### Hot-Plug and Link Disruption Events
```
Firmware swaps and donor reconfigurations require link renegotiation.
Three observable signals:

1. AER Surprise Down — uncorrectable fatal error logged when link
   drops unexpectedly mid-session.

2. Slot Status hot-plug events — Presence Detect Changed,
   Data Link Layer State Changed, MRL Sensor Changed.
   Register via IoRegisterPlugPlayNotification with
   EventCategoryTargetDeviceChange or EventCategoryDeviceInterfaceChange.

3. LTSSM re-training cycles — Link Training bit toggling,
   transient Recovery state.

A device that surprise-downs then reappears with subtly different
Config Space (adjusted MSI layout, different latency profile,
different VID/DID) = fingerprint of mid-session firmware reload.
```

## Detection at the IOMMU Layer

### Fault-Rate Monitoring
```
Sample per-device fault counters from IOMMU fault-recording structure
(VT-d Fault Recording Registers, AMD-Vi Event Log) or from WHEA.

Pipeline:
1. Snapshot baseline at session start
2. Sample at intervals; compute per-device fault rate
3. Threshold-trigger additional PCIe probing on devices exceeding baseline
4. Aggregate evidence across signals before action
```

### Domain Assignment Audit
```
Walk IOMMU domain assignments for anomalies:
- Devices on passthrough/identity domains when strict mode is active
- Devices in unexpectedly large IOMMU groups (poor ACS topology)
- Multiple devices sharing Domain ID when they shouldn't
```

### ACS Topology Verification
```
Walk PCIe bridge topology between every endpoint and root complex.
For each bridge with ACS Capability:
- Verify Source Validation (SV) enabled
- Verify Translation Blocking (TB) enabled
- Verify P2P Request Redirect (RR) and Completion Redirect (CR) enabled

Missing or disabled ACS can limit isolation where peer routing is possible.
Assess the complete topology, root-complex behavior, firmware policy, and actual
IOMMU grouping before calling it an exploitable isolation hole.
```

### IOMMU as Containment Primitive
```
Active containment when suspect device is identified:

1. IOMMU domain re-remapping:
   Reprogram device's domain to sandbox memory instead of revoking access.
   Requests may receive sandbox data or fault depending on mappings and device
   behavior; validate OS/driver stability before using this response.

2. Bus Master Enable clearance:
   Toggle Command[2] to 0. Effectiveness depends on platform enforcement,
   device behavior, and alternate paths; monitor for restoration or races.

3. Downstream Port Containment (DPC):
   When DPC is enabled on root port (Extended Cap ID 0x001D),
   supported trigger conditions can place the downstream hierarchy into
   containment. Verify the port status, traffic blocking, link recovery, and
   platform-specific behavior; support is not universal.

4. Anti-cheat-owned device domain:
   For device owned by AC driver, allocate and map only sandbox IOVAs,
   never expose game memory.

5. Hypervisor-integrated enforcement:
   Enforce policy above guest kernel by trapping IOMMU MMIO programming.
   Requires privileged platform integration.
```

## Hypervisor-Level Defense

### EPT-Based Memory Protection
```
EPT translates Guest Physical Address (GPA) to Host Physical Address (HPA).
A hypervisor owning the EPT can:

- Mark game memory as read-execute-only in EPT, even if guest OS marks
  read-write. Writes cause EPT violations the hypervisor traps.
- Hide pages by clearing EPT mappings.
- Implement watchpoints on specific GPA ranges.

IOMMU blocks DMA at device-to-memory boundary;
EPT blocks CPU access at guest-to-host boundary.
A cheat combining DMA card with kernel-mode payload faces both.
```

### VBS, HVCI, and VTL Split
```
VBS creates Secure Kernel (VTL 1) alongside regular kernel (VTL 0)
in a Hyper-V partition. HVCI uses VTL 1 to enforce no executable page
in VTL 0 is simultaneously writable.

Anti-cheat interaction:
- Register VTL 1 callouts to validate guest state
- Attest against System Guard Secure Launch (DRTM) measurements
- Rely on HVCI to block BYOVD patterns

Combined VBS+HVCI+TPM+SecureBoot is assumed baseline for
serious anti-cheat threat models.
```

### SMM Considerations
```
System Management Mode (Ring -2) runs in SMRAM, isolated from
the OS. SMM CPU memory accesses are not mediated by the device IOMMU, but
accessible data still depends on platform protections, memory encryption,
firmware design, and virtualization context.

A vulnerable SMI handler = path to arbitrary memory access
without IOMMU mediation.

Mitigations:
- Intel Boot Guard / AMD Platform Secure Boot (firmware signatures)
- SMI Transfer Monitor (STM): hypervisor-resident, treats SMM as
  constrained guest; availability and deployment are platform-specific
- Runtime verification of SMM lockdown registers
```

### PCIe IDE (Integrity and Data Encryption)
```
IDE adds link-level TLP protection: integrity (MAC-based, required)
and confidentiality (encryption, optional).
Incorporated into PCIe 6.0 base specification.

Valuable against: physical link interposers, malicious retimers/switches,
traffic tampering.

NOT a DMA-cheat silver bullet: cheat installed as the endpoint
still originates legitimate IDE-protected TLPs after key establishment.
IDE raises the bar for passive bus sniffing but endpoint identity,
IOMMU policy, ACS topology, ATS policy, and attestation remain required.
```

## External Trust Anchors

### TPM 2.0
```
Hardware (or firmware-isolated) cryptoprocessor with:
- PCRs: extend-only registers, PCR[n] = SHA256(PCR[n] || new_value)
- Persistent keys: EK (manufacturer), SRK (provisioned), user-defined
- Hierarchy: Endorsement, Storage, Platform, Null
```

### PCR Allocation (Measured Boot)
```
PCR   Measured Content
0     SRTM / Core Root of Trust — UEFI firmware code
1     Platform configuration data — firmware variables
2     Option ROM code — third-party UEFI drivers
3     Option ROM configuration and data
4     IPL / boot manager binary (e.g., bootmgfw.efi)
5     IPL configuration — GPT/partition table, boot config
6     Manufacturer-specific / state-transition events
7     Secure Boot policy (PK, KEK, db, dbx)
8–15  OS-defined (BitLocker binds to PCR[11])
16    Debug
17–22 DRTM measurements (Secure Launch)
23    Application-defined
```

### Remote Attestation Cryptography
```
Trust property: without the attestation key or a break in the TPM/verification
chain, local software cannot forge a quote over arbitrary PCR values.

Flow:
1. Server sends nonce
2. Client calls TPM2_Quote(AIK, PCR_selection, nonce)
   TPM computes PCR composite, builds TPMS_ATTEST, signs with AIK
3. Client sends Quote + AIK certificate chain
4. Verifier checks:
   - AIK signature valid
   - AIK certificate chains to trusted TPM manufacturer root
   - EK on known-EK list (binds AIK to real TPM)
   - Nonce matches (freshness, replay protection)
   - PCR composite matches known-good value

A rootkit loading after measured boot cannot normally reset extend-only PCRs to
an arbitrary prior value through the standard TPM interface. A software
simulator cannot produce a quote verifiable under a trusted hardware-backed
attestation key, but a valid quote still covers only the selected measurements.
```

### DRTM and Secure Launch
```
Dynamic Root of Trust for Measurement allows "late launch" —
trusted execution environment established after OS boot,
measurement captured into PCR[17].

Intel: GETSEC[SENTER] (TXT)
AMD: SKINIT (SVM extension)

CPU enters measured execution state, Secure Loader Block (SLB)
loaded and hashed into PCR[17], control transfers to
Measured Launch Environment (MLE).

Microsoft System Guard Secure Launch uses this to load HVCI's
hypervisor into measured state independent of SRTM chain.
Defender requests Quote including PCR[17] and matches against
known-good MLE measurement.
```

### UEFI Pre-Boot DMA Integrity
```
Pre-Boot DMA Protection: firmware must isolate DMA-capable devices'
I/O buffers before ExitBootServices().

ACPI indicators:
- Intel: DMA_CTRL_PLATFORM_OPT_IN_FLAG in DMAR table flags
- AMD: DMA remap support bit in IVRS IVinfo field

Windows PCR[7] event: firmware extends EV_EFI_ACTION with
"DMA Protection Disabled" when IOMMU/Kernel DMA Protection
is disabled, providing attestation hook.

Combined picture:
PCR[0]/PCR[7] anchor firmware and DMA-protection policy,
ACPI tables describe runtime IOMMU config,
documented DMA interfaces show what OS actually remaps,
attestation ties local claims to remote-verified known-good policy.
```

## Layered Detection Pipeline

### Pre-Game Environmental Verification
```
- IOMMU active and applied to DMA-capable PCIe paths
- Interrupt Remapping enabled
- Secure Boot enabled
- VBS/HVCI active
- TPM 2.0 present and provisioned
- Attestation Quote validates against expected policy
- BIOS/UEFI version not in known vulnerable pre-boot DMA list
- ACS topology walk: all relevant bridges enforce SV, TB, RR, CR
```

### PCIe Inventory Pass
```
- Enumerate all PCIe devices via PnP tree
- Full 4 KB config-space dump for each
- Check device problem codes (DEVPKEY_Device_ProblemCode)
- Cross-reference SMBIOS slot inventory with populated devices
```

### Configuration Integrity Per Device
```
- VID/DID/SVID/SDID against known-good list
- Capability-chain walk and validation
- Signature-residue scan
- BAR mask verification
- R/W consistency probing
- Compare against per-donor reference database
```

### Behavioral Sampling During Play
```
- Periodic Link Status reads (LTSSM, ASPM transitions)
- AER counter snapshots
- Per-device interrupt rate and distribution
- Per-device IOMMU fault rate
- BAR-region content sampling for class consistency
```

### Statistical Analysis Over Session
```
- Latency distribution comparison (KS test, Hill estimator)
- Interrupt arrival distribution
- ASPM transition rate
```

### Cheat-Phase Detection
```
- Honeypot region access
- Memory access frequency / locality classifiers
```

### Containment Before Verdict
```
Each detection produces evidence, not a verdict.
Verdict informed by:
- Multi-signal correlation with measured joint error rates; correlated
  signals can share the same false-positive cause
- Server-side aggregation across sessions
- Behavioral verification (input timing, gameplay statistics)

While verdict accumulates, containment protects the live match:
IOMMU re-remapping to sandbox, BME clearance, or EPT-level
game-process protection degrades cheat effectiveness in real time.
```

Apply [`research-rigor`](research-rigor.md) when converting these
signals into a claim or response. Validate baselines per device, firmware,
platform, topology, driver, and power state; preserve raw captures and test
benign alternatives before attribution.

### Realistic Limits
```
A firmware that:
- Clones donor byte-for-byte (full 4 KB config + all capabilities)
- Implements donor-class BAR MMIO, MSI generation, overlay RAM
- Adds completion-latency jitter matching donor distribution
- Generates plausible AER correctable-error rates
- Transitions through ASPM states like the donor
- Uses donor not present in gaming PC and not on blacklists
- Operates only within driver-mapped IOMMU domains (legitimate-path exfil)
- Avoids honeypot regions through gameplay-aware address whitelisting

...can evade the listed PCIe-layer and IOMMU-layer signatures when each is used
in isolation and the emulation matches the defender's tested dimensions.

This is why external trust anchors are required:
TPM attestation, measured boot, and server-side correlation operate
outside the "spoof a PCIe endpoint" problem.

A device cannot forge a TPM Quote signature without the attestation key, but a
valid Quote attests only the selected PCR values and nonce. It does not by
itself prove the absence of a runtime DMA device or the current IOMMU mapping.
The verifier must validate the event log and a policy covering measured
firmware, DMA-protection events, Secure Boot, VBS/HVCI, and IOMMU configuration,
then obtain separate evidence for unmeasured runtime state.

Layering PCIe, IOMMU, hypervisor, and attestation controls raises attacker cost;
whether it exceeds attacker value is an environment-specific economic claim,
not a technical guarantee.
```

## Forensic Evidence Capture

### What to Capture
```
Artifact                     Source                          Purpose
──────────────────────────────────────────────────────────────────────────────
Full 4 KB config dump        Bus interface / ECAM            Donor ID post-hoc
Capability chain walk        Parsed from config              Capability presence
PCIe link state history      Link Status over session        LTSSM anomaly evidence
MSI/MSI-X arrival timeline   OS interrupt telemetry          Rate claim refutation
AER correctable counts       AER capability registers        Baseline outlier evidence
IOMMU fault log entries      WHEA/ETW, Driver Verifier       Invalid-DMA evidence
IOMMU domain assignments     IOMMU manager state walk        Passthrough anomaly
ACS bridge state             Bridge enumeration              Isolation assessment
Honeypot access record       Hypervisor EPT trap log         Unauthorized read evidence
TPM PCR snapshot             TPM Quote API                   Boot-chain attestation
MCFG / DMAR / IVRS tables   ACPI subsystem                  Platform config baseline
SMBIOS slot inventory        DMI subsystem                   Slot-population audit
BIOS version + patch level   SMBIOS                          Pre-Boot DMA fix verify
Latency-distribution hists   Per-session sampling            Statistical fingerprint
```

### Multi-Signal Correlation
```
Strongest evidence packages combine:
1. Hardware-layer signal (config space, BAR, link state)
2. Behavioral-layer signal (interrupt distribution, IOMMU fault rate, honeypot)
3. Temporal correlation (hardware signal preceded behavioral by plausible interval)

No signal count guarantees a target false-positive rate. Establish independence
or model dependence, validate the joint decision rule on representative benign
systems, and report confidence bounds plus expected appeal volume.
```

### PCIe Protocol Captures
```
A PCIe protocol analyzer (interposer) can provide high-fidelity evidence at its
observation point: TLP-level captures with analyzer-specific timestamp accuracy.

Commercial analyzers capture every TLP, DLLP, and physical-layer ordered set.
Traces can be replayed to confirm fingerprinting findings.

Cost and deployment complexity limit routine use. For high-impact cases,
protocol-level captures from an independent lab can materially strengthen the
record, but capture coverage, analyzer configuration, and interpretation still
need validation.
```

## Thunderbolt / USB4 DMA

### Attack Surface
```
- Thunderbolt 1-4 / USB4 provide direct PCIe tunneling
- Hot-plug capable: device can be attached at runtime
- Pre-boot DMA: device has memory access before OS loads
- Thunderbolt Security Levels:
  - SL0 (None): no security, legacy mode
  - SL1 (User Auth): user must approve new devices
  - SL2 (Secure Connect): device must match previously approved UUID
  - SL3 (No PCIe tunneling): completely disables DMA
```

### Thunderbolt-Specific Attacks
```
- Thunderclap: malicious Thunderbolt peripherals bypass IOMMU
- Device re-identification: change UUID to bypass SL2
- OS-level Thunderbolt driver vulnerabilities
- PCIe tunneling through USB4 hubs
```

### Defensive Measures
```
- Kernel DMA Protection (Windows 10 1803+): automatic IOMMU for hot-plug
- Thunderbolt firmware verification
- Platform-level: BIOS setting to disable Thunderbolt PCIe tunneling
- macOS: T2 chip enforces DMA restrictions on Thunderbolt ports
```

## Shadow CR3 / Split TLB

### Page Table Manipulation
```
- Maintain two sets of page tables (two CR3 values):
  - "Clean" CR3: legitimate page tables visible to anti-cheat
  - "Shadow" CR3: modified page tables with cheat-accessible mappings
- Swap CR3 before/after anti-cheat inspection windows
- Combine with EPT manipulation for hypervisor-level split
```

### Split TLB Techniques
```
- Desync instruction TLB (iTLB) and data TLB (dTLB):
  - Execute code from one physical page
  - Read data from another physical page at same virtual address
- Requires precise TLB invalidation control
- Hypervisor can create EPT-based split: execute on page A,
  read on page B, at same GPA
- Anti-cheat mitigation: TLB flush + re-walk, serializing instructions
```

## Memory Access Techniques

### Physical Memory Reading
```c
// Typical pcileech API usage
HANDLE hDevice;
BYTE buffer[0x1000];
pcileech_read_phys(hDevice, physAddr, buffer, sizeof(buffer));
```

### Virtual Address Translation
```c
// Walk page tables: PML4 → PDPT → PD → PT → Physical
PHYSICAL_ADDRESS TranslateVA(UINT64 cr3, UINT64 virtualAddr) {
    UINT64 pml4e = ReadPhys(cr3 + PML4_INDEX(virtualAddr) * 8);
    UINT64 pdpte = ReadPhys(PFN(pml4e) + PDPT_INDEX(virtualAddr) * 8);
    UINT64 pde = ReadPhys(PFN(pdpte) + PD_INDEX(virtualAddr) * 8);
    UINT64 pte = ReadPhys(PFN(pde) + PT_INDEX(virtualAddr) * 8);
    return PFN(pte) + PAGE_OFFSET(virtualAddr);
}
```

### DTB (Directory Table Base) Finding
```
- Scan physical memory for valid CR3 values
- Look for kernel structures
- Use signature scanning
- Validate page table entries
```

## Security Considerations

### Ethical Use
```
- Security research only
- Authorized testing environments
- Responsible disclosure
- Legal compliance
```

### Risk Awareness
```
- Physical hardware access required
- Potential system instability
- Detection by advanced anti-cheat
- Legal implications
```

## Resource Organization

The README contains:
- pcileech and derivatives
- FPGA firmware projects
- DMA libraries
- Integration tools
- Device emulation firmware
- Anti-detection implementations

---
