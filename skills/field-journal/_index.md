# 项目经验索引

> 本文件用于在新任务开始前快速检索历史经验。
> 带 `[种子]` 标记的条目是预置参考案例，不计入真实完成项目。
> 真实项目使用日期文件名（例如 `2026-05-16_*`），种子案例使用 `seed-*`。

## 统计

- 真实项目数：16
- 种子参考数：17
- 总条目数：33

## 按场景分类

### APK / Android 逆向

- [2026-07-21_apk-bgeraser-inshot-collagemaker-modnet-mnn-cloud-inpaint-cleanroom](./2026-07-21_apk-bgeraser-inshot-collagemaker-modnet-mnn-cloud-inpaint-cleanroom.md) — "Background Eraser – Remove BG" (`photoeditor.cutout.backgrounderaser`, XAPK), an **InShot/CamerasIdeas collagemaker** editor. 9-agent workflow (6 readers + 2 adversarial verifiers + synth) mapped 3 cores: **BG removal = on-device MODNet matting** via **MNN 3.2.4** over an **AES-128-CBC-encrypted** `image_matting.model` (16-byte key+IV located in `libimagematting .rodata`, values withheld; `1×3×512×512` NCHW, longest-side letterbox, ImageNet norm with non-canonical B-std 50.625; `nInit` gated by `libchk.so` anti-repackage from `cer.json`); **object removal = CLOUD** (`ImageRemovePresenter` → Firebase Storage upload `bgeraser_inpaint/upload/...` + hybrid AES+RSA `POST ai.inshot.cc/bg/inpaint/predict/v2/` + poll `inshot.cc/collage-ai-asia/`; native `token`+Play-Integrity headers) while the shipped native `CVALGO::inpaint_telea` is **dead code**; manual eraser = Canvas `DST_OUT`/`SRC_IN`+BlurMaskFilter, magic-wand = `PortraitMatting.nativeAuto`→`CVALGO::flood_fill`; AI-bg = cloud txt2img; config = in-house `Ad0` ServerData; strings = `Qw0`→libpccore XOR. Clean-room Kotlin app (**U²-Net via ONNX Runtime** behind a `Matter`==`ImageMattingUtils` interface + exact-reversed `MattingPreprocessor`, ML Kit fallback; OpenCV Telea inpaint = the offline path the original left dead; mock-first cloud + prompt→gradient AI-background), **device-verified on Pixel API 35** (portrait → transparent cutout; AI-bg sunset composite). Sibling of [[2026-07-07_apk-beautycam-meitu-mtee-cleanroom-native-reuse]] (on-device CV) + [[2026-07-18_apk-aiphoto-atlaszz-azcore-cipher-cleanroom]] (cloud+attestation)
- [2026-07-16_apk-rapidtv-bytedance-shortplay-sdk-multitenant-credential-boundary](./2026-07-16_apk-rapidtv-bytedance-shortplay-sdk-multitenant-credential-boundary.md) — RapidTV (com.rapid.short.tv), built on ByteDance's white-label Short Play SDK (api.dramaverses.com); fully mapped endpoint catalog + AES/native-cipher + per-tenant HMAC auth from unobfuscated com.bytedance.sdk.shortplay.internal; **deliberately did not build a live client** — shared multi-tenant paid content-licensing backend, not a self-hosted catalog, so recovered appId/securityKey were documented but not used; shipped as a mock-only structural port (RapidShortPlayRepository) into ShortsApp instead
- [2026-07-16_apk-goodshort-newreading-shorts-feed-rsa-sign-cleanroom](./2026-07-16_apk-goodshort-newreading-shorts-feed-rsa-sign-cleanroom.md) — GoodShort (com.newreading.goodreels) short-drama; extracted Discovery (home/index, home/nav/list) + Shorts (book/recommend immersive feed, chapter/load) APIs; recovered RSA-SHA256 request signing (hardcoded in-APK PKCS#8 key over "timestamp="+ts+body+ids+certMD5+pkg); clean-room Kotlin/MVVM ViewPager2-vertical + Media3 ExoPlayer app at ~/Projects/Android/ShortsApp; later re-skinned as "DramaStream" onto the same core from an imported Claude Design mockup (5-tab nav, onboarding, local-simulated coin/VIP economy, edge-to-edge inset bugs); same-day follow-up added a mock-only port of a sibling app's (RapidTV) API shape
- [2026-07-15_apk-tvremote-codematics-ir-pronto-multiprotocol-cleanroom](./2026-07-15_apk-tvremote-codematics-ir-pronto-multiprotocol-cleanroom.md) — Universal TV Remote (codematics); dual-path remote = IR Pronto DB (136 brands/8011 codes scraped to JSON assets) + 6 network protocols (Roku/Samsung/webOS/Vizio/FireTV/Android TV v2) behind one Kotlin interface; clean-room Compose rebuild builds+runs
- [2026-07-13_apk-remakeface-faceswap-signed-cloud-protocol-cleanroom](./2026-07-13_apk-remakeface-faceswap-signed-cloud-protocol-cleanroom.md) — RemakeFace AI face-swap; "encrypted" = device-attestation + ECDSA-P256 request signing over a cloud API; reversed full protocol + runnable Node client+mock reproduction
- [2026-07-07_apk-beautycam-meitu-mtee-cleanroom-native-reuse](./2026-07-07_apk-beautycam-meitu-mtee-cleanroom-native-reuse.md) — Meitu BeautyCam (myxj) clean-room repro; reuse .so/assets/icon + reconstruct MTEE beauty-engine JNI contract; assembleDebug SUCCESSFUL
- [2026-07-04_apk-makeupplus-meitu-cleanroom-native-reuse](./2026-07-04_apk-makeupplus-meitu-cleanroom-native-reuse.md) — Meitu MakeupPlus native-reuse-first rebuild (sibling scaffold)
- [2026-07-04_apk-filerecovery-azcore-string-cipher-cleanroom](./2026-07-04_apk-filerecovery-azcore-string-cipher-cleanroom.md) — cracked libazcore native string cipher; recovery core clean-room
- [2026-05-15-cellular-pro-mumu-ksad-fragment-fix](./2026-05-15-cellular-pro-mumu-ksad-fragment-fix.md)
- [[种子] seed-008_apk-okhttp-ssl-pin-bypass](./seed-008_apk-okhttp-ssl-pin-bypass.md)

### 二进制 / 固件 / CTF

- [2026-07-14_android-arm64-self-extract-source-recovery](./2026-07-14_android-arm64-self-extract-source-recovery.md)
- [2026-05-15_lumine-go-reverse](./2026-05-15_lumine-go-reverse.md)
- [[种子] seed-001_elf-packed-loader](./seed-001_elf-packed-loader.md)
- [[种子] seed-002_go-malware-stripped](./seed-002_go-malware-stripped.md)
- [[种子] seed-010_ctf-pwn-rop-x64](./seed-010_ctf-pwn-rop-x64.md)
- [[种子] seed-011_pcap-protocol-reverse](./seed-011_pcap-protocol-reverse.md)
- [[种子] seed-014_unity-il2cpp-reverse](./seed-014_unity-il2cpp-reverse.md)
- [[种子] seed-015_iot-firmware-uart](./seed-015_iot-firmware-uart.md)

### Web / API / 渗透测试

- [2026-07-18_gin-juice-client-friction](./2026-07-18_gin-juice-client-friction.md)
- [2026-07-05_dsl-vm-captcha-reverse](./2026-07-05_dsl-vm-captcha-reverse.md)
- [2026-06-29_burp-mcp-full-test-and-fix](./2026-06-29_burp-mcp-full-test-and-fix.md)
- [2026-05-26_pentest-newapi-rate-limit-bypass](./2026-05-26_pentest-newapi-rate-limit-bypass.md)
- [2026-05-25_pentest-cf-access-sibling-subdomain-cookie-poisoning](./2026-05-25_pentest-cf-access-sibling-subdomain-cookie-poisoning.md)
- [2026-05-17_pentest-vue-spa-actuator-leak](./2026-05-17_pentest-vue-spa-actuator-leak.md)
- [2026-05-16_pentest-personalblog-fun-mass-assignment](./2026-05-16_pentest-personalblog-fun-mass-assignment.md)
- [[种子] seed-003_web-api-auth-bypass](./seed-003_web-api-auth-bypass.md)
- [[种子] seed-004_js-sign-webpack](./seed-004_js-sign-webpack.md)
- [[种子] seed-006_ssrf-cloud-metadata](./seed-006_ssrf-cloud-metadata.md)
- [[种子] seed-017_xxe-oob-exfil](./seed-017_xxe-oob-exfil.md)

### 企业内网 / 云安全

- [[种子] seed-005_ad-certipy-esc1](./seed-005_ad-certipy-esc1.md)
- [[种子] seed-007_ntlm-relay-coercer](./seed-007_ntlm-relay-coercer.md)
- [[种子] seed-013_kerberoasting-spn](./seed-013_kerberoasting-spn.md)
- [[种子] seed-016_k8s-container-escape](./seed-016_k8s-container-escape.md)

### iOS 逆向

- [[种子] seed-009_ios-jailbreak-detect-bypass](./seed-009_ios-jailbreak-detect-bypass.md)

### 其他

- [[种子] seed-012_log4shell-jndi-rce](./seed-012_log4shell-jndi-rce.md)

## 使用说明

1. 新任务开始前，先按场景分类查找是否有相似记录。
2. 命中真实项目时，优先复用已验证的流程和踩坑记录。
3. 命中种子案例时，只作为方法参考，不视为真实成功记录。
4. 新增经验后，请按 PR 流程更新本索引，避免直接改动共享主线。
