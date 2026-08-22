> **reverse-skill adapter** - AGS `graphics-api-hooking` is installed as a first-class reference under PRIMARY `game-security/` (routing **R43**). This is not a second PRIMARY and not `npx skills add`.
>
> **Auth:** `case-init` + `auth.status=granted` before ACT on a target. Technique catalog / threat-model / authorized-lab RE stay in scope.
> **Deliverable bound:** do not ship a live-title trainer / cheat product. Dump, observe-hook, copy-patch, AC RE, DMA/overlay/kernel catalogs remain required capabilities.
> **Handoff:** technique catalog pairs with ``game-hacking.md``. Present/overlay as threat-model or authorized-lab capture. Native RE -> ``ida-reverse/``.
> **Fetch links / wiki / archive:** [fetch-upstream.md](fetch-upstream.md). Upstream wiki overview: `wiki/overviews/graphics-api.md`.
> **Distill:** duplicated Data Source footer removed (one home in fetch-upstream.md). Taxonomy, workflows, and technique catalogs are kept.
>
> Source: [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) (MIT, Copyright 2022 gmh).
---
name: graphics-api-hooking
description: Guide for graphics API interception, overlay rendering, and render-pipeline analysis across DirectX, OpenGL, and Vulkan. Use this skill when working with Present or SwapBuffers hooks, DXGI swap chains, shader or draw-call interception, screenshot-sensitive overlays, or graphics debugging in game security research.
---

# Graphics API Hooking & Rendering

## Overview

This skill covers graphics API resources from the awesome-game-security collection, including DirectX, OpenGL, and Vulkan hooking techniques, overlay rendering, and graphics debugging.

Capture paths, hook points, synchronization, latency, and observable artifacts
vary by API, driver, compositor, application, and tool version. Verify the
active path and use [`research-rigor`](research-rigor.md) before
attributing a capture or overlay signal.

## README Coverage

- `DirectX > Guide`
- `DirectX > Hook`
- `DirectX > Tools`
- `DirectX > Emulation`
- `DirectX > Compatibility`
- `DirectX > Overlay`
- `OpenGL > Guide`
- `OpenGL > Source`
- `OpenGL > Hook`
- `Vulkan > Guide`
- `Vulkan > API`
- `Vulkan > Hook`
- `Cheat > Overlay`
- `Cheat > Render/Draw`
- `Cheat > Anti Screenshot`
- `Anti Cheat > Screenshot`
- `Anti Cheat > Detection:Overlay`

## DirectX

### DirectX 9
```cpp
// Key functions to hook
IDirect3DDevice9::EndScene
IDirect3DDevice9::Reset
IDirect3DDevice9::Present
```

### DirectX 11
```cpp
// Key functions to hook
IDXGISwapChain::Present
ID3D11DeviceContext::DrawIndexed
ID3D11DeviceContext::Draw
```

### DirectX 12
```cpp
// Key functions to hook
IDXGISwapChain::Present
ID3D12CommandQueue::ExecuteCommandLists
```

### VTable Hooking
```cpp
// DX11 Example
typedef HRESULT(__stdcall* Present)(IDXGISwapChain*, UINT, UINT);
Present oPresent;

HRESULT __stdcall hkPresent(IDXGISwapChain* swapChain, UINT syncInterval, UINT flags) {
    // Render overlay here
    return oPresent(swapChain, syncInterval, flags);
}

// Hook via vtable
void* swapChainVtable = *(void**)swapChain;
oPresent = (Present)swapChainVtable[8];  // Present is index 8
```

## OpenGL

### Key Functions
```cpp
wglSwapBuffers
glDrawElements
glDrawArrays
glBegin/glEnd (legacy)
```

### Hook Example
```cpp
typedef BOOL(WINAPI* wglSwapBuffers_t)(HDC);
wglSwapBuffers_t owglSwapBuffers;

BOOL WINAPI hkwglSwapBuffers(HDC hdc) {
    // Render overlay
    return owglSwapBuffers(hdc);
}
```

## Vulkan

### Key Functions
```cpp
vkQueuePresentKHR
vkCreateSwapchainKHR
vkCmdDraw
vkCmdDrawIndexed
```

### Instance/Device Layers
- Use validation layers for debugging
- Custom layers for interception
- Layer manifest configuration

## Universal Hook Libraries

### Kiero
- Cross-API hook library
- Supports DX9/10/11/12, OpenGL, Vulkan
- Automatic method detection

### Universal ImGui Hook
- Pre-built ImGui integration
- Multiple API support
- Easy deployment

## ImGui Integration

### Setup (DX11)
```cpp
// In Present hook
ImGui_ImplDX11_Init(device, context);
ImGui_ImplWin32_Init(hwnd);

// Render
ImGui_ImplDX11_NewFrame();
ImGui_ImplWin32_NewFrame();
ImGui::NewFrame();

// Your rendering code
ImGui::Begin("Overlay");
// ...
ImGui::End();

ImGui::Render();
ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
```

### Window Procedure Hook
```cpp
// Required for ImGui input
LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (ImGui_ImplWin32_WndProcHandler(hWnd, msg, wParam, lParam))
        return true;
    return CallWindowProc(oWndProc, hWnd, msg, wParam, lParam);
}
```

## Overlay Techniques

### External Overlay
```
1. Create transparent window
2. Set WS_EX_LAYERED | WS_EX_TRANSPARENT
3. Use SetLayeredWindowAttributes
4. Render with GDI+/D2D
5. Position over game window
```

### DWM Overlay
```
- Hook Desktop Window Manager
- Render in DWM composition
- Higher privilege requirements
- Better anti-detection
```

### Steam Overlay Hijack
```
- Hook Steam's overlay functions
- Use existing overlay infrastructure
- Requires Steam running
```

### NVIDIA Overlay Hijack
```
- Hook GeForce Experience overlay
- Native-looking overlay
- May require specific drivers
```

## Shader Manipulation

### Wallhack Implementation
```hlsl
// Disable depth testing
OMSetDepthStencilState(depthDisabledState, 0);

// Or in pixel shader
float4 PSMain(VS_OUTPUT input) : SV_Target {
    // Always pass depth test
    return float4(1, 0, 0, 0.5);  // Red transparent
}
```

### Chams (Character Highlighting)
```hlsl
// Replace model shader
float4 PSChams(VS_OUTPUT input) : SV_Target {
    if (isEnemy) {
        return float4(1, 0, 0, 1);  // Red
    }
    return float4(0, 1, 0, 1);      // Green
}
```

## Rendering Concepts

### World-to-Screen
```cpp
D3DXVECTOR3 WorldToScreen(D3DXVECTOR3 pos, D3DXMATRIX viewProjection) {
    D3DXVECTOR4 clipCoords;
    D3DXVec3Transform(&clipCoords, &pos, &viewProjection);
    
    if (clipCoords.w < 0.1f) return invalid;
    
    D3DXVECTOR3 NDC;
    NDC.x = clipCoords.x / clipCoords.w;
    NDC.y = clipCoords.y / clipCoords.w;
    
    D3DXVECTOR3 screen;
    screen.x = (viewport.Width / 2) * (NDC.x + 1);
    screen.y = (viewport.Height / 2) * (1 - NDC.y);
    
    return screen;
}
```

### View Matrix Extraction
```
- From device constants
- Pattern scanning
- Engine-specific locations
- Reverse engineered addresses
```

## Debugging Tools

### PIX for Windows
- Frame capture and analysis
- GPU profiling
- Shader debugging

### RenderDoc
- Open-source frame debugger
- Multi-API support
- Resource inspection

### NVIDIA Nsight
- Performance analysis
- Shader debugging
- Frame profiling

## Anti-Screenshot Techniques

### How Anti-Cheat Captures Screenshots
```
- BitBlt from game window DC: captures visible content including overlays
- DXGI Desktop Duplication API: captures composited desktop output
- IDXGISwapChain::Present interception: grab backbuffer before present
- PrintWindow: capture specific window contents
- DirectX/Vulkan frame readback: copy render target to CPU-readable buffer
- Scheduled captures: random intervals to catch intermittent overlays
```

### Overlay Evasion Against Screenshot
```
- Disable overlay rendering during screenshot frame:
  - Detect screenshot by hooking BitBlt/PrintWindow in AC module
  - Suppress ImGui rendering for captured frame
- DWM composition tricks:
  - Render to a separate window that DWM excludes from capture
  - Use WDA_EXCLUDEFROMCAPTURE (SetWindowDisplayAffinity) on overlay window
- Hardware overlay planes:
  - Use IDXGIOutput::FindClosestMatchingMode + hardware overlay
  - Content on hardware overlay plane may not appear in software capture
- External rendering:
  - Render on secondary display or capture card output
  - OBS virtual camera trick: render to virtual camera feed
```

### Cheat-Side Anti-Screenshot (README > Anti Screenshot)
```
- Projects that detect and evade AC screenshot capture
- Techniques: hook Present to suppress overlay on screenshot frames
- DWM-based overlays that survive PrintWindow but not BitBlt
- Kernel-level: suppress screenshot by blocking DC access
```

## OBS Capture Pipeline and AI Visual Cheat Surface

### OBS Frame Capture Modes
```
OBS is one possible frame source for AI visual systems. Capture implementation
varies by OBS, Windows, graphics API, and source settings, so identify the
active path before inferring artifacts:

Game Capture:
- On supported Windows paths, commonly injects an OBS graphics-capture hook into
  the game and intercepts API-specific presentation/capture points
- Commonly transfers frames through shared graphics resources rather than
  requiring a full CPU readback for every frame
- Often offers low-latency pre-composition capture, but performance and quality
  depend on API, synchronization, settings, and version
- The hook module and resource-sharing behavior may be observable, but they are
  also legitimate OBS activity and are not attribution by themselves

Window Capture:
- May use Windows Graphics Capture, BitBlt, or another version/settings-specific
  backend without injecting a game-capture hook
- Captures a window/composited path; occlusion, cursor, HDR, and latency behavior
  depend on the selected backend
- Attribute the actual API and owning process rather than assuming Desktop
  Duplication

Display Capture:
- Captures a monitor/output through a platform-specific backend such as Desktop
  Duplication or Windows Graphics Capture
- Composition coverage and latency vary; protected content and hardware overlays
  can create exceptions
- No per-process interaction

OBS Virtual Camera:
- Outputs captured frames as a virtual camera device
- Can feed AI model running in separate process or machine
- May be discoverable through virtual-camera device registration and media
  pipeline activity, depending on platform and OBS version
```

### Frame Pipeline for AI Aimbot
```
Capture path (latency-critical):
  Game render → Present hook copies backbuffer
  → Shared GPU texture (ID3D11Texture2D, GPU-side)
  → GPU→CPU readback (staging texture + Map/Unmap)
  → CPU-side frame buffer (system memory)
  → Crop to ROI (Region of Interest, e.g., 640x640 around crosshair)
  → AI inference input (CUDA/TensorRT/DirectML)

OBS plugin form factor:
  AI model implemented as OBS video filter plugin
  → Receives frames through obs_source_frame callback
  → Runs inference in-process
  → Outputs mouse commands to hardware device
  → Appears as "OBS running a filter" to the system

Dual-machine pipeline:
  Game PC OBS → NDI (Network Device Interface) or capture card
  → Cheat PC receives video stream
  → AI inference on cheat PC GPU
  → Mouse commands sent via network to KMBox on game PC
  Added latency depends on capture hardware, buffering, transport, encoding,
  network, synchronization, and receiver configuration

Performance measurement:
  Measure capture, synchronization, transfer/readback, preprocessing, inference,
  postprocessing, transport, and input stages separately on the deployed setup.
  Report percentile end-to-end latency and dropped/stale frames; fixed latency
  budgets do not transfer across hardware and configurations.
```

### Detection-Relevant Graphics Signals
```
- obs-graphics-hook64.dll in game process module list
- IDXGISwapChain::Present hook or detour in game process
- Repeated readback/copy behavior involving staging resources, shared textures,
  or API-specific capture objects; efficient pipelines may reuse resources
- GPU-to-CPU memory copy bandwidth anomaly (Map/Unmap calls
  or equivalent synchronization/readback patterns)
- DXGI shared handle creation from game process to external process
- NDI SDK DLLs loaded (Processing.NDI.Lib.*.dll)
- Virtual camera driver (obs-virtualcam) registered

These are collection signals, not proof of a visual cheat. Correlate them with
plugin provenance, process behavior, trusted gameplay telemetry, and the
legitimate streaming/accessibility context.
```

## Anti-Detection Considerations

### Present Hook Detection
```
- VTable integrity checks
- Code section verification
- Call stack analysis
- Module list scanning for known capture DLLs
```

### Evasion Techniques
```
- Trampoline hooks
- Hardware breakpoints
- Timing obfuscation
```

## Performance Optimization

### Best Practices
```
1. Minimize state changes
2. Batch draw calls
3. Use instancing
4. Cache resources
5. Profile regularly
```

### Common Issues
```
- Flickering: Double buffer sync
- Artifacts: Clear state properly
- Performance: Reduce overdraw
```

## Resource Organization

The README contains:
- DirectX 9/11/12 hook implementations
- OpenGL hook libraries
- Vulkan interception tools
- ImGui integration examples
- Overlay frameworks
- Shader modification tools

---
