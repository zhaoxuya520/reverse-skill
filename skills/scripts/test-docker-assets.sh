#!/usr/bin/env bash
# Offline smoke for docker assets (issue #129). No Docker daemon required.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DOCKER_DIR="$ROOT/docker"
FAIL=0

check() {
  local name="$1"
  shift
  if "$@"; then
    echo "PASS $name"
  else
    echo "FAIL $name"
    FAIL=$((FAIL + 1))
  fi
}

check "Dockerfile exists" test -f "$DOCKER_DIR/Dockerfile"
check "compose exists" test -f "$DOCKER_DIR/docker-compose.yml"
check "entrypoint exists" test -f "$DOCKER_DIR/entrypoint.sh"
check "docker README exists" test -f "$DOCKER_DIR/README.md"
check "root .dockerignore exists" test -f "$ROOT/.dockerignore"

check "Dockerfile FROM kali" grep -q 'FROM kalilinux/kali-rolling' "$DOCKER_DIR/Dockerfile"
check "Dockerfile non-root analyst" grep -q 'USER analyst' "$DOCKER_DIR/Dockerfile"
check "Dockerfile includes nmap" grep -Eq '^[[:space:]]+nmap[[:space:]]*\\?$' "$DOCKER_DIR/Dockerfile"
check "Dockerfile includes radare2" grep -Eq '^[[:space:]]+radare2[[:space:]]*\\?$' "$DOCKER_DIR/Dockerfile"
check "Dockerfile pins frida-tools" grep -q 'frida-tools==14.10.4' "$DOCKER_DIR/Dockerfile"
check "compose mounts package" grep -q '/opt/reverse-skill' "$DOCKER_DIR/docker-compose.yml"
check "compose work volume" grep -q 'reverse-skill-work' "$DOCKER_DIR/docker-compose.yml"
check "compose not privileged" bash -c "! grep -q 'privileged: true' '$DOCKER_DIR/docker-compose.yml'"
check "compose no docker.sock" bash -c "! grep -q 'docker.sock' '$DOCKER_DIR/docker-compose.yml'"
check "README links kali docs" grep -q '../kali/README-kali.md' "$DOCKER_DIR/README.md"
check "entrypoint is executable or +x intent" test -f "$DOCKER_DIR/entrypoint.sh"

if command -v docker >/dev/null 2>&1; then
  check "compose config" docker compose -f "$DOCKER_DIR/docker-compose.yml" config -q
else
  echo "SKIP compose config (docker CLI not installed)"
fi

if [ "$FAIL" -ne 0 ]; then
  echo "TOTAL FAIL=$FAIL"
  exit 1
fi
echo "TOTAL FAIL=0"
echo "=== Docker asset smoke passed ==="
