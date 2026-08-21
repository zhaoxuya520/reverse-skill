# reverse-skill 快速開始與社群問題說明

## 專案定位

`reverse-skill` 是 AI 客戶端可讀取的逆向工程、安全研究技能、規則與工具文件集合 ，不是一個單一的可執行應用程式。使用前，請先確認你對分析目標擁有明確授權，或正在使用合法的 CTF、教學或測試環境。

## 基本使用方式

先下載專案：

    git clone https://github.com/zhaoxuya520/reverse-skill.git
    cd reverse-skill

接著將專案目錄交給你使用的 AI 客戶端作為工作區或文件來源 。核心文件包括：

- `RULES.md`：一般規則與安全邊界。
- `skills/MASTER-ROUTING.md`：技能路由與任務分流。
- `skills/*/SKILL.md`：各專業領域的技能說明。
- `docs/platforms/`：不同作業系統的工具安裝說明。

本專案保持客戶端中立，因此 OpenCode、Codex、Cursor、Claude Code 與其他客戶端的實際載入方式，仍以各客戶端官方文件為準；不要假設某一個客戶端的 plugin 或同步格式能套用到其他客戶端。

## OpenCode、Codex 與同步問題

若客戶端顯示 `Not Synchronizable` 或無法同步，先確認工作區是否指向完整的 repository 根目錄、檔案權限是否允許讀取，以及客戶端是否支援該目錄格式。最可靠的替代方式是直接在本地工作區開啟 repository，並在對話中明確引用所需的規則或技能文件。若問題仍可重現，回報時請附上客戶端版本、作業系統、完整錯誤訊息與最小重現步驟。

## AI 拒絕處理分析請求

AI 的安全策略不會因為提示中加入「我已授權」就必然允許所有操作。請只處理合法授權的目標，避免要求未授權入侵、憑證竊取、持久化或破壞性操作；可將請求限定為程式碼理解、樣本分析、漏洞修補、CTF 或防禦性驗證。對於特定 APK、網站或帳戶，請先準備可驗證的授權範圍與測試環境。

## Python 工具與 uv

獨立命令列工具可使用：

    uv tool install PACKAGE_NAME

專案依賴則使用隔離環境：

    uv venv
    uv pip install -r requirements.txt

不要機械式把所有 `pip` 字串替換為 `uv pip`；`python -m pip`、`pipx` bootstrap 與已存在的虛擬環境各有不同用途。若尚未安裝 `uv`，請使用作業系統套件管理器或明確建立的虛擬環境，不要把安全工具直接安裝到系統全域 Python。

## ZIP 報毒與下載安全

逆向工程工具可能包含二進位檔、除錯器、封裝檔或測試資料，容易觸發防毒軟體的啟發式偵測。防毒警告不代表已證明安全，也不代表已證明惡意。請勿停用防毒軟體或盲目略過警告。

開啟壓縮檔前，請從預期的 HTTPS repository 或 release 頁面下載，核對 checksum 或 release digest（若有提供），檢查壓縮檔內容，並使用最新的安全軟體掃描。不要因為檔案成功下載，就直接執行其中未知的二進位檔、腳本或安裝程式。

## 帳戶、貢獻與未具體化回報

請遵守 AI 客戶端、GitHub、工具供應商及目標環境的服務條款。repository 本身無法保證第三方平台不會限制帳戶，也不能替平台決定帳戶政策。若要貢獻 radare2 或其他技能，請先閱讀 `skills/CONTRIBUTING.md`，並以小型、可驗證的 Pull Request 提交。

只有包含完整錯誤訊息、環境資訊與重現步驟的問題，才適合進一步修復。像是只有「病毒」、「gaha」或「test」的回報，請補充檔名、下載 URL、掃描產品、版本與重現方式。
