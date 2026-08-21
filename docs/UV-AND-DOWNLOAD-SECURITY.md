# Installation and Download Security Guidance

## Prefer uv for Python environments

Use `uv tool install <package>` for isolated command-line tools. For project dependencies, create a virtual environment first:

    uv venv
    uv pip install -r requirements.txt

Do not mechanically replace every `pip` command. `uv pip` is intended for an existing virtual environment, while `uv tool install` is generally more suitable for standalone CLI tools. Prefer pinned dependency versions or a lock file for reproducible environments.

## Safe handling of downloaded archives

Reverse-engineering and security tools may trigger antivirus heuristics because they contain binaries, debuggers, packed files, or security-test data. A warning is not proof that an archive is safe or malicious.

Do not disable antivirus protection or blindly bypass a warning. Before opening an archive, verify that it came from the intended HTTPS repository or release page, compare its checksum or release digest when one is published, inspect its contents, and scan it with an up-to-date security product. Do not execute unknown binaries, scripts, or installers merely because an archive downloaded successfully.
