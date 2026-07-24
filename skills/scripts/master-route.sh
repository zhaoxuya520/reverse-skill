#!/usr/bin/env bash
# reverse-skill PRIMARY router (bash parity of master-route.ps1)
# Portable: bash 3.2+ (macOS), no associative arrays.
# Usage:
#   bash skills/scripts/master-route.sh --hint "analyze this APK"
#   bash skills/scripts/master-route.sh --hint "js reverse signature" --out-dir /tmp/route-out
set -eu

HINT=""
OUT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    -Hint|-hint|--hint) HINT="${2:-}"; shift 2 ;;
    -OutDir|-out-dir|--out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *)
      if [ -z "$HINT" ] && [ "${1#-}" = "$1" ]; then HINT="$1"; shift
      else echo "Unknown arg: $1" >&2; exit 2; fi
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_ROOT="$(cd "$SKILLS_ROOT/.." && pwd)"

# Lowercase Latin only; keep CJK.
t="$(printf '%s' "$HINT" | tr 'A-Z' 'a-z')"

map_path() {
  case "$1" in
    R0) echo "reverse-engineering/SKILL.md" ;;
    R1) echo "apk-reverse/SKILL.md" ;;
    R2) echo "mobile-reverse/SKILL.md" ;;
    R3) echo "js-reverse/SKILL.md" ;;
    R4) echo "reverse-engineering/dsl-vm-reverse/SKILL.md" ;;
    R5) echo "dotnet-reverse/SKILL.md" ;;
    R6) echo "ida-reverse/SKILL.md" ;;
    R7) echo "radare2/SKILL.md" ;;
    R8) echo "firmware-pentest/SKILL.md" ;;
    R9) echo "malware-analysis/SKILL.md" ;;
    R10) echo "attack-chain/SKILL.md" ;;
    R11) echo "pentest-tools/SKILL.md" ;;
    R12) echo "api-security/SKILL.md" ;;
    R13) echo "supply-chain-security/SKILL.md" ;;
    R14) echo "llm-security/SKILL.md" ;;
    R15) echo "binary-diff/SKILL.md" ;;
    R16) echo "patch-diff-exploit/SKILL.md" ;;
    R17) echo "pwn-chain/SKILL.md" ;;
    R18) echo "edr-bypass-re/SKILL.md" ;;
    R19) echo "browser-automation/SKILL.md" ;;
    R20) echo "docs-generator/SKILL.md" ;;
    R21) echo "protocol-reverse/SKILL.md" ;;
    R22) echo "ghidra-reverse/SKILL.md" ;;
    R23) echo "cloud-k8s/SKILL.md" ;;
    R24) echo "windows-ad/SKILL.md" ;;
    R25) echo "digital-forensics/SKILL.md" ;;
    R26) echo "code-audit/SKILL.md" ;;
    R27) echo "threat-hunting/SKILL.md" ;;
    R28) echo "ot-ics/SKILL.md" ;;
    R29) echo "wifi-wireless/SKILL.md" ;;
    R30) echo "browser-extension-reverse/SKILL.md" ;;
    R31) echo "macos-reverse/SKILL.md" ;;
    R32) echo "thick-client/SKILL.md" ;;
    R33) echo "go-rust-reverse/SKILL.md" ;;
    R34) echo "hardware-security/SKILL.md" ;;
    R35) echo "database-security/SKILL.md" ;;
    R36) echo "email-security/SKILL.md" ;;
    R37) echo "identity-federation/SKILL.md" ;;
    R38) echo "radio-sdr/SKILL.md" ;;
    *) echo "" ;;
  esac
}

map_label() {
  case "$1" in
    R0) echo "General reverse-engineering" ;;
    R1) echo "APK reverse" ;;
    R2) echo "Mobile reverse (Android+iOS)" ;;
    R3) echo "JS / frontend reverse" ;;
    R4) echo "DSL VM reverse" ;;
    R5) echo ".NET reverse" ;;
    R6) echo "IDA reverse" ;;
    R7) echo "radare2" ;;
    R8) echo "Firmware pentest" ;;
    R9) echo "Malware analysis" ;;
    R10) echo "Attack chain" ;;
    R11) echo "Pentest tools" ;;
    R12) echo "API security" ;;
    R13) echo "Supply chain" ;;
    R14) echo "LLM / Agent security" ;;
    R15) echo "Binary diff / symbol migrate" ;;
    R16) echo "Patch-diff / N-day" ;;
    R17) echo "Pwn chain" ;;
    R18) echo "EDR bypass RE" ;;
    R19) echo "Browser / desktop automation" ;;
    R20) echo "Docs generator" ;;
    R21) echo "Protocol reverse" ;;
    R22) echo "Ghidra reverse" ;;
    R23) echo "Cloud / K8s" ;;
    R24) echo "Windows / AD" ;;
    R25) echo "Digital forensics" ;;
    R26) echo "Code audit / SAST" ;;
    R27) echo "Threat hunting" ;;
    R28) echo "OT / ICS" ;;
    R29) echo "Wi-Fi / wireless" ;;
    R30) echo "Browser extension reverse" ;;
    R31) echo "macOS / Mach-O reverse" ;;
    R32) echo "Thick client security" ;;
    R33) echo "Go / Rust reverse" ;;
    R34) echo "Hardware / debug interfaces" ;;
    R35) echo "Database security" ;;
    R36) echo "Email / phishing analysis" ;;
    R37) echo "Identity federation (SAML/OIDC)" ;;
    R38) echo "RF / SDR research" ;;
    *) echo "Unknown" ;;
  esac
}

# Portable ERE match (no \\b — BSD grep on macOS).
re() {
  printf '%s' "$t" | grep -Eiq -- "$1"
}

SEL=""
add() {
  id="$1"
  case " $SEL " in
    *" $id "*) ;;
    *) SEL="$SEL $id" ;;
  esac
}

re 'apk|smali|jadx|apktool|android.?reverse|安卓|反编译.?apk|apk.?加固|重打包' && add R1
re 'ipa|ios.?reverse|objection|mobsf|mobile.?reverse|ios.?逆向' && add R2
if re '越狱' && ! re '模型|提示词|llm|prompt|jailbreak|garak|红队.?ai|ai.?红队'; then add R2; fi
if re 'jailbreak' && re 'ios|iphone|ipad|mobile|objection|ipa'; then add R2; fi
re 'js.?reverse|webpack|cryptojs|frontend.?sign|jshook|cdp|encrypted.?param|前端.?签名|js.?逆向|加密.?参数|webpack.?逆向' && add R3
re 'dsl.?vm|fireye|opcode.?vm|custom.?vm|自定义.?虚拟机' && add R4
re '\.net|dnspy|de4dot|confuserex|csharp|dotnet|c#' && add R5
re 'ida|decompile|disassembl|反编译|反汇编|静态.?分析.?二进制' && add R6
re 'radare|[^a-z]r2[^a-z]|^r2[^a-z]|[^a-z]r2$' && add R7
# also bare r2 token
re '(^|[^a-z0-9])r2([^a-z0-9]|$)' && add R7
re 'firmware|binwalk|iot|emba|firmadyne|固件|路由器.?固件|嵌入式' && add R8
re 'malware|yara|virus.?sample|pe-?sieve|cape.?sandbox|恶意.?软件|病毒.?样本|木马.?分析|恶意.?样本|样本.?分析' && add R9
if re 'sandbox' && re 'malware|virus|恶意|木马|样本|cape|any\.run|triage'; then add R9; fi
re 'attack.?chain|red.?team|lateral|domain.?pentest|internal.?network|full.?pentest|完整.?渗透|从外网|打到域控|红队|横向.?移动|内网.?渗透' && add R10
re 'nmap|nuclei|sqlmap|ffuf|pentest|src.?hunt|bug.?bounty|waf.?bypass|渗透.?测试|端口.?扫描|漏洞.?扫描|目录.?爆破|sql.?注入|众测' && add R11
re 'graphql|bola|bfla|api.?secur|接口.?安全|越权|未授权.?访问|rest.?api.?secur' && add R12
if re 'oauth' && ! re 'oauth2|oidc|saml|sso|openid|联邦|单点'; then add R12; fi
re 'sbom|supply.?chain|trivy|gitleaks|syft|供应链|依赖.?扫描' && add R13
re 'llm|prompt.?inject|jailbreak|agent.?secur|garak|owasp.?llm|提示词.?注入|模型.?红队|模型.?越狱|llm.?越狱|提示词.?越狱|ai.?红队' && add R14
re 'bindiff|symbol.?migrat|pdb|符号.?迁移|版本.?对比' && add R15
re 'n-?day|patch.?diff|patch.?tuesday|补丁.?差分|补丁.?分析' && add R16
re 'pwn|rop|ret2libc|heap.?overflow|stack.?overflow|pwntools|栈溢出|堆溢出' && add R17
re 'edr|av.?bypass|syscall|amsi|etw.?patch|hell.?s.?gate|免杀|反病毒' && add R18
re 'playwright|browser.?auto|desktop.?auto|openreverse|fill.?form|浏览器.?自动化|桌面.?自动化|自动.?填表' && add R19
re 'writeup|write.?report|generate.?report|report|写.?报告|出.?报告|渗透.?报告|逆向.?报告' && add R20
re 'protocol.?reverse|custom.?protocol|protobuf|grpc|pcap.?protocol|wireshark.?dissector|协议.?逆向|自定义.?协议|流量.?逆向' && add R21
re 'ghidra|ghidra.?mcp|analyzeheadless|无.?ida|开源.?反编译' && add R22
re 'kubernetes|k8s|container.?escape|docker.?escape|kube-?bench|cloud.?secur|imds|169\.254\.169\.254|容器.?逃逸|云.?安全|k8s.?渗透' && add R23
re 'active.?directory|bloodhound|kerberoast|as-?rep|certipy|ntlm.?relay|dc.?sync|kerberos.?攻击|ad.?证书' && add R24
if re '域.?渗透|域控' && ! re '完整.?渗透|从外网|打到域控|attack.?chain|full.?pentest'; then add R24; fi
re 'forensic|volatility|memory.?dump|plaso|timeline.?explorer|取证|内存.?转储|应急.?响应.?取证' && add R25
re 'code.?audit|sast|semgrep|codeql|source.?review|白盒|代码.?审计|静态.?应用.?安全' && add R26
re 'threat.?hunt|detection.?engineer|blue.?team|sigma.?rule|sigma|威胁.?狩猎|检测.?工程|蓝队.?狩猎|检测.?规则' && add R27
re '(^|[^a-z])ot([^a-z]|$)|(^|[^a-z])ics([^a-z]|$)|scada|plc|modbus|dnp3|s7comm|purdue|工控|工业.?控制|ot/?ics' && add R28
re 'wifi|wi-?fi|aircrack|airmon|wpa.?handshake|wireless.?pentest|无线.?渗透|wifi.?攻击' && add R29
re 'browser.?extension|chrome.?extension|crx|xpi|mv3.?extension|浏览器.?扩展|chrome.?扩展' && add R30
re 'macos|mach-?o|codesign|dyld|objective-?c|swift.?binary|苹果.?逆向|mac.?逆向' && add R31
re 'thick.?client|electron.?app|wpf|winforms|桌面.?客户端|厚客户端' && add R32
re 'golang|rustc|go.?binary|stripped.?go|gore.?sym|go.?malware|rust.?binary|go.?逆向|rust.?逆向' && add R33
re 'uart|jtag|swd|debug.?pad|flashrom|硬件.?调试|串口.?shell|芯片.?提取' && add R34
re 'database.?secur|mysql|postgres|mongodb|redis.?secur|mssql|数据库.?安全|数据库.?渗透' && add R35
re 'phish|spf|dkim|dmarc|bec|email.?secur|钓鱼.?邮件|邮件.?安全' && add R36
re 'saml|oidc|openid.?connect|oauth2|sso|联邦.?身份|单点.?登录' && add R37
re 'sdr|hackrf|rtl-?sdr|gnu.?radio|urh|射频|软件.?无线电' && add R38
re 'ollvm|anti-?debug|unicorn|angr|gdb|deobfuscat|控制流平坦|反调试' && add R0
if re 'frida' && ! re 'apk|smali|jadx|android|安卓'; then add R0; fi
if re 'reverse|逆向' && ! re 'apk|js.?reverse|ios|mobile|\.net|firmware|malware|安卓|固件|恶意|protocol|ghidra|extension|macos|mach|golang|rust|工控|厚客户端|取证|协议|扩展'; then add R0; fi

PRIORITY="R4 R1 R2 R3 R30 R31 R33 R5 R9 R21 R22 R6 R7 R8 R34 R28 R17 R16 R18 R24 R37 R23 R35 R25 R36 R29 R38 R32 R26 R27 R10 R11 R12 R13 R14 R15 R19 R20 R0"

NOTES=""
PRIMARY=""
for p in $PRIORITY; do
  case " $SEL " in
    *" $p "*) PRIMARY="$p"; break ;;
  esac
done

CONFIDENCE="low"
if [ -z "$PRIMARY" ]; then
  PRIMARY="R0"
  if [ -n "$t" ]; then NOTES="No strong keyword hit; open routing.md full matrix"
  else NOTES="Empty hint; provide task text"; fi
else
  # count selected
  nsel=0
  for _s in $SEL; do nsel=$((nsel+1)); done
  if [ "$nsel" -eq 1 ]; then CONFIDENCE="high"; else CONFIDENCE="medium"; fi
fi

if [ -z "$OUT_DIR" ]; then
  stamp="$(date +%Y%m%d-%H%M%S)"
  if [ -d "$PACKAGE_ROOT" ]; then
    OUT_DIR="$PACKAGE_ROOT/work/master-route-$stamp"
  else
    OUT_DIR="${TMPDIR:-/tmp}/reverse-skill-route/master-route-$stamp"
  fi
fi
mkdir -p "$OUT_DIR"

PRIMARY_PATH="$(map_path "$PRIMARY")"
SKILL_ABS="$SKILLS_ROOT/$PRIMARY_PATH"
if [ ! -f "$SKILL_ABS" ]; then
  echo "ERROR: PRIMARY skill missing: $SKILL_ABS" >&2
  exit 2
fi

SEC_TEXT=""
for d in $SEL; do
  if [ "$d" != "$PRIMARY" ]; then
    sp="skills/$(map_path "$d")"
    if [ -z "$SEC_TEXT" ]; then SEC_TEXT="$sp"; else SEC_TEXT="$SEC_TEXT, $sp"; fi
  fi
done
[ -n "$SEC_TEXT" ] || SEC_TEXT="(none)"

created="$(date +%Y-%m-%dT%H:%M:%S%z 2>/dev/null || date)"
{
  echo "# reverse-skill Master route (PRIMARY)"
  echo "- created: $created"
  echo "- package: reverse-skill"
  echo "- hint: $HINT"
  echo "- primary: $PRIMARY"
  echo "- primary_label: $(map_label "$PRIMARY")"
  echo "- primary_skill: skills/$PRIMARY_PATH"
  echo "- confidence: $CONFIDENCE"
  echo "- secondary: $SEC_TEXT"
  echo ""
  echo "## MUST open next"
  echo ""
  echo "1. skills/MASTER-ROUTING.md"
  echo "2. skills/$PRIMARY_PATH"
  echo ""
  echo "## Notes"
  if [ -z "$NOTES" ]; then echo "- (none)"; else
    oldIFS=$IFS; IFS='|'
    # single note string for now
    echo "- $NOTES"
    IFS=$oldIFS
  fi
} > "$OUT_DIR/route-scope.md"

echo "PRIMARY -> skills/$PRIMARY_PATH"
echo "Label: $(map_label "$PRIMARY") | confidence: $CONFIDENCE"
[ -n "$NOTES" ] && echo "NOTE: $NOTES"
echo "Wrote $OUT_DIR/route-scope.md"
echo "ACTION: Open PRIMARY SKILL.md now and execute ACTION REQUIRED."
