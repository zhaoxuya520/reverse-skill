#Requires -Version 5.1
# reverse-skill PRIMARY router. EN + ZH keyword patterns; UTF-8 BOM source for Windows PowerShell 5.1.
param(
    [string] $Hint = '',
    [string] $OutDir = ''
)
$ErrorActionPreference = 'Stop'

# Lowercase for Latin tokens; CJK unchanged by ToLowerInvariant.
$t = if ($Hint) { $Hint.ToLowerInvariant() } else { '' }

$map = [ordered]@{
    'R0'  = 'reverse-engineering/SKILL.md'
    'R1'  = 'apk-reverse/SKILL.md'
    'R2'  = 'mobile-reverse/SKILL.md'
    'R3'  = 'js-reverse/SKILL.md'
    'R4'  = 'reverse-engineering/dsl-vm-reverse/SKILL.md'
    'R5'  = 'dotnet-reverse/SKILL.md'
    'R6'  = 'ida-reverse/SKILL.md'
    'R7'  = 'radare2/SKILL.md'
    'R8'  = 'firmware-pentest/SKILL.md'
    'R9'  = 'malware-analysis/SKILL.md'
    'R10' = 'attack-chain/SKILL.md'
    'R11' = 'pentest-tools/SKILL.md'
    'R12' = 'api-security/SKILL.md'
    'R13' = 'supply-chain-security/SKILL.md'
    'R14' = 'llm-security/SKILL.md'
    'R15' = 'binary-diff/SKILL.md'
    'R16' = 'patch-diff-exploit/SKILL.md'
    'R17' = 'pwn-chain/SKILL.md'
    'R18' = 'edr-bypass-re/SKILL.md'
    'R19' = 'browser-automation/SKILL.md'
    'R20' = 'docs-generator/SKILL.md'
    'R21' = 'protocol-reverse/SKILL.md'
    'R22' = 'ghidra-reverse/SKILL.md'
    'R23' = 'cloud-k8s/SKILL.md'
    'R24' = 'windows-ad/SKILL.md'
    'R25' = 'digital-forensics/SKILL.md'
    'R26' = 'code-audit/SKILL.md'
    'R27' = 'threat-hunting/SKILL.md'
    'R28' = 'ot-ics/SKILL.md'
    'R29' = 'wifi-wireless/SKILL.md'
    'R30' = 'browser-extension-reverse/SKILL.md'
    'R31' = 'macos-reverse/SKILL.md'
    'R32' = 'thick-client/SKILL.md'
    'R33' = 'go-rust-reverse/SKILL.md'
    'R34' = 'hardware-security/SKILL.md'
    'R35' = 'database-security/SKILL.md'
    'R36' = 'email-security/SKILL.md'
    'R37' = 'identity-federation/SKILL.md'
    'R38' = 'radio-sdr/SKILL.md'
}

$labels = [ordered]@{
    'R0'  = 'General reverse-engineering'
    'R1'  = 'APK reverse'
    'R2'  = 'Mobile reverse (Android+iOS)'
    'R3'  = 'JS / frontend reverse'
    'R4'  = 'DSL VM reverse'
    'R5'  = '.NET reverse'
    'R6'  = 'IDA reverse'
    'R7'  = 'radare2'
    'R8'  = 'Firmware pentest'
    'R9'  = 'Malware analysis'
    'R10' = 'Attack chain'
    'R11' = 'Pentest tools'
    'R12' = 'API security'
    'R13' = 'Supply chain'
    'R14' = 'LLM / Agent security'
    'R15' = 'Binary diff / symbol migrate'
    'R16' = 'Patch-diff / N-day'
    'R17' = 'Pwn chain'
    'R18' = 'EDR bypass RE'
    'R19' = 'Browser / desktop automation'
    'R20' = 'Docs generator'
    'R21' = 'Protocol reverse'
    'R22' = 'Ghidra reverse'
    'R23' = 'Cloud / K8s'
    'R24' = 'Windows / AD'
    'R25' = 'Digital forensics'
    'R26' = 'Code audit / SAST'
    'R27' = 'Threat hunting'
    'R28' = 'OT / ICS'
    'R29' = 'Wi-Fi / wireless'
    'R30' = 'Browser extension reverse'
    'R31' = 'macOS / Mach-O reverse'
    'R32' = 'Thick client security'
    'R33' = 'Go / Rust reverse'
    'R34' = 'Hardware / debug interfaces'
    'R35' = 'Database security'
    'R36' = 'Email / phishing analysis'
    'R37' = 'Identity federation (SAML/OIDC)'
    'R38' = 'RF / SDR research'
}

$sel = New-Object System.Collections.Generic.List[string]

if ($t -match '\bapk\b|smali|jadx|apktool|android.?reverse|安卓|反编译.?apk|apk.?加固|重打包') { [void]$sel.Add('R1') }
# iOS mobile: do NOT bare-match 越狱 when LLM/model context (R14)
if ($t -match '\bipa\b|ios.?reverse|objection|mobsf|mobile.?reverse|ios.?逆向') { [void]$sel.Add('R2') }
if ($t -match '越狱' -and $t -notmatch '模型|提示词|llm|prompt|jailbreak|garak|红队.?ai|ai.?红队') { [void]$sel.Add('R2') }
if ($t -match 'jailbreak' -and $t -match 'ios|iphone|ipad|mobile|objection|ipa') { [void]$sel.Add('R2') }
if ($t -match 'js.?reverse|webpack|cryptojs|frontend.?sign|jshook|cdp|encrypted.?param|前端.?签名|js.?逆向|加密.?参数|webpack.?逆向') { [void]$sel.Add('R3') }
if ($t -match 'dsl.?vm|fireye|opcode.?vm|custom.?vm|自定义.?虚拟机') { [void]$sel.Add('R4') }
if ($t -match '\.net|dnspy|de4dot|confuserex|csharp|dotnet|c#') { [void]$sel.Add('R5') }
if ($t -match '\bida\b|decompile|disassembl|反编译|反汇编|静态.?分析.?二进制') { [void]$sel.Add('R6') }
if ($t -match 'radare|\br2\b') { [void]$sel.Add('R7') }
if ($t -match 'firmware|binwalk|iot|emba|firmadyne|固件|路由器.?固件|嵌入式') { [void]$sel.Add('R8') }
# bare sigma -> R27; sandbox needs malware context
if ($t -match 'malware|yara|virus.?sample|pe-?sieve|cape.?sandbox|恶意.?软件|病毒.?样本|木马.?分析|恶意.?样本|样本.?分析') { [void]$sel.Add('R9') }
if ($t -match 'sandbox' -and $t -match 'malware|virus|恶意|木马|样本|cape|any\.run|triage') { [void]$sel.Add('R9') }
if ($t -match 'attack.?chain|red.?team|lateral|domain.?pentest|internal.?network|full.?pentest|完整.?渗透|从外网|打到域控|红队|横向.?移动|内网.?渗透') { [void]$sel.Add('R10') }
if ($t -match 'nmap|nuclei|sqlmap|ffuf|pentest|src.?hunt|bug.?bounty|waf.?bypass|渗透.?测试|端口.?扫描|漏洞.?扫描|目录.?爆破|sql.?注入|众测') { [void]$sel.Add('R11') }
if ($t -match 'graphql|bola|bfla|api.?secur|接口.?安全|越权|未授权.?访问|rest.?api.?secur') { [void]$sel.Add('R12') }
if ($t -match '\boauth\b' -and $t -notmatch 'oauth2|oidc|saml|sso|openid|联邦|单点') { [void]$sel.Add('R12') }
if ($t -match 'sbom|supply.?chain|trivy|gitleaks|syft|供应链|依赖.?扫描') { [void]$sel.Add('R13') }
if ($t -match 'llm|prompt.?inject|jailbreak|agent.?secur|garak|owasp.?llm|提示词.?注入|模型.?红队|模型.?越狱|llm.?越狱|提示词.?越狱|ai.?红队') { [void]$sel.Add('R14') }
if ($t -match 'bindiff|symbol.?migrat|pdb|符号.?迁移|版本.?对比') { [void]$sel.Add('R15') }
if ($t -match 'n-?day|patch.?diff|patch.?tuesday|补丁.?差分|补丁.?分析') { [void]$sel.Add('R16') }
if ($t -match '\bpwn\b|rop|ret2libc|heap.?overflow|stack.?overflow|pwntools|栈溢出|堆溢出') { [void]$sel.Add('R17') }
if ($t -match 'edr|av.?bypass|syscall|amsi|etw.?patch|hell.?s.?gate|免杀|反病毒') { [void]$sel.Add('R18') }
if ($t -match 'playwright|browser.?auto|desktop.?auto|openreverse|fill.?form|浏览器.?自动化|桌面.?自动化|自动.?填表') { [void]$sel.Add('R19') }
if ($t -match 'writeup|write.?report|generate.?report|\breport\b|写.?报告|出.?报告|渗透.?报告|逆向.?报告') { [void]$sel.Add('R20') }
if ($t -match 'protocol.?reverse|custom.?protocol|protobuf|grpc|pcap.?protocol|wireshark.?dissector|协议.?逆向|自定义.?协议|流量.?逆向') { [void]$sel.Add('R21') }
if ($t -match 'ghidra|ghidra.?mcp|analyzeheadless|无.?ida|开源.?反编译') { [void]$sel.Add('R22') }
if ($t -match 'kubernetes|\bk8s\b|container.?escape|docker.?escape|kube-?bench|cloud.?secur|imds|169\.254\.169\.254|容器.?逃逸|云.?安全|k8s.?渗透') { [void]$sel.Add('R23') }
if ($t -match 'active.?directory|\bad\b.?cs|bloodhound|kerberoast|as-?rep|certipy|ntlm.?relay|dc.?sync|kerberos.?攻击|ad.?证书') { [void]$sel.Add('R24') }
if ($t -match '域.?渗透|域控' -and $t -notmatch '完整.?渗透|从外网|打到域控|attack.?chain|full.?pentest') { [void]$sel.Add('R24') }
if ($t -match 'forensic|volatility|memory.?dump|plaso|timeline.?explorer|取证|内存.?转储|应急.?响应.?取证') { [void]$sel.Add('R25') }
if ($t -match 'code.?audit|sast|semgrep|codeql|source.?review|白盒|代码.?审计|静态.?应用.?安全') { [void]$sel.Add('R26') }
if ($t -match 'threat.?hunt|detection.?engineer|blue.?team|sigma.?rule|\bsigma\b|威胁.?狩猎|检测.?工程|蓝队.?狩猎|检测.?规则') { [void]$sel.Add('R27') }
# word-boundary ics so "forensics" does not match
if ($t -match '\bot\b|\bics\b|scada|plc\b|modbus|dnp3|s7comm|purdue|工控|工业.?控制|ot/?ics') { [void]$sel.Add('R28') }
if ($t -match 'wifi|wi-?fi|aircrack|airmon|wpa.?handshake|wireless.?pentest|无线.?渗透|wifi.?攻击') { [void]$sel.Add('R29') }
if ($t -match 'browser.?extension|chrome.?extension|\bcrx\b|\bxpi\b|mv3.?extension|浏览器.?扩展|chrome.?扩展') { [void]$sel.Add('R30') }
if ($t -match 'macos|mach-?o|codesign|objective-?c|swift.?reverse|xpc|mac.?逆向|苹果.?桌面') { [void]$sel.Add('R31') }
if ($t -match 'thick.?client|desktop.?client|electron.?app|winforms|wpf|厚客户端|桌面.?客户端') { [void]$sel.Add('R32') }
if ($t -match '\bgolang\b|\brustc\b|go.?binary|stripped.?go|gore.?sym|go.?malware|rust.?binary|go.?逆向|rust.?逆向') { [void]$sel.Add('R33') }
if ($t -match 'uart|jtag|swd|debug.?pad|flashrom|硬件.?调试|串口.?shell|芯片.?提取') { [void]$sel.Add('R34') }
if ($t -match 'database.?secur|\bmysql\b|\bpostgres|mongodb|redis.?secur|mssql|数据库.?安全|数据库.?渗透') { [void]$sel.Add('R35') }
if ($t -match 'phish|spf|dkim|dmarc|bec\b|email.?secur|钓鱼.?邮件|邮件.?安全') { [void]$sel.Add('R36') }
if ($t -match 'saml|oidc|openid.?connect|oauth2|sso\b|联邦.?身份|单点.?登录') { [void]$sel.Add('R37') }
if ($t -match '\bsdr\b|hackrf|rtl-?sdr|gnu.?radio|\burh\b|射频|软件.?无线电') { [void]$sel.Add('R38') }
if ($t -match 'ollvm|anti-?debug|unicorn|angr|gdb|deobfuscat|控制流平坦|反调试') { [void]$sel.Add('R0') }
if ($t -match 'frida' -and $t -notmatch '\bapk\b|smali|jadx|android|安卓') { [void]$sel.Add('R0') }
if ($t -match 'reverse|逆向' -and $t -notmatch 'apk|js.?reverse|ios|mobile|\.net|firmware|malware|安卓|固件|恶意|protocol|ghidra|extension|macos|mach|golang|rust|工控|厚客户端|取证|协议|扩展') { [void]$sel.Add('R0') }

$notes = New-Object System.Collections.Generic.List[string]

$uniq = New-Object System.Collections.Generic.List[string]
foreach ($d in $sel) { if (-not $uniq.Contains($d)) { [void]$uniq.Add($d) } }

# priority high -> low (all R0-R38 must appear)
$priority = @('R4','R1','R2','R3','R30','R31','R33','R5','R9','R21','R22','R6','R7','R8','R34','R28','R17','R16','R18','R24','R37','R23','R35','R25','R36','R29','R38','R32','R26','R27','R10','R11','R12','R13','R14','R15','R19','R20','R0')
$primary = $null
foreach ($p in $priority) {
    if ($uniq.Contains($p)) { $primary = $p; break }
}

$confidence = 'low'
if ($null -eq $primary) {
    $primary = 'R0'
    if ($t) { [void]$notes.Add('No strong keyword hit; open routing.md full matrix') }
    else { [void]$notes.Add('Empty hint; provide task text') }
} else {
    $confidence = if ($uniq.Count -eq 1) { 'high' } else { 'medium' }
}

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$skillsRoot = Split-Path -Parent $scriptDir
$packageRoot = Split-Path -Parent $skillsRoot

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    if ($packageRoot -and (Test-Path -LiteralPath $packageRoot)) {
        $OutDir = Join-Path $packageRoot ("work\master-route-{0}" -f $stamp)
    } else {
        $tmpBase = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
        $OutDir = Join-Path $tmpBase ("reverse-skill-route\master-route-{0}" -f $stamp)
    }
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$primaryPath = $map[$primary]
$skillAbs = Join-Path $skillsRoot ($primaryPath -replace '/', [IO.Path]::DirectorySeparatorChar)
if (-not (Test-Path -LiteralPath $skillAbs)) {
    Write-Host ("ERROR: PRIMARY skill missing: {0}" -f $skillAbs) -ForegroundColor Red
    exit 2
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# reverse-skill Master route (PRIMARY)')
[void]$sb.AppendLine(("- created: {0}" -f (Get-Date -Format 'o')))
[void]$sb.AppendLine(("- package: reverse-skill"))
[void]$sb.AppendLine(("- hint: {0}" -f $Hint))
[void]$sb.AppendLine(("- primary: {0}" -f $primary))
[void]$sb.AppendLine(("- primary_label: {0}" -f $labels[$primary]))
[void]$sb.AppendLine(("- primary_skill: skills/{0}" -f $primaryPath))
[void]$sb.AppendLine(("- confidence: {0}" -f $confidence))
$sec = New-Object System.Collections.Generic.List[string]
foreach ($d in $uniq) {
    if ($d -ne $primary) { [void]$sec.Add(("skills/{0}" -f $map[$d])) }
}
$secText = if ($sec.Count -gt 0) { ($sec -join ', ') } else { '(none)' }
[void]$sb.AppendLine(("- secondary: {0}" -f $secText))
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## MUST open next')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('1. skills/MASTER-ROUTING.md')
[void]$sb.AppendLine(("2. skills/{0}" -f $primaryPath))
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Notes')
if ($notes.Count -eq 0) { [void]$sb.AppendLine('- (none)') }
foreach ($n in $notes) { [void]$sb.AppendLine(("- {0}" -f $n)) }

# UTF-8 with BOM for route-scope (Windows notepad-friendly)
$utf8 = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText((Join-Path $OutDir 'route-scope.md'), $sb.ToString(), $utf8)

Write-Host ("PRIMARY -> skills/{0}" -f $primaryPath) -ForegroundColor Green
Write-Host ("Label: {0} | confidence: {1}" -f $labels[$primary], $confidence)
foreach ($n in $notes) { Write-Host ("NOTE: {0}" -f $n) -ForegroundColor Yellow }
Write-Host ("Wrote {0}\route-scope.md" -f $OutDir)
Write-Host 'ACTION: Open PRIMARY SKILL.md now and execute ACTION REQUIRED.' -ForegroundColor Yellow
