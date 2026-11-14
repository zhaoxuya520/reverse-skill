# All-in-one reverse-skill execution image (issue #129)
# Base: official Kali rolling — many analysis CLIs come preinstalled.
# The package itself is bind-mounted at runtime; this image supplies tooling + runtimes.

FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/usr/local/bin

# Core runtimes + analysis CLIs available via Kali/apt.
# Keep packages explicit; commercial/cracked tools are NOT installed here.
# Manifest-aligned CLIs: apktool/adb/r2/seclists/nmap/sqlmap/hashcat/hydra/gobuster/ffuf/binwalk.
# GitHub-only or licensed capabilities (jadx, ida-pro, jeb, binaryninja) stay for bootstrap/manual.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        unzip \
        tar \
        wget \
        python3 \
        python3-pip \
        python3-venv \
        pipx \
        openjdk-17-jdk-headless \
        nodejs \
        npm \
        file \
        xxd \
        binwalk \
        apktool \
        adb \
        radare2 \
        seclists \
        nmap \
        sqlmap \
        hashcat \
        hydra \
        gobuster \
        ffuf \
    && rm -rf /var/lib/apt/lists/* \
    && pipx install frida-tools==14.10.4 \
    && pipx ensurepath

# Non-root analyst user; cases live under /home/analyst/work
RUN useradd --create-home --shell /bin/bash analyst \
    && mkdir -p /opt/reverse-skill /home/analyst/work \
    && chown -R analyst:analyst /opt/reverse-skill /home/analyst/work

# Bake a package snapshot for offline layout checks; runtime compose bind-mounts override this.
COPY --chown=analyst:analyst . /opt/reverse-skill

# Optional: refresh tool index at build (network + time). Default off.
ARG BOOTSTRAP=false
RUN if [ "$BOOTSTRAP" = "true" ]; then \
        bash /opt/reverse-skill/kali/scripts/refresh-tool-index.sh || true; \
    fi

COPY docker/entrypoint.sh /usr/local/bin/reverse-skill-entrypoint.sh
RUN chmod +x /usr/local/bin/reverse-skill-entrypoint.sh

USER analyst
WORKDIR /opt/reverse-skill
VOLUME ["/home/analyst/work"]

ENTRYPOINT ["/usr/local/bin/reverse-skill-entrypoint.sh"]
CMD ["bash"]
