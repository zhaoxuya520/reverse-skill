# APK — Background Eraser (InShot/CamerasIdeas collagemaker) → clean-room BG-removal + object-removal core

- **Date**: 2026-07-21
- **Target**: `photoeditor.cutout.backgrounderaser` v2.351.105 ("Background Eraser – Remove BG"), an XAPK/APKS bundle (base + arm64/armv7 splits, 48 MB). User-owned; goal = analyze + clean-room repro of the background-removal and object-removal cores.
- **Auth**: granted (owner's APK, interop study + clean-room rebuild). Standard reverse per precedent-reverse.
- **Tools**: jadx 1.5.5, apktool, r2/rabin2, strings, unzip (all "yes" in tool-index). No install needed.

> Note: concrete secret VALUES (the model's AES key/IV, the app's Firebase/AdMob keys) are intentionally withheld from this public note — the method and byte-offsets are recorded, the raw keys are not, since they would decrypt a third party's commercial model / expose their cloud project.

## Method
1. XAPK bundle → `manifest.json` reveals package + 3 splits. Base APK: `assets/image_matting.model` (5 MB, entropy 8.0 → encrypted), `classes.dex`×2, **no .so in base** (natives in config splits).
2. Native triage (`rabin2 -qs`, `strings`) on arm64 split → the whole engine stack: **libMNN.so** (Alibaba MNN), **libimagematting.so** (C++ `ImageMatting::image_matting_init/run/release`, JNI class `a/bd/jniutils/ImageMattingUtils`, dynamic RegisterNatives), **libcvalgo.so** (`CVALGO::inpaint_telea`, `erode_mask`, `dilate_mask`, `get_mask_edge`), face libs, SpillSDK, ByteDance PAG, apminsight.
3. jadx on base → identity: **`com.camerasideas.collagemaker`** (InShot). Key classes: `ImageMattingUtils`, `C1211cd0` (SegMatting), `C1091bN` (`ImageRemovePresenter`, cloud inpaint), `PortraitMatting` (magic-wand), `CutoutEditorView`.
4. Fanned out a 9-agent Workflow (6 subsystem readers + 2 adversarial verifiers + synthesis) → authoritative report (kept in the clean-room project as `ANALYSIS.md`).

## Verified findings (architecture)
- **Background removal = on-device MODNet matting.** `image_matting.model` = **AES-128-CBC** encrypted MNN flatbuffer; **16-byte key + IV recovered from `libimagematting.so .rodata`** (@~0x2db0 / 0x2da0; values withheld here). MODNet + MobileNetV3-Large backbone. Input **1×3×512×512 fp32 NCHW**, longest-side letterbox top-left (zero-pad), normalize mean `[123.675,116.28,103.53]` inv_std `[0.0171247534,0.0175070036,0.0197530873]` (**non-canonical B std 50.625** — retrain artifact; == ImageNet in 0..255). Output 1-ch alpha → ALPHA_8 mask → composite via SpillSDK edge-decontamination or PorterDuff `SRC_IN` fallback. `nInit(sha1[], packageName, modelPath)` calls **libchk.so::sub_2087** anti-repackage gate (from `cer.json`) → returns `-103` on tamper; MNN loader only ever gets the model path.
- **Object removal (real "remove object") = CLOUD.** `ImageRemovePresenter` uploads source `.jpg` + brushed mask `.png` to **Firebase Storage / GCS** bucket `stn2_collage_ai_asia` (key `bgeraser_inpaint/upload/<yyyy-MM-dd GMT+8>/<uuid>.<ext>`), POSTs `{image_name,mask_name,nb}` (hybrid AES-CBC body + RSA-wrapped key → `{rv,ki,data}`, headers incl. native `token` + Play Integrity `X-Integrity-Token`) to `https://ai.inshot.cc/bg/inpaint/predict/v2/`, then polls `https://inshot.cc/collage-ai-asia/<image_url>` 30×1.5 s.
- **`CVALGO::inpaint_telea` is DEAD CODE** — exported but zero importers / no JNI. The on-device "removal" is only Canvas erase-to-transparent (`CutoutEditorView`, PorterDuff `DST_OUT`/`SRC_IN`, BlurMaskFilter) + magic-wand flood-fill (`PortraitMatting.nativeAuto`→`CVALGO::flood_fill`, tolerance 0..100). **No GPUImage** in the cutout path.
- **AI Background = cloud txt2img** (`/bg/txt2img/predict/v2/`, no image, composited locally by `ItemView`). Sibling `/bg/<feature>/predict/v2/` endpoints (enhance/expand/cartoon/ai_bg/avatar). Remote config = in-house `Ad0` ServerData (**not** Firebase RC). String cipher `Qw0.d`→libpccore.so (URL-safe b64 + even-index XOR, cmdline-gated).

## Clean-room build (WORKS, device-verified)
Kotlin app (minSdk 26, AGP 8.7.2 / Gradle 8.11.1). Legal substitutes wired to the reversed interfaces:
- BG removal → **U²-Net (u2netp) via ONNX Runtime** (real NCHW matting, closest analogue to MNN+MODNet) behind a `Matter` interface == `ImageMattingUtils`; `MattingPreprocessor` reproduces the EXACT letterbox + normalization (unit-tested; the reversed constants are identically ImageNet, so they drive u2netp too). **ML Kit Selfie Segmentation** as automatic fallback.
- Mask feather/morphology → **OpenCV** erode/dilate/GaussianBlur; magic-wand → Kotlin BFS `FloodFill`.
- Local object removal → **OpenCV `Photo.inpaint(INPAINT_TELEA)`** (the offline path the original left dead).
- Cloud inpaint + AI-background → clients mirroring the protocols (object-key/form/poll; txt2img form body), **mock by default** (token + Play Integrity not forgeable clean-room; AI-bg synthesizes a prompt→gradient background and composites locally like the original).
- **Verified on Pixel emulator API 35**: pick portrait → "Xóa nền" → clean transparent cutout (ONNX u2netp session loaded, `input.1`→d0); "AI Nền: sunset" → foreground composited over a generated sunset gradient. `assembleDebug` + unit tests green; `OpenCV loaded: 4.11.0`.

## Gotchas
- OkHttp 4.12 `MediaType.get(String)` is an **ERROR-level** deprecation → use `String.toMediaType()`.
- ML Kit `SegmentationMask.getBuffer()` is a **ByteBuffer of floats** → read with `buffer.float`, not `get()`.
- ONNX Runtime: query `session.inputNames`/`outputNames` at runtime (u2netp input `input.1`, 7 outputs, `[0]` = d0 saliency); u2net has no final sigmoid → **min-max normalize** the output before use.
- OpenCV Maven `org.opencv:opencv:4.11.0` bundles native libs (`OpenCVLoader.initLocal()`), but the `.so` (OpenCV + ONNX + libc++) aren't 16 KB-aligned → Android 15 "page size compatible mode" notice (harmless debug; needs 16 KB-aligned libs for Play).
- Edge-to-edge is forced at targetSdk 35 → root layout needs `fitsSystemWindows="true"` or the top bar sits under the status bar.
- Debug APK ~347 MB (ONNX + OpenCV + ML Kit native libs for 4 ABIs).

## Reuse
Sibling of prior on-device-CV repros. Same shape as MakeupPlus/BeautyCam (Meitu MTEE native-reuse) but here the matting model is cleanly swappable (ONNX/MNN/TFLite MODNet/U²-Net). Cloud-protocol reversing mirrors RemakeFace/AIPhoto (device attestation blocks clean-room cloud calls → mock). The InShot `ai.inshot.cc/bg/<feature>/predict/v2/` family + `Ad0` ServerData + `Qw0`/libpccore string cipher are reusable across other InShot editors.
