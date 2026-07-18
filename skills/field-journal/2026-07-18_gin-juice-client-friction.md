# 现代 Web 靶场摩擦 → skill 加固

> 日期：2026-07-18  
> 场景：合法公开靶场（PortSwigger 类 scanner-eval / OWASP Juice Shop demo）  
> 脱敏：无真实业务域名利用细节

## 结论（给下次 Agent）

**未打穿 ≠ 包无效。** 必须交付：surface map、sink 列表、门闩原因、Evidence(observed|validated)。  
失败要写进 timeline，并反哺 playbook。

## 踩坑

| 坑 | 现象 | 修复/纪律 |
|----|------|-----------|
| case-init 授权被污染 | `-AuthGranted` 后 status 变成奇怪字符串 | 仅允许 pending/granted/denied/unknown；`PSBoundParameters` 判断 AuthStatus |
| lab_only 不 ready | network=lab_only 时 ready_for_act 假 | lab_only + granted + assets → ready |
| Windows curl `[]` | `bad range in position` | **必须** `curl.exe --globoff` |
| append-evidence 特殊字符 | RawExcerpt 含引号/XML 报错 | block 缩进 + 去控制字符 |
| 公网 demo 503 | Juice Shop Heroku 挂 | 换本地 Docker 或其它合法靶；勿死磕 |
| DOM XSS 假阳性 | 有 innerHTML sink 就报 validated | 需 200 非数字 body 才可 exploit；否则 observed |
| agent-browser ref 过期 | click 失败 | 页面变化后重新 snapshot |

## 可复用模式

1. Surface → Sink → Chain（见 `pentest-tools/references/client-side-lab-playbook.md`）  
2. 库存类 `innerHTML = fetchBody`：先证 sink，再找 200 非数字  
3. 静态 rg sink + agent-browser eval 双证  

## 工具链

- case-init / case-guard / append-evidence / smoke  
- agent-browser（CDP）  
- curl --globoff  

## 环境

- Windows + PowerShell 5.1  
- Docker Desktop 可能 daemon 未就绪  
