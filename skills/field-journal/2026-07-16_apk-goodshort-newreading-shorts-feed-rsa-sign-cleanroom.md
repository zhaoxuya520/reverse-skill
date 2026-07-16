# 2026-07-16 · APK reverse — GoodShort (Newreading) short-drama: Discovery + Shorts feed API + RSA-SHA256 request signing

**Scenario:** APK / Android reverse — user handed `short.xapk` and wanted the Discovery ("Khám phá") + Shorts ("Video ngắn") tab APIs extracted and a **complete Kotlin TikTok-style vertical-swipe player app** rebuilt from them (ViewPager2 vertical + Media3 ExoPlayer, MVVM, Paging).
**Target:** `short.xapk` (ApkPure) → `com.newreading.goodreels` — **GoodShort** v3.0.9.2109 (vc 3092109), min/target 23/35. Split XAPK: base **98 MB** + `config.arm64_v8a.apk`. **13 plain DEX, no packer** (`classes*.dex` decompiled straight). Heavy R8 (single/double-letter packages) **but the whole `com.newreading.goodreels.net` + `com.lib.http` layer kept real names**. Stack: Kotlin, **Retrofit2 + OkHttp3 + RxJava2 + Gson**, Firebase, AppLovin/Moloco/Tapjoy/ByteDance ads, Sobot. Short-drama app: **book = drama series, chapter = a video episode.**
**Outcome:** ✅ full Discovery + Shorts protocol reversed (base `https://api.goodreels.com/`, prefix `hwycclientreels/`, 119 POST endpoints enumerated) + **request-signing scheme recovered verbatim** (RSA-SHA256 over a fixed base string, hardcoded PKCS#8 key in-APK) + a **clean-room Kotlin/MVVM app** at `~/Projects/Android/ShortsApp` (ViewPager2-vertical + Media3 ExoPlayer pool w/ SimpleCache preload, Retrofit signing interceptors ported, Paging3 infinite feed, **USE_MOCK=true runs offline** with sample videos). Built via a 7-slice parallel construction workflow + adversarial per-slice verify. **Same-day follow-up:** the app was re-skinned end-to-end as "DramaStream" from an imported Claude Design mockup (5-tab nav + onboarding + local-simulated coin/VIP economy on top of the *same* reversed core, zero backend changes) — see the dedicated section below for the edge-to-edge/status-bar touch-dead-zone bug class it surfaced.

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

## DramaStream redesign (2026-07-16, same-day follow-up) — importing a Claude Design mockup onto the already-reversed core, not another reversing pass

A different kind of follow-up: the user published a **Claude Design** project (`claude.ai/design`, a
`.dc.html` export — JSON-wrapped self-contained HTML with an embedded JS state machine, used purely as a
UI/UX *spec* to translate into native Android, never executed directly) and asked to implement its full
~10-screen redesign ("Good Reels Redesign", rebranded on-screen as **"DramaStream"**) as the interface for
the already-built `ShortsApp`, explicitly **reusing the existing reversed API core** rather than inventing
a new backend. This is the reverse-engineering payoff pattern worth naming: once a protocol is faithfully
reproduced (real `Book`/`Chapter` fields, `charged`/`price`, real cover art), a completely different visual
layer can be dropped on top with zero backend changes — the redesign touched **zero** files under
`data/remote/RetrofitClient.kt` / `SignManager.kt` / `HeaderInterceptor.kt`.

**Scope boundary that mattered:** the design's monetization surface (coin wallet, VIP status, watch
progress, saved list, onboarding completion) has **no real backend counterpart** in the reversed protocol
(`profile/balance`, `pay/sku/list`, `sign/award/receive` exist server-side but were never in scope to
integrate) — implemented as **100% local-simulated `SharedPreferences` state**, explicitly **not** wired to
Google Play Billing, with a `RewardsRepository` KDoc and an on-screen paywall disclaimer ("100% simulated
for this build — no real payment is ever charged") both stating this in the app itself, not just the
commit message. The free-episode-count/coin-pricing shown in the UI was grounded in the **real**
`Chapter.charged`/`Chapter.price` fields already reversed, not invented numbers — the simulated economy
still respects the real content-gating shape.

Built the same way as the original 7-slice construction (locked `CONTRACT.md` + parallel `Workflow` +
adversarial per-slice review, 9 slices this time: onboarding/home/shorts/search/library/rewards/
profile-paywall/detail/player, 99 files). The adversarial pass caught 2 real bugs (stale search results
surviving a failed query, a missing synopsis binding) before device testing even started — cheap to catch
there. What it **couldn't** catch (each slice only reads its own files against the contract, never runs the
app) is the interesting part below.

### Bugs that only live device testing found — three are an edge-to-edge/status-bar class worth generalizing

1. **Mock data baked a display prefix in twice.** `MockApiService.buildChapter()` set
   `chapterName = "EP ${index+1} · $title"`, and the *redesigned* player screen's next-episode hint
   independently reconstructed `"EP $n · $name"` from that same field — assuming `chapterName` was a bare
   title. Mock mode is the only mode that ever exercised this path (real-mode `chapterName` format is
   unknown/unverified), so it was invisible in every prior mock-only review. Rendered on-device as
   `"EP 2 · EP 2 · The Big Escape"`. Fix: stop baking the prefix into the mock field — let the one place
   that already formats "EP N" own it. **Lesson: a synthetic test-data generator that happens to already
   contain the string a later formatting step will also produce is a silent duplication trap — it only
   surfaces once something downstream actually concatenates the two, and nothing in a code review (or even
   a screenshot of the *first* episode, where there's no "next" to compare against) will show it.**

2. **A `MaterialToolbar`'s fixed height turns "add inset padding" into "clip the icon."** Three edge-to-edge
   inset bugs surfaced by literally tapping every icon on-device: the VIP paywall's primary CTA sat half
   under the gesture-nav bar, the Home header's search/profile icons had their top ~60% inside the status
   bar's touch-exclusion zone (confirmed via `uiautomator dump` bounds vs. the `WindowManager` log's
   `mInsetsHint=Insets{top=97,...}` — a tap at `y=84` silently ate `Back`/`Search`/`Profile` clicks with
   *zero* logcat trace, they just never dispatched), and a `ProfileActivity` back arrow was unreachable
   the same way. The fix shape differs by container:
   - **`wrap_content` container** (the Home header `LinearLayout`) → add the inset as **top padding** via
     `ViewCompat.setOnApplyWindowInsetsListener` + `updatePadding` — the container grows to fit, nothing
     clips. Also grow the scrollable content's *reserved* top space by the same inset, or the taller
     header now overlaps the first row of content.
   - **Fixed-size view inside flexible layout** (a `MaterialButton`/`ImageButton` at the screen edge) →
     add the inset as **margin**, not padding — `updateLayoutParams<MarginLayoutParams>`, confirmed on the
     Subscribe screen's close button and continue CTA.
   - **`MaterialToolbar`** (`android:layout_height="?attr/actionBarSize"`, a *fixed* height) → padding is
     the wrong tool: padding the toolbar's own view eats into that fixed height and **clips the nav icon**
     (tried it, the back arrow rendered as a barely-visible sliver). The correct, already-proven pattern
     elsewhere in this same app (`DetailActivity`'s `AppBarLayout`) is to **wrap the toolbar in a
     `com.google.android.material.appbar.AppBarLayout` with `android:fitsSystemWindows="true"`** — the
     AppBarLayout absorbs the inset as its own top padding and the toolbar inside keeps its full,
     unclipped height. **Lesson: "add a window-insets listener" is not one fix, it's three, chosen by
     what kind of view is eating the inset — get the wrong one and you trade an invisible-touch-target bug
     for a visibly-clipped-icon bug, not a working screen.**
   - **Immersive full-bleed screens are a deliberate exception, not a bug to fix uniformly.**
     `PlayerActivity` calls `WindowInsetsControllerCompat.hide(WindowInsetsCompat.Type.systemBars())` for
     the video experience, so its back button correctly has *no* persistent status-bar collision to fix —
     checking for this before "fixing" every top-anchored control saved a wasted change.

**How the touch-dead-zone bug was actually diagnosed, since it produces zero error signal:** repeated taps
at a coordinate that visually looked correct (matched the screenshot, matched `uiautomator dump` element
bounds) kept landing on the wrong screen with no crash, no logcat line, nothing. Cross-checking against
`adb shell dumpsys activity activities | grep topResumedActivity` before/after each tap (not just
screenshots, which can't distinguish "click landed on the wrong invisible layer" from "click didn't
register at all") confirmed the Activity truly never changed. The breakthrough was correlating the dead
y-range against the `WindowManager` log line captured earlier in the same logcat session
(`mInsetsHint=Insets{top=97,...}`) — the status bar is a **separate system window layered on top**, and it
silently swallows taps in its zone before they ever reach the app, regardless of what the app draws there.
**Any element positioned within the first ~100px of an edge-to-edge Android screen needs to be verified
tappable on a real device, not just visually inspected in a screenshot — a screenshot shows what's drawn,
not what's reachable.**

## Appendix — endpoint quick-reference (subset; 119 total under `hwycclientreels/`)
Discovery: `home/index`, `home/nav/list`, `home/rankList`, `book/recommend`, `book/forUFilterTab`, `book/foru/introduction`, `book/suggest`, `book/search1`, `book/search/hot/words`.
Shorts/player: `chapter/load`, `chapter/node/load`, `chapter/list`, `chapter/end/recommend`, `chapter/exit/recommend`, `chapter/recommend/last`, `book/quick/open`, `reader/init`, `chapter/download`.
Account/monetization (not rebuilt): `user/login|logout|email/register`, `pay/create/order`, `pay/sku/list`, `profile/user/info|balance`, `member/page`, `ad/unit|iaa`, `app/bootstrap|global|common/conf`.

**Memory:** [[shorts-goodshort-repro]] (this). Siblings: [[remakeface-swap-repro]] (signed cloud protocol + mock repro pattern), [[beautycam-repro]] / [[makeupplus-repro]] (Meitu native-reuse), [[tvremote-repro]] (Compose clean-room + protocol DB).
