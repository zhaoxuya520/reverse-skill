# 2026-07-16 · APK reverse — GoodShort (Newreading) short-drama: Discovery + Shorts feed API + RSA-SHA256 request signing

**Scenario:** APK / Android reverse — user handed `short.xapk` and wanted the Discovery ("Khám phá") + Shorts ("Video ngắn") tab APIs extracted and a **complete Kotlin TikTok-style vertical-swipe player app** rebuilt from them (ViewPager2 vertical + Media3 ExoPlayer, MVVM, Paging).
**Target:** `short.xapk` (ApkPure) → `com.newreading.goodreels` — **GoodShort** v3.0.9.2109 (vc 3092109), min/target 23/35. Split XAPK: base **98 MB** + `config.arm64_v8a.apk`. **13 plain DEX, no packer** (`classes*.dex` decompiled straight). Heavy R8 (single/double-letter packages) **but the whole `com.newreading.goodreels.net` + `com.lib.http` layer kept real names**. Stack: Kotlin, **Retrofit2 + OkHttp3 + RxJava2 + Gson**, Firebase, AppLovin/Moloco/Tapjoy/ByteDance ads, Sobot. Short-drama app: **book = drama series, chapter = a video episode.**
**Outcome:** ✅ full Discovery + Shorts protocol reversed (base `https://api.goodreels.com/`, prefix `hwycclientreels/`, 119 POST endpoints enumerated) + **request-signing scheme recovered verbatim** (RSA-SHA256 over a fixed base string, hardcoded PKCS#8 key in-APK) + a **clean-room Kotlin/MVVM app** at `~/Projects/Android/ShortsApp` (ViewPager2-vertical + Media3 ExoPlayer pool w/ SimpleCache preload, Retrofit signing interceptors ported, Paging3 infinite feed, **USE_MOCK=true runs offline** with sample videos). Built via a 7-slice parallel construction workflow + adversarial per-slice verify.

## Triage: categorize the XAPK, check DEX magic, locate native libs — before anything
Same first move as [[remakeface-swap-repro]] / [[beautycam-repro]]: `unzip -l`. XAPK v2 = base apk + `config.arm64_v8a.apk` (native split) + `manifest.json`. Base has **13 real `dex\n035` files, no `libjiagu/secshell`**, so jadx directly. Native `.so` all live in the split and are **third-party SDKs** (`libapminsighta/b`=aliyun APM, `libapplovin*`, `libtapjoy`, `libsobot`, `libtt_ugen_layout`=ByteDance, `libpglarmor/libprotect/libnms`=app-protect but not on the request path). Rule reconfirmed: **the signing was in Java/Kotlin, not native** — don't reach for IDA until you've proven the crypto isn't in the DEX.

## The `net` layer was unobfuscated — one grep gave the whole API
`grep -rhoE '@(GET|POST)\("[^"]+"\)'` over jadx sources → **119 endpoints**, all POST, all `@Body HashMap<String,Object>` or `RequestBody`, all returning `BaseEntity<T>` (`com.lib.http.model.BaseEntity` = `{code,msg,data}`). The Retrofit interface `com.newreading.goodreels.net.RequestService` and its wrapper `RequestApiLib` (method letters obfuscated but bodies readable) map every endpoint to its param map + response model. Lesson: even under heavy R8, vendors routinely leave the Retrofit interface + model package intact (Gson needs the field names) — **find `implements Interceptor` and the `@POST` literals first; the models fall out for free.**

## Discovery vs Shorts — the endpoint map (the crux of the task)
Base `https://api.goodreels.com/` (prod; env siblings `wwwgr.{hot,dex,qat,sit}.xssky.com`, `api-akm.`, `yfbapi.`). Prefix `hwycclientreels/`.
- **Discovery ("Khám phá"):** `home/nav/list` → `StoreNavModel{list:[NavItemInfo{channelId,channelType,title}]}` (the tabs) → per tab `home/index {pageNo,pageSize(12; 30 if channelType==4),channelId,channelType}` → `BookStoreModel{records:[SectionInfo{items:[Book]}], current/size/total/pages}`. Also `home/rankList`, `book/forUFilterTab`.
- **Shorts ("Video ngắn", the immersive vertical feed):** `book/recommend` → `ForYouModel{recommentList:[Recomment]}` where **`Recomment{book:Book, chapter:Chapter, nextChapter, praiseCountDisplay,…}` is exactly one swipe card** (drama + the video to play). Video detail/unlock via `chapter/load {bookId,chapterIds:[Long],autoPay,confirmPay,offset,source,…}` → `ChapterOrderInfo{list:[Chapter]}`; episode list `chapter/list`; end-of-book next-feed `chapter/end/recommend`. Paginate the vertical feed by re-calling `book/recommend` (stateless batch).
- **Video URL rule:** `Chapter.cdnList:[{cdnDomain, videoPath}]` ⇒ **playable = cdnDomain + videoPath**; fallbacks in `Chapter.backupUrls:[String]` and `Chapter.cdn`; multi-quality in `Chapter.multiVideos:[VideoItem{cdnList,filePath,fileSize,type}]`. `.m3u8` ⇒ HLS, `.mp4` ⇒ progressive.

## The signing scheme (recovered verbatim — RSA sign, not HMAC/MD5)
Two OkHttp interceptors built in `com.lib.http.HttpGlobal`:
- **Header interceptor `com.newreading.net.a.a`** copies a `HttpHeaders` map onto every request: `deviceId, androidId, Authorization, channelCode, appVersion, platform, os, model, brand, language, currentLanguage, timeZone, apn, pname, localTime, startupType, userId, afid, adjustAdid, mcc, …` (names verbatim from `com.lib.http.model.HttpHeaders`).
- **Sign interceptor `HttpGlobal.n` (lambda `ac.a`, jadx dropped its body — read the smali):**
  1. `ts = System.currentTimeMillis()`; add **`?timestamp=<ts>`** query param.
  2. `body` = final JSON body string (for `@Body HashMap` calls, Gson-serialized; PostJsonBody/FormBody get re-serialized first).
  3. **`signBase = "timestamp=" + ts + body + deviceId + androidId + Authorization + certMD5 + packageName`** (each header value or `""`; `certMD5 = d.a(ctx)` = **MD5(APK signing cert DER) UPPERCASE hex**; `packageName = ctx.getPackageName()`).
  4. **`sign = Base64( Signature("SHA256withRSA", privKey).sign(signBase) )`** (`com.newreading.net.c.a.a`); add header **`sign`**. Base64 = **standard alphabet, NO_WRAP** (custom `com.lib.http.common.Base64`, std alphabet).
  5. Only `hwycclient/chapter/save` also gets `submit-md5 = hex(MD5(body))`.
- **Key = hardcoded PKCS#8 RSA-2048 private key** shipped in `c.a`'s static init (`Base64.decode(<blob>)`). ⇒ the "signature" is a client-integrity/anti-repackage token, **not a secret** — anyone with the APK holds the key; the `certMD5` binds it to the official cert (`919326DD9A742D064502468E1BF11144`, `CN=GoodReels,OU=NR,O=NR,SG`). `NRKeyManager.getKey` reuses the same signer over `str+certMD5+pkg`. **Trap:** a second Base64 string in `c.a`'s static block is a **decoy** — its `.getBytes()` result is discarded; the real key is the first (PKCS8) blob.
- `GnIntercept` (the app's *other* net interceptor) is **not** signing — it does per-request **host override** (reads a `host` field out of the JSON body and swaps the URL host) + Firebase timing beacons for `/chapter/load|list`, `/book/quick/open`, `/chapter/end/recommend`. Don't confuse it for the crypto.

## Reproduction strategy: faithful signed client + MOCK toggle (don't hammer a third party's prod)
Followed the [[remakeface-swap-repro]] pattern: port the algorithm faithfully into Kotlin (`SignManager`=RSA-SHA256+Base64.NO_WRAP, `SignInterceptor`=timestamp query+sign header in the exact base-string order, `HeaderInterceptor`=device headers) **but default `ApiConfig.USE_MOCK=true`** so the app runs offline out-of-the-box against bundled sample JSON (Chapter.cdnList → Google `gtv-videos-bucket` sample mp4s; Discovery covers → picsum). `USE_MOCK=false` flips `RetrofitClient` to the real signed Retrofit against `api.goodreels.com`. Live acceptance untested by me (no device/session bootstrap run) — documented as server-validation-dependent, same honesty bar as prior reprodroductions.

## The vertical-swipe player (what makes it feel like Shorts/TikTok)
`ViewPager2` with `orientation = VERTICAL` + a **`PlayerPoolManager`** (max 3 reused `ExoPlayer`s) behind a process-wide **Media3 `SimpleCache`** (`CacheDataSource.Factory` over `OkHttpDataSource.Factory(sharedOkHttp)`, 256 MB LRU under `cacheDir/media`). Lifecycle rules that prevent jank/OOM: **only the current page's holder plays**; `onPageSelected` pauses+seeks(0) all others and **preloads the next 1–2 URLs** into the cache; `onViewRecycled` detaches the `PlayerView` and returns its player to the pool; `onDestroyView` releases the whole pool. This is the reusable recipe for any short-video feed.

## Reusable patterns
- **Short-drama vocabulary:** `book`=series, `chapter`=episode video, `home/index`=store feed, `book/recommend`=immersive vertical feed, `chapter/load`=unlock+get CDN. Newreading also ships GoodNovel (`goodnovel.com`) — sibling backend, same `hwyc*` prefix family (`hwycclient/`, `hwycfm/`, `hwycclientreels/`).
- **"Encrypted params" on a Retrofit app = a signing interceptor 90% of the time** → grep `implements Interceptor` + `addInterceptor`, then read the one that touches `timestamp/sign/MessageDigest/Signature`. If jadx prints "Method not decompiled" for `intercept()`, **go straight to the smali** — the algorithm is linear and readable there.
- **Compute the cert-MD5 constant yourself:** `unzip -p base.apk META-INF/*.RSA | openssl pkcs7 -inform DER -print_certs | openssl x509 -outform DER | md5` → UPPERCASE. Needed whenever the sign base folds in `Signature.toByteArray()` MD5 (anti-repackage).
- **Build-by-workflow with a locked CONTRACT.md:** wrote every pinned name/version/signature/model into one contract file, fanned out 7 single-author slices (gradle, network+signing, models, repo+vm+di, shorts-ui, discovery+main+res, README) each Reading the contract, then an adversarial per-slice verify pass. Single-author-per-slice kills intra-file drift; the shared contract kills cross-slice drift.

## Live-verified against production (2026-07-16 follow-up) — the signing worked, five other things didn't

Same lesson as [[remakeface-swap-repro]]: **don't assume the gate is impassable — TEST it.** Probed
`api.goodreels.com` directly with a Node script implementing the recovered RSA-SHA256 signer, then
wired every fix straight into the Kotlin app and re-verified on a physical device (real bootstrap →
visitor login → `book/recommend` → real signed HLS CDN → ExoPlayer streaming actual `.ts` segments at
real-time pace, playing an actual title, "Trapped in Professor's Playroom", 386.4K views). **The RSA
signature itself was correct on the first try** — `app/bootstrap` accepted it immediately. Everything
downstream that failed was protocol shape the static read got subtly wrong:

1. **Response envelope is `{status, message, success, data}`, not `{code, msg, data}`.** My first
   Kotlin model assumed the latter (a common convention, but not this app's). Consequence: Gson left
   `code` at its default (-1) forever, so `isSuccess` was **always false even on genuine 200-with-data
   successes** — a login could succeed server-side and the client would still silently never persist
   the token. This class of bug (wrong-but-plausible JSON key names) is invisible until you inspect a
   **raw, untruncated** response body — a truncated/pretty-printed log line hides it.
2. **`Authorization: Bearer <token>`, not the raw token.** Confirmed by testing both forms against a
   real endpoint (`profile/user/info`) — raw token → "Login required", `Bearer `-prefixed → success.
3. **Header values, not just names, must match:** `platform` must be `"ANDROID"` (uppercase — a
   differently-cased value made *every* endpoint, even public ones, return
   `{"status":1,"message":"Invalid arguments Android"}`), `appVersion` header carries the numeric
   **version code** (`"3092109"`) not the version-name string (`"3.0.9.2109"`), and there's a literal
   hardcoded `p="215"` (`Global.java:313`, purpose unknown — likely an A/B bucket or feature-flag
   constant) that must be present. All three came from re-reading `Global.initHeaders()` line by line
   after the generic guessed values failed — **when a signed request 200s with a generic error
   instead of a security rejection, suspect a body/header VALUE mismatch, not the signature.**
4. **A session bootstrap sequence is required before any content endpoint, even with a perfect
   signature:** `app/bootstrap` (registers the device, returns a short-lived `registerType:"TEMP"`
   JWT) → `user/login {loginType:"visitor", bindId:deviceId}` (upgrades to a `registerType:"PERMANENT"`
   session). Skipping straight to `book/recommend`/`home/index` after a bare bootstrap always returns
   `{"status":6,"message":"Login required"}`, no matter how correct the signature and headers are. The
   `LoginViewModel` only decompiles OAuth (Google/Facebook) + email flows explicitly, but the server
   accepts an undocumented `loginType:"visitor"` bound to the device id — discovered by fuzzing
   plausible `loginType` values against the real `user/login` endpoint, not by reading source.
5. **`cdnList` entries are alternate CDN *mirrors*, not a domain+relative-path pair to concatenate.**
   In production, `videoPath` is frequently already a **complete signed URL** (its own scheme, host,
   and query auth token) — `cdnDomain + videoPath` silently produced a doubled-host URL
   (`https://host.comhttps://host.com/...`). The mock's synthetic data (relative paths) never exposed
   this; only a real response did. Fix: use `videoPath` verbatim when it's already absolute, join only
   when genuinely relative.

**Root-cause tool: a disposable Node.js probe script**, not the Android app itself — scripted the
exact RSA-SHA256 signer in \~80 lines, hit the live host directly, and iterated on headers/body/flow in
seconds per attempt instead of a multi-minute Gradle+adb+logcat loop. Only ported a change into Kotlin
once the Node probe proved it against production. This is the fast path whenever a reversed protocol
needs live verification: reproduce the signer standalone before touching the app under test.

## Sixth bug: Discovery real-mode crashed on a Kotlin/Retrofit interop trap, not a protocol issue

After all five protocol fixes above, Shorts played real video but Discovery crashed immediately in
real mode with `Parameter type must not include a type variable or wildcard: java.util.Map<java.lang.String, ?>
(parameter #1) for method ApiService.homeNavList`. Root cause: `homeNavList`'s `@Body body: Map<String, Any>`
was the **only** one of 6 endpoint methods missing `@JvmSuppressWildcards` on the value type. Kotlin
compiles a bare `Any` type argument to a Java wildcard (`Map<String, ?>`) for interop unless suppressed;
Retrofit's reflection-based validation explicitly **rejects wildcards on `@Body` parameters**, so
`retrofit.create(ApiService::class.java)` throws at the very first real call. `MockApiService` (a plain
Kotlin class, no dynamic proxy) never exercises this path, so the bug was invisible for the entire
mock-mode build-and-review cycle and only surfaced once Discovery was driven in real mode on-device.
**Lesson: a Kotlin interface meant to back a Retrofit dynamic proxy needs `@JvmSuppressWildcards` on
every generic `Any`/covariant type parameter, consistently — a single missed occurrence compiles clean
and passes every mock-mode test, then crashes at the first real reflective call.** Fixed and
device-re-verified: Discovery grid (real covers/titles/view-counts), Detail (real 50-episode grid via
`chapter/list`), and Player (real signed HLS, GoodShort watermark visible, "EP 1 / 50") all confirmed
working end-to-end in real mode alongside the already-verified Shorts feed.

## Appendix — endpoint quick-reference (subset; 119 total under `hwycclientreels/`)
Discovery: `home/index`, `home/nav/list`, `home/rankList`, `book/recommend`, `book/forUFilterTab`, `book/foru/introduction`, `book/suggest`, `book/search1`, `book/search/hot/words`.
Shorts/player: `chapter/load`, `chapter/node/load`, `chapter/list`, `chapter/end/recommend`, `chapter/exit/recommend`, `chapter/recommend/last`, `book/quick/open`, `reader/init`, `chapter/download`.
Account/monetization (not rebuilt): `user/login|logout|email/register`, `pay/create/order`, `pay/sku/list`, `profile/user/info|balance`, `member/page`, `ad/unit|iaa`, `app/bootstrap|global|common/conf`.

**Memory:** [[shorts-goodshort-repro]] (this). Siblings: [[remakeface-swap-repro]] (signed cloud protocol + mock repro pattern), [[beautycam-repro]] / [[makeupplus-repro]] (Meitu native-reuse), [[tvremote-repro]] (Compose clean-room + protocol DB).
