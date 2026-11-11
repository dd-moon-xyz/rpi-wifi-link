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
if [ ! -s "$config/setup-key" ]; then
    umask 077
    key_file=$(mktemp "$config/setup-key.XXXXXX")
    trap 'rm -f "$key_file"' EXIT
    od -An -N32 -tx1 /dev/urandom | tr -d ' \n' > "$key_file"
    if [ "$(wc -c < "$key_file")" -ne 64 ]; then
        echo "Failed to generate a setup key." >&2
        exit 1
    fi
    mv "$key_file" "$config/setup-key"
    trap - EXIT
fi

SETUP_KEY_FILE="$config/setup-key" docker compose -f "$repo/compose.yaml" up -d --build
