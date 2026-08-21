# 安裝與下載安全指引

## 優先使用 uv 管理 Python 環境

獨立的命令列工具可使用 `uv tool install <package>` 安裝 。專案依賴則先建立虛擬環境：

    uv venv
    uv pip install -r requirements.txt

不要機械式替換所有 `pip` 指令。`uv pip` 適合已建立的虛擬環境，而獨立 CLI 工具通常更適合使用 `uv tool install`。為了提升可重現性，請儘量固定依賴版本或提交 lock file。

## 安全處理下載的壓縮檔

逆向工程與安全測試工具可能包含二進位檔、除錯器、封裝檔或安全測試資料，因此容易觸發防毒軟體的啟發式偵測。防毒警告不代表已證明安全，也不代表已證明惡意。

請勿停用防毒軟體或盲目略過警告。開啟壓縮檔前，請確認檔案來自預期的 HTTPS repository 或 release 頁面；若有 checksum 或 release digest，請先比對；接著檢查壓縮檔內容並使用最新的安全軟體掃描。不要因為檔案能成功下載，就直接執行其中未知的二進位檔、腳本或安裝程式。
