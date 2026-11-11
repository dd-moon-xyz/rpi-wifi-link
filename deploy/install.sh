#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this installer as root." >&2
    exit 1
fi

. /etc/os-release
if [ "${VERSION_CODENAME:-}" != trixie ] || [ "$(dpkg --print-architecture)" != arm64 ]; then
    echo "This installer requires 64-bit Trixie." >&2
    exit 1
fi

for service in docker bluetooth NetworkManager; do
    if ! systemctl is-active --quiet "$service"; then
        echo "$service must be installed and running." >&2
        exit 1
    fi
done

docker compose version >/dev/null

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
config=/etc/rpi-wifi-link

install -d -m 0700 "$config"
exec 9>"$config/install.lock"
flock 9

docker compose -f "$repo/compose.yaml" up -d --build
