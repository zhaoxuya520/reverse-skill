# 安装与下载安全指引

## 优先使用 uv 管理 Python 环境

独立的命令行工具可以使用 `uv tool install <package>` 安装。项目依赖则先建立虚拟环境：

    uv venv
    uv pip install -r requirements.txt

不要机械式替换所有 `pip` 指令。`uv pip` 适合已建立的虚拟环境，独立 CLI 工具通常更适合 `uv tool install`。仓库内 bootstrap 仍以 `skills/scripts/bootstrap-manifest.json` 为准，当前隔离通道默认是 `pipx`；把安装路径改成 uv 需要维护者单独决定范围（见 Issue #51）。为了可复现，请尽量固定依赖版本或提交 lock file。

## 安全处理下载的压缩包

逆向工程与安全测试工具可能包含二进制、调试器、封装文件或安全测试数据，因此容易触发杀毒软件的启发式检测。杀毒警告不代表已证明安全，也不代表已证明恶意。

请勿停用杀毒软件或盲目略过警告。打开压缩包前，请确认文件来自预期的 HTTPS 仓库或 release 页面；若有 checksum 或 release digest，请先比对；接着检查压缩包内容并用最新的安全软件扫描。不要因为文件能成功下载，就直接执行其中未知的二进制、脚本或安装程序。
