> **reverse-skill adapter** - AGS `anti-cheat-systems` is installed as a first-class reference under PRIMARY `game-security/` (routing **R43**). This is not a second PRIMARY and not `npx skills add`.
>
> **Auth:** `case-init` + `auth.status=granted` before ACT on a target. Technique catalog / threat-model / authorized-lab RE stay in scope.
> **Deliverable bound:** do not ship a live-title trainer / cheat product. Dump, observe-hook, copy-patch, AC RE, DMA/overlay/kernel catalogs remain required capabilities.
> **Handoff:** quick family-ID table -> ``../anti-cheat-families.md``. Kernel callbacks/IOCTL -> ``kernel-driver-reverse.md``. EDR-like stack -> ``edr-bypass-re/``. DMA detection depth -> ``dma-attack.md``.
> **Fetch links / wiki / archive:** [fetch-upstream.md](fetch-upstream.md). Upstream wiki overview: `wiki/overviews/anti-cheat.md`.
> **Distill:** duplicated Data Source footer removed (one home in fetch-upstream.md). Taxonomy, workflows, and technique catalogs are kept.
>
> Source: [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) (MIT, Copyright 2022 gmh).
---
name: anti-cheat-systems
description: Guide for modern game anti-cheat architecture, Windows kernel monitoring, and detection tradeoffs. Use this skill when analyzing EAC, BattlEye, Vanguard, FACEIT AC, kernel callbacks, handle protection, manual-map detection, boot-start drivers, BYOVD, DMA threats, or behavioral telemetry in game security research.
---

# Anti-Cheat Systems & Analysis

## Overview

This skill covers layered anti-cheat design across kernel drivers, privileged services, in-game components, and backend telemetry. It is most useful for mapping how modern anti-cheats monitor process handles, image loads, memory integrity, driver trust, virtualization abuse, DMA threats, and suspicious input behavior on Windows.

## README Coverage

- `Anti Cheat > Guide`
- `Anti Cheat > Stress Testing`
- `Anti Cheat > Driver Unit Test Framework`
- `Anti Cheat > Anti Debugging`
- `Anti Cheat > Page Protection`
- `Anti Cheat > Binary Packer`
- `Anti Cheat > CLR Protection`
- `Anti Cheat > Anti Disassembly`
- `Anti Cheat > Sample Unpacker`
- `Anti Cheat > Dump Fix`
- `Anti Cheat > Encrypt Variable`
- `Anti Cheat > Lazy Importer`
- `Anti Cheat > Anti-Cheat Programming`
- `Anti Cheat > Compile Time`
- `Anti Cheat > Shellcode Engine & Tricks`
- `Anti Cheat > Obfuscation Engine`
- `Anti Cheat > Screenshot`
- `Anti Cheat > Game Engine Protection:*`
- `Anti Cheat > Open Source Anti Cheat System`
- `Anti Cheat > Analysis Framework`
- `Anti Cheat > Detection:*`
- `Anti Cheat > Signature Scanning`
- `Anti Cheat > Information System & Forensics`
- `Anti Cheat > Dynamic Script`
- `Anti Cheat > Kernel Mode Winsock`
- `Anti Cheat > Fuzzer`
- `Anti Cheat > Windows Ring3 Callback`
- `Anti Cheat > Windows Ring0 Callback`
- `Anti Cheat > Winows User Dump Analysis`
- `Anti Cheat > Winows Kernel Dump Analysis`
- `Anti Cheat > Sign Tools`
- `Anti Cheat > Backup File / Backup Drivers`
- `Anti Cheat > Black Signature`
- `Windows Security Features`

## Major Anti-Cheat Systems

### Easy Anti-Cheat (EAC)
- Multi-component architecture with service, driver, and game-facing protections
- Process integrity verification and memory inspection
- Runtime driver loading with strong client-side enforcement
- Used by: Fortnite, Apex Legends, Rust

### BattlEye
- Kernel driver plus service and game module coordination
- Handle protection, process monitoring, and memory scanning
- Strong focus on injected code and runtime tampering visibility
- Used by: PUBG, Rainbow Six Siege, DayZ

### Vanguard (Riot Games)
- Boot-start kernel driver with early visibility into later-loaded drivers
- Boot-time initialization
- Driver allowlisting and aggressive system trust checks
- Used by: Valorant, League of Legends

### FACEIT AC
- Kernel-level competitive anti-cheat with strong process and driver monitoring
- Emphasis on platform integrity and low tolerance for hostile drivers
- Often discussed alongside Vanguard in kernel anti-cheat research

### Valve Anti-Cheat (VAC)
- User-mode detection
- Signature-based scanning
- Delayed ban waves
- Used by: CS2, Dota 2, TF2

### Other Systems
- **PunkBuster**: Legacy FPS anti-cheat
- **FairFight**: Server-side statistical analysis
- **nProtect GameGuard**: Korean anti-cheat solution
- **XIGNCODE3**: Mobile game protection
- **ACE (Tencent)**: Chinese market protection

## Detection Mechanisms

### Detection Decision Methodology

Use [`research-rigor`](research-rigor.md) for source verification and
empirical validation. Numeric values elsewhere in this skill are examples or
research hypotheses unless they are tied to a representative, versioned
calibration study for the target game.

1. **Define the decision unit:** player, engagement, session, account, device,
   or build; state the game mode, patch, platform, input method, and timeframe.
2. **Establish telemetry trust:** record whether each field is server-observed,
   server-derived, client-reported, or reconstructed. Client reports are
   adversarial inputs; server authority improves trust but does not eliminate
   clock, replication, schema, or game-logic errors.
3. **Keep layers separate:** observation -> finding -> attribution -> action.
   A detector hit is not itself proof of cheating or actor intent.
4. **Calibrate locally:** derive features, sample floors, and operating
   thresholds from representative data. Hold out players/sessions and time
   periods; segment results by relevant populations.
5. **Measure deployment risk:** report prevalence, FPR, FNR, precision, recall,
   calibration, uncertainty, and the expected review volume. A score in
   `[0, 1]` is not a probability unless calibrated as one.
6. **Corroborate correctly:** combine causally distinct signals and evaluate
   their joint errors. Correlated signals, maximum-score aggregation, or a
   fixed signal count do not guarantee a lower false-positive rate.
7. **Review high-impact actions:** preserve counterevidence and an appeal path;
   use human review or independently trusted evidence before punitive action
   when false positives remain plausible.

For invariant findings, first verify that the invariant is guaranteed in the
observed state and exclude rollback, retry, reconnect, replication delay,
legitimate transitions, administrator/test paths, stale baselines, and game
bugs. Describe the result as a state-integrity violation until exploitation and
attribution are separately supported.

Every evidence package should retain the raw artifact or immutable reference,
timestamps and ordering, schema/game/detector versions, feature transforms,
threshold/model version, sample counts, provenance, contradictory evidence,
limitations, and the exact rule that fired.

### Memory Detection
```
- Code section hashing and integrity verification
- Executable private memory and manual-map detection
- Injected module and anomalous image mapping detection
- Memory modification and stack provenance monitoring
```

### Process Detection
```
- Handle access stripping and protected-process enforcement
- Thread start address, APC, and context inspection
- Debug register and hidden-thread monitoring
- Stack trace and module-correlation analysis
```

### Kernel-Level Detection
```
- Driver verification, signature policy, and blocklist checks
- Callback registration and object access monitoring
- System call, dispatch table, and hook integrity checks
- PatchGuard, test-signing, and kernel trust state checks
- Kernel pool scanning (Segment Heap aware) for hidden drivers and shellcode
```

### Kernel Pool Scanning (Segment Heap Era)
```
Why Segment Heap matters for anti-cheat:
Cheat drivers allocate memory in NonPagedPool for shellcode, hook tables,
hidden modules. The Segment Heap (19H1+) changed pool internals:
headers are HeapKey XOR encoded, allocation paths are split (kLFH, VS,
Segment, Large), metadata is isolated. Anti-cheat pool scanners must
understand these mechanisms to scan accurately without false positives.

Detection targets:

1. BigPool / Large Allocation scanning:
   - Walk nt!PoolBigPageTable (nt!PoolTrackTable)
   - Find allocations without corresponding DRIVER_OBJECT or loaded module
   - Detect manually mapped drivers that allocate large pool chunks
   - Large allocations have no inline header; metadata is external

2. VS Allocator chunk scanning:
   - Traverse _SEGMENT_HEAP → VsContext → SubsegmentList
   - Decode _HEAP_VS_CHUNK_HEADER using HeapKey:
     real_sizes = encoded_header ^ chunk_address ^ HeapKey
   - Check decoded chunk for suspicious PoolTag, executable content,
     or allocation without matching driver
   - VS chunks carry both _HEAP_VS_CHUNK_HEADER (encoded) and
     _POOL_HEADER (PoolTag still present)

3. kLFH bucket scanning:
   - _SEGMENT_HEAP → LfhContext → Buckets[] → AffinitySlots → Subsegments
   - kLFH randomizes block placement (harder to predict adjacency)
   - FreeHint encoded with LfhKey
   - Allocation pattern anomalies in specific size buckets can indicate
     pool grooming by cheat drivers

4. Suspicious PoolTag detection:
   - Cheat drivers use custom or rare tags; maintain blacklist
   - Cross-reference tags against known-good tag database (pooltag.txt)
   - Tags present in pool but absent from any loaded module = suspicious

5. Executable memory in NonPagedPool:
   - Find chunks with X permission but no corresponding module
   - Scan decoded chunk content for known cheat signatures, ROP gadgets,
     specific syscall stub patterns

6. Segment Heap integrity checks:
   - Validate the build-specific `_SEGMENT_HEAP` signature/layout using symbols
     and runtime checks (0xDDEEDDEE is observed on relevant layouts)
   - Verify VS chunk header encoding consistency
   - Detect tampered heap metadata (indicates heap exploitation attempt)

Required knowledge for scanner:
- nt!RtlpHpHeapGlobals (HeapKey, LfhKey) — obtained via pattern scan
- nt!ExpPoolQuotaCookie — for ProcessBilled decoding
- Per-pool-type _SEGMENT_HEAP instance addresses (nt!PoolVector)
- Allocation path determination (size → kLFH/VS/Segment/Large)

Anti-cheat KDP integration:
- Store detection rule tables in Secure Pool (ExAllocatePool3 + KDP)
- Correctly configured KDP can protect selected pages from ordinary VTL0 writes,
  including kernel R/W primitives, while the hypervisor and policy path remain
  trustworthy
```

### Behavioral Analysis
```
- Raw input timing and pattern analysis
- Movement and aim anomaly detection
- Statistical improbability and ML-assisted scoring
- Telemetry collection and server-side review
- AI visual aimbot detection (input pattern + gameplay behavior)
```

### AI Visual Aimbot Detection
```
AI visual cheats (screen capture + computer vision + hardware input) can be
among the harder classes to detect because some designs avoid game-memory
access, code injection, and a cheat driver on the gaming PC. Detection then
leans more heavily on trusted behavioral telemetry and contextual signals.

Input Pattern Analysis:
- Mouse movement micro-signature: a particular automation pipeline may retain
  acceleration or correction patterns distinguishable from a matched human
  baseline; this must be demonstrated rather than assumed
- Engagement timing: a given automation pipeline may produce a narrower
  latency distribution than a matched human baseline, but capture, inference,
  transport, smoothing, frame rate, and input hardware make absolute latency
  ranges setup-specific
- Quantization: a specific coordinate-to-HID conversion may leave repeated
  rounding patterns, but integer deltas also occur in legitimate input
- Correction patterns: some smoothing configurations produce repeated
  overshoot-and-settle shapes; compare them with matched legitimate behavior
- Target switching: an explicit automated scoring objective may produce more
  consistent ordering than a matched baseline, but implementations vary

Gameplay Behavioral Signals:
- Anomalous K/D ratio combined with other statistical outliers
- "Snap" engagement pattern: rapid crosshair movement to target
  followed by immediate fire, repeated consistently
- FOV-boundary effect: some configured systems produce a sharper engagement
  cutoff near a chosen radius; estimate it statistically and test alternatives
- Consistent headshot angle distribution that doesn't match
  the player's ranked skill bracket
- Engagement rate: compare visible-target engagement with a matched population;
  high or stable rates are contextual signals, not class rules

Environmental Detection:
- OBS Game Capture may load a graphics-capture hook into the game on supported
  paths; this is legitimate capture evidence, not cheat attribution
- Window/Display Capture backends vary across Windows Graphics Capture,
  BitBlt, Desktop Duplication, OBS version, and source settings
- Frame-transfer detection should account for shared GPU resources, reusable
  staging resources, readback, synchronization, and legitimate capture tools
- Known hardware input device USB VID/PID signatures
  (KMBox, certain Arduino/Teensy boards)
- USB device enumeration anomalies: input device appearing/changing
  mid-session
- Logitech driver version detection: known exploitable G HUB versions
- A known input-filter driver is a contextual signal; legitimate use and actual
  behavior must be established before assigning risk

Server-Side Statistical Analysis:
- Aim trajectory reconstruction from server-received input deltas
- Compare aim distribution against player population at same rank
- Detect systematic per-frame aim correction vectors
  that deviate from matched legitimate distributions
- Cross-session pattern analysis: test whether unusually stable metrics remain
  discriminative after controlling for skill, hardware, and play style
- Replay-based ML classifiers trained on confirmed AI aimbot cases

Anti-AI Countermeasures (Game Design):
- Evaluate ordinary gameplay effects, visual variety, and UI composition for
  model robustness without degrading accessibility or legitimate play
- Server-side aim validation: reject physically impossible aim transitions
- Treat model-targeted visual changes as experiments; adaptive models can
  retrain, and game-design costs may outweigh temporary detection gains
```

### Server-Side Replay Analysis for AI Aimbot Detection
```
Server-side detection can analyze gameplay and input telemetry without relying
on local process-scanning hits. It is a strong complementary layer against
zero-memory AI cheats when telemetry provenance and integrity are trustworthy;
client-uploaded fields remain untrusted until validated.

Input Telemetry Collection:
- Record raw mouse delta (dx, dy) per tick at server tick rate
- Record timestamps at the highest reliable precision supported by the input,
  engine, transport, and clock-synchronization pipeline
- Record crosshair angle / view angle per tick
- Record fire events with corresponding view angle at fire time
- Record damage events with hit location (head/body/limb)
- Collect per-session: total engagement count, hit count,
  headshot count, K/D, average engagement distance

Replay-Based Trajectory Reconstruction:
- Reconstruct full crosshair trajectory from recorded input deltas
- Overlay trajectory onto 3D game state (player positions, obstacles)
- Identify "engagement windows": trajectory segments where crosshair
  moves toward and locks onto a target
- Measure per-engagement: time-to-target, overshoot magnitude,
  correction count, final hold time before fire

Statistical Features for AI Detection:
  (extracted from reconstructed trajectories)

Temporal features:
- Reaction time distribution: time from target visibility to
  first crosshair movement toward target
  → Compare automation and human distributions only within a matched,
    versioned setup; target-visibility definition, tick rate, latency, skill,
    and input method materially change the result
- Time-to-lock distribution: time from engagement start to
  crosshair on target
  → AI: consistent, speed-limited by smoothing algorithm
  → Human: highly variable, depends on initial angular distance

Spatial features:
- Trajectory curvature: some smoothing algorithms produce repeated parametric
  shapes, but both automation and human trajectories vary by configuration,
  device, sensitivity, and task
- Overshoot-correction ratio: compare distributions within matched conditions;
  neither automation nor human behavior has a universal shape
- End-point precision: test for repeated offsets or concentration relative to a
  skill- and context-matched baseline
- Angular velocity profile: treat smoothness and acceleration as measured
  features, not class-defining rules

Engagement pattern features:
- Target selection consistency: automation configured with an explicit scoring
  objective may select targets more consistently than a matched human baseline;
  implementations need not use closest-to-crosshair or confidence ordering
- FOV boundary effect: AI shows sharp engagement cutoff at
  configured pixel radius; humans have gradual falloff
- Engagement rate: percentage of visible targets engaged;
  AI engages more consistently than humans who miss, ignore,
  or react slowly to peripheral targets
- Multi-target switch pattern: AI switches with machine-like
  regularity; humans show grouping and hesitation
```

### ML Classifier for AI Aimbot Detection
```
Feature engineering and model architecture for detecting
AI-generated mouse input at scale.

Feature Vector (per engagement window):
  f1:  reaction_time_ms
  f2:  time_to_lock_ms
  f3:  initial_angular_distance_deg
  f4:  trajectory_curvature_mean
  f5:  trajectory_curvature_std
  f6:  overshoot_magnitude_px
  f7:  correction_count
  f8:  final_hold_time_ms
  f9:  angular_velocity_max_deg_per_sec
  f10: angular_velocity_std
  f11: micro_correction_frequency (small deltas < 2px per tick)
  f12: trajectory_straightness_ratio (distance / path_length)
  f13: dx_dy_correlation (Pearson correlation of delta components)
  f14: delta_magnitude_entropy (Shannon entropy of |delta| sequence)
  f15: fire_timing_relative_to_lock_ms

Session-level aggregate features:
  s1:  headshot_ratio
  s2:  hit_ratio
  s3:  reaction_time_cv (coefficient of variation across engagements)
  s4:  engagement_rate (targets engaged / targets visible)
  s5:  k/d_ratio
  s6:  fov_engagement_boundary_sharpness
  s7:  target_selection_optimality_score
  s8:  trajectory_curvature_consistency (inter-engagement variance)

Model architecture options:
- Gradient Boosted Trees (XGBoost/LightGBM):
  Strong candidate for tabular feature vectors, with fast inference and useful
  diagnostics; validate explanations and deployment fit
- Random Forest: useful baseline; overfitting depends on data and tuning
- 1D-CNN / LSTM on raw delta sequences:
  Operates on raw (dx, dy, dt) sequences instead of engineered features.
  Can capture patterns human engineers might miss.
  Higher compute cost; suitable for batch/offline analysis.
- Ensemble: combine tree-based features and sequence models only when held-out
  evaluation shows a worthwhile gain after calibration and complexity costs

Training data:
- Positive samples: confirmed AI aimbot users (manual review, honeypot,
  or controlled testing with known cheat software)
- Negative samples: legitimate high-skill players (important: include
  top-percentile players to avoid false-positives on skilled play)
- Hard negatives: players with aim-assist controllers (console),
  players using legitimate accessibility tools

Evaluation metrics:
- Choose an operating point from prevalence, error costs, enforcement policy,
  and review capacity; there is no universal acceptable FPR or TPR
- Report FPR, FNR, precision, recall, calibration and confidence intervals on
  representative held-out data, including population slices
- Session-level aggregation can reduce transient noise, but only after
  validating cross-session dependence, drift, and its effect on both FP and FN

Deployment pipeline:
  Client → input telemetry upload (per tick) → server telemetry DB
  → batch feature extraction (per engagement window)
  → ML inference (per session)
  → risk score aggregation (per player, across sessions)
  → threshold → manual review queue or automated action

Adversarial robustness:
- Cheat developers tune smoothing parameters to evade specific features
- Defense: retrain model periodically on newly confirmed samples
- Use feature combinations rather than single-feature thresholds
- Aggregate across sessions only after validating dependence, drift, and
  attacker adaptation
- Evaluate both raw-sequence and engineered-feature models adversarially;
  neither architecture is inherently harder to evade
```

### Hardware Input Device Detection
```
Detecting KMBox and similar hardware input injectors at the
platform/driver level.

USB Enumeration Signals:
- Known VID/PID combinations for KMBox, Arduino Leonardo (2341:8036),
  Teensy (16C0:0486), generic CH340/CP2102 serial adapters
- USB device appearing/disappearing during game session
- Multiple HID mouse devices where only one physical mouse is expected
- USB device with HID mouse capability but no manufacturer string
  or generic "Arduino LLC" / "Teensyduino" manufacturer

USB HID Report Analysis:
- Hardware input devices generate genuine HID reports, but:
  - Report rate: a simplistic injector may expose programmed periodicity, but
    real devices and sophisticated injectors can both show jitter
  - Report timing: some automation pipelines create burst patterns; human and
    legitimate software-assisted input can also be bursty
  - Delta distribution: compare against matched devices, polling rates,
    sensitivity, and movement tasks before drawing conclusions

Network Traffic Indicators (KMBox Net):
- KMBox Net uses UDP communication on the local network
- Packet pattern: consistent-size UDP packets at high frequency
  from a secondary device to the KMBox's IP
- If cheat PC is on the same network: detectable via
  network monitoring (firewall/router logs)

Driver-Level Detection:
- interception.sys: known driver signature, detectable via
  module enumeration and PiDDBCacheTable
- Logitech G HUB DLL injection: detect unexpected DLL loads
  into GHUB process, or specific exploitable GHUB versions
  via file version checking

Limitations:
- Protocol-conformant hardware injection may be indistinguishable from a normal
  mouse from an individual HID report alone; descriptors, timing, provenance,
  and gameplay behavior can still provide imperfect signals
- Device signatures can identify known implementations but are not durable
  attribution; statistical input analysis also requires calibration
- Dual-machine capture can avoid a cheat process on the gaming PC, but still
  leaves ordinary capture/input-device effects and may leave network or device
  telemetry depending on the design
```

## Anti-Cheat Architecture

### User-Mode Components
- Process scanner
- Module verifier
- Overlay detector
- Screenshot capture

### Kernel-Mode Components
- Driver loader
- Memory protection
- System callback registration
- Hypervisor and driver trust detection
- VAD and executable memory inspection

### Hypervisor-Level Components
```
- EPT-based memory access monitoring
- Callback list write protection via EPT hooks
- ETW structure integrity enforcement
- AC driver code page protection (prevent patching)
- VMCALL interface for policy configuration from kernel driver
- VM exit handlers for EPT violations on protected regions
```

### Server-Side Components
- Statistical analysis
- Replay verification
- Report processing
- Ban management

## Research Techniques

### Static Analysis
1. Dump and analyze AC drivers
2. Reverse engineer detection routines
3. Identify signature patterns
4. Map callback registrations and trust boundaries

### Dynamic Analysis
1. Monitor system calls
2. Track driver communications
3. Inspect memory layout and module provenance
4. Debug with kernel or hypervisor tools

## Bypass Categories

### Memory Access
- Physical memory read/write
- DMA-based access
- Hypervisor memory virtualization
- Driver-based access

## DMA Cheat Detection Methodology

### PCIe-Layer Detection Pipeline
```
Detection targets inconsistencies between what a device claims to be
and how it actually behaves. Each technique targets a specific
firmware emulation tier or class of gap.

Configuration Integrity:
- VID/DID/SVID/SDID against known-real-silicon allowlist
- Capability-chain walk: DWord-aligned Next pointers, no overlaps, no cycles
- Signature-residue scanning: Xilinx 7-series default byte patterns,
  Device Capabilities field bits, reserved-field defaults
- Capability presence consistency: donor model must expose expected caps
- BAR mask verification: write 0xFFFFFFFF, compare size mask vs donor

BAR Memory Probing:
- Send Memory Read TLPs to BAR ranges, validate responses by donor class
- NIC BAR0: register layout (ring descriptors, interrupt mask, link status)
- NVMe BAR0: controller registers (CAP, VS, CC, CSTS, AQA, ASQ/ACQ)
- XHCI BAR0: capability registers (CAPLENGTH, HCSPARAMS, HCCPARAMS)
- stock pcileech zerowrite4k returns all-zeros; loopaddr echoes address

R/W Consistency:
- Toggle writable bits (Command BME, Device Control MPS/MRRS, MSI Enable)
- Walk W1C bits (Status, AER Status): write 1s, confirm clear semantics
- Walk reserved bits: write 1s, confirm read-back as 0
- Per-register writable masks must match donor model exactly

Link-State Validation:
- Compare negotiated Width/Speed with slot topology, platform policy, signal
  integrity, and the claimed device; capable devices can legitimately train down
- DLL Active, Slot Clock Config consistency
- ASPM behavioral validation only when ASPM is enabled and the workload,
  observation window, firmware, and platform policy should exercise it

AER Baselining:
- Compare correctable-error rates against per-silicon baseline
- Implausibly clean logs (zero correctables when donor normally
  produces Bad TLP / Replay Timer Timeout) = anomalous
- UR/CA response distribution to probes of unimplemented offsets
```

### Completion Latency Fingerprinting
```
Completion-latency distributions can reflect memory, arbitration, buffering,
power state, link, driver, and workload behavior. A simplistic BRAM-backed
emulator may show unusually low variance, but neither distribution shape is
universal.

Statistical methods:
- Kolmogorov–Smirnov test: compare empirical CDFs vs reference
- Hill estimator: tail index (real silicon has non-trivial tail)
- Anderson-Darling test: sensitive to tail differences

Added random jitter is not equivalent to reproducing a donor distribution.
Validate mean, variance, tails, modes, autocorrelation, and condition changes
against matched hardware.
```

### MSI/MSI-X Behavioral Validation
```
- Device with MSI Enable + programmed Address/Data + attached driver
  should produce interrupts when a verified device condition triggers them
- Zero interrupts when driver should exercise device = anomalous
- Uniform arrival times may indicate timer-driven emulation, but legitimate
  periodic workloads must be excluded
- MSI-X probe: mask vector → induce condition → observe PBA bit →
  unmask → observe interrupt firing. Conforming implementations should preserve
  the expected state transition; incomplete emulations may fail.
```

### Cheat-Phase Access Pattern Recognition
```
One possible pattern is a slow, broad discovery phase followed by narrower,
periodic reads of a smaller offset set during use. Rates and phases vary by
implementation and can be randomized.

Execution phase statistical signature:
- High temporal periodicity
- Low address-space breadth
- Alignment to game-frame intervals
- Distinguishing features: Fano factor, autocorrelation at frame intervals,
  address-space coverage entropy

Honeypot regions effective when combined with IOMMU denial/fault logging,
hypervisor EPT traps, decoy IOVA mappings, or server-side behavioral traps.
```

### IOMMU-Layer Detection
```
Fault-Rate Monitoring:
- Per-device fault rate from IOMMU fault-recording / WHEA
- Establish a platform-, device-, driver-, and workload-specific benign
  baseline; legitimate bugs, resets, firmware issues, and mapping races can
  produce faults
- A sustained nonzero rate is evidence of failed or invalid DMA requests, not
  by itself evidence of cheating or actor intent

Domain Assignment Audit:
- Flag devices on passthrough/identity domains under strict mode
- Flag unexpectedly large IOMMU groups (poor ACS topology)
- Verify multi-function devices sharing Domain ID legitimately

ACS Topology Verification:
- Walk bridge topology, verify Source Validation, Translation Blocking,
  P2P Request/Completion Redirect on every relevant bridge
- Missing/disabled ACS is a potential isolation gap where peer routing is
  possible; confirm the full topology, root-complex behavior, and IOMMU grouping
```

### IOMMU Containment Primitives
```
Before ban verdict, containment protects the live match:

1. IOMMU domain sandbox: reprogram device domain to sandbox memory;
   cheat reads garbage data

2. Bus Master Enable clearance: toggle Command[2] to 0;
   effective for tier-0 through tier-3

3. Downstream Port Containment (DPC): if upstream port supports
   DPC Extended Capability (0x001D), trigger Contained state —
   contain downstream traffic according to the port/platform implementation;
   verify the resulting link and device state

4. Anti-cheat-owned device domain: map only sandbox IOVAs
```

### External Trust Anchors
```
When local kernel/hypervisor trust fails, external anchors close the gap:

TPM Remote Attestation:
- Server sends nonce → client requests TPM2_Quote(AIK, PCR_selection, nonce)
- Verifier checks: AIK signature, certificate chain, EK binding,
  nonce freshness, PCR composite matches known-good policy
- A compromised kernel cannot normally set extend-only PCRs back to an
  arbitrary prior value, but a valid quote still covers only selected
  measurements and not all runtime state

Measured Boot PCR Relevance:
- PCR[0]: UEFI firmware code
- PCR[7]: Secure Boot policy + DMA Protection Disabled event
- PCR[17]: DRTM/Secure Launch measurement

UEFI Pre-Boot DMA Integrity:
- Verify DMAR/IVRS protection indicators
- Cross-check BIOS version against known vulnerable CVE lists
- Verify PCR[7] DMA Protection Disabled event state
```

### Layered Detection Synthesis
```
No single signature is durable. Production pipeline layers:

1. Pre-game: IOMMU active, IR enabled, Secure Boot, VBS/HVCI,
   TPM provisioned, attestation validates, BIOS not vulnerable,
   ACS topology verified

2. Inventory: full 4 KB config dump per device, problem codes,
   SMBIOS slot cross-reference

3. Config integrity: per-donor reference database comparison

4. Behavioral sampling: Link Status, AER counters, interrupt rates,
   IOMMU fault rates, BAR content

5. Statistical analysis: latency distributions, interrupt distributions,
   ASPM transition rates

6. Cheat-phase: honeypot access, access pattern classifiers

Verdict requires multi-signal correlation — single signals can
false-positive. Use causally distinct signals and measure the joint error rate;
correlated detectors can fail together, and no fixed signal count guarantees a
practical false-positive rate.
```

### Firmware Sophistication Tiers (Detection Mapping)
```
Tier 0 (Stock):        VID/DID blacklist catches immediately
Tier 1 (Bridge):       Signature residue, driverless device detection
Tier 2 (Shadow):       R/W consistency probing catches write drops
Tier 3 (Overlay RAM):  BAR probing + class-functional A/B testing
Tier 4 (BAR+MSI):      Interrupt distribution + BAR content baselining
Tier 5 (Behavioral):   Multi-session latency/ASPM/AER statistical analysis
Tier 6 (Private):      Requires external trust anchors (TPM + attestation)
```

### Forensic Evidence for DMA Cases
```
Capture on detection:
- Full 4 KB config dump + capability chain walk
- PCIe link state history (LTSSM, ASPM transitions)
- MSI/MSI-X arrival timeline
- AER correctable counts
- IOMMU fault log entries + domain assignments
- ACS bridge state
- Honeypot access records (EPT trap log)
- TPM PCR snapshot
- MCFG / DMAR / IVRS ACPI tables
- SMBIOS slot inventory + BIOS version
- Completion latency distribution histograms

A useful evidence package combines hardware, behavioral, and temporal signals.
The combined package is stronger only when provenance is trusted, alternative
causes are tested, and the joint false-positive behavior is validated.
```

### Code Execution
- Manual mapping
- Thread hijacking
- APC injection
- Kernel callbacks

### Detection Evasion
- Signature mutation
- Timing attack mitigation
- Stack spoofing
- Module hiding

## Security Features Interaction

### Windows Security
- Driver Signature Enforcement (DSE)
- PatchGuard/Kernel Patch Protection
- Hypervisor Code Integrity (HVCI)
- Secure Boot
- TPM-backed attestation considerations

### Virtualization Detection
- VT-x/AMD-V detection
- Hypervisor presence checks
- VM escape detection
- Timing-based detection

### Hypervisor-Based Defense for Anti-Cheat
```
Concept:
- Use hypervisor (EPT/SLAT) to enforce anti-cheat protections
  from a privilege level above the kernel
- Even if attacker achieves kernel R/W (BYOVD, exploit),
  hypervisor-level enforcement remains intact
- EPT hooks replace traditional kernel hooks:
  operate outside the guest OS, invisible to kernel-level rootkits

EPT Hook Protection Targets:
- Anti-cheat driver executable pages
  → Prevents attackers from patching AC driver code in memory
- Kernel callback lists (PsSetCreateProcessNotifyRoutine, ObRegisterCallbacks)
  → Write authorization moved to hypervisor; kernel-level callback removal denied
- ETW-related structures
  → Unauthorized writes trigger EPT violations, caught by hypervisor
- EPP/AC process memory
  → Protects security software from silent tampering

Hypervisor vs Kernel-Level Threats:
- Common kernel-level attack chain:
  1. Attacker uses BYOVD or kernel exploit for R/W primitives
  2. Patches callbacks to remove AC notifications
  3. Tampers with ETW to disable telemetry
  4. Modifies AC driver code to blind detection
- With hypervisor defense:
  1. Same kernel R/W primitives obtained
  2. Write to protected callback list → EPT violation → VM exit
  3. Hypervisor evaluates context and denies unauthorized modification
  4. AC callbacks and telemetry remain intact

Advantages:
- Higher privilege than the guest kernel under the stated hypervisor threat
  model; ordinary VTL0 writes cannot directly change protected EPT policy
- No guest-kernel patch is required, although hypervisor presence and effects
  may still be observable
- Can remain effective after guest-kernel compromise if the hypervisor,
  configuration path, hardware, and protected policy remain trustworthy
- Complements existing kernel-mode detection (callbacks, signatures, scans)

Limitations:
- Requires hardware virtualization support (VT-x/AMD-V)
- Performance overhead from VM exits on protected region access
- Complexity: must handle nested virtualization (VMware, Hyper-V)
- DMA attacks bypass hypervisor memory protections (separate threat)
```

## Code Protection Techniques

### Page Protection
```
- Executable page guard pages and trap-based integrity monitoring
- NX bit enforcement and DEP policy
- PAGE_GUARD + single-step trap for code coverage without patching
- VirtualProtect monitoring to detect runtime permission changes
```

### Binary Packing & Encryption
```
- PE packers: UPX, Themida, VMProtect, Enigma, MPRESS
- CLR protection: .NET obfuscation (ConfuserEx, Dotfuscator, .NET Reactor)
- Encrypt Variable: runtime value encryption to frustrate memory scanners
- Lazy Importer: compile-time import hiding to avoid IAT-based detection
- Compile-time techniques: string encryption, constexpr obfuscation, COFF obfuscation
```

### Shellcode & Obfuscation
```
- Shellcode engines: position-independent code generation, syscall stubs
- Obfuscation engines: OLLVM-based, custom LLVM passes, MBA (Mixed Boolean-Arithmetic)
- Anti-disassembly: opaque predicates, junk code insertion, control flow flattening
```

## Heartbeat & Screenshot

### Heartbeat Mechanisms
```
- Periodic client-to-server health check packets
- Encrypted challenge-response with server nonce
- Timing-based integrity: detect suspended or debugged processes
- Failure modes: silent disconnect, delayed ban, immediate kick
```

### Screenshot Capture
```
- AC-initiated screen capture for manual or automated review
- BitBlt / PrintWindow / DXGI desktop duplication
- Anti-screenshot evasion: overlay hiding, DWM composition bypass
- Server-side ML classifiers for ESP/overlay detection in captured frames
```

## Telemetry Pipeline

### Client-Side Collection
```
- Module list enumeration and hash reporting
- Handle table snapshots for suspicious access patterns
- Stack trace sampling at periodic intervals
- Driver load events and callback registration state
- Hardware fingerprint (disk serial, NIC MAC, SMBIOS, GPU)
```

### Transport & Server-Side
```
- Encrypted telemetry channel (TLS + custom encryption layer)
- Server-side aggregation and anomaly scoring
- ML-based behavioral clustering for ban waves
- Replay system integration for suspicious session review
```

## Ethical Considerations

### Research Guidelines
- Focus on understanding, not exploitation
- Report vulnerabilities responsibly
- Respect Terms of Service implications
- Consider impact on gaming communities

### Legal Aspects
- DMCA considerations
- CFAA implications
- Regional regulations
- ToS enforcement

## Resources Organization

### Detection Research
```markdown
- Anti-cheat driver analysis
- Detection routine documentation
- Callback enumeration tools
```

### Bypass Research
```markdown
- Memory access techniques
- Injection methods
- Evasion strategies
```

### Tools
```markdown
- Custom debuggers
- Driver loaders
- Analysis frameworks
```

---
