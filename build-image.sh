#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_GEN_DIR="${ROOT_DIR}/pi-gen"
CUSTOM_STAGE_SRC="${ROOT_DIR}/custom-stage"
CUSTOM_STAGE_DST="${PI_GEN_DIR}/stage-hid"

WIFI_SSID="${WIFI_SSID:-}"
WIFI_PSK="${WIFI_PSK:-}"
WIFI_COUNTRY="${WIFI_COUNTRY:-US}"

if [[ -z "${WIFI_SSID}" || -z "${WIFI_PSK}" ]]; then
  echo "ERROR: Set WIFI_SSID and WIFI_PSK before running."
  echo "Example: WIFI_SSID=\"ember_wolf\" WIFI_PSK=\"password\" ./build-image.sh"
  exit 1
fi

if [[ ! -d "${PI_GEN_DIR}" ]]; then
  git clone --depth 1 https://github.com/RPi-Distro/pi-gen.git "${PI_GEN_DIR}"
fi

if [[ ! -d "${CUSTOM_STAGE_SRC}" ]]; then
  echo "ERROR: custom-stage directory not found at ${CUSTOM_STAGE_SRC}"
  exit 1
fi

rm -rf "${CUSTOM_STAGE_DST}"
cp -a "${CUSTOM_STAGE_SRC}" "${CUSTOM_STAGE_DST}"

WPA_FILE="${CUSTOM_STAGE_DST}/files/wpa_supplicant-wlan0.conf"
cat > "${WPA_FILE}" <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=${WIFI_COUNTRY}

network={
    ssid="${WIFI_SSID}"
    psk="${WIFI_PSK}"
    key_mgmt=WPA-PSK
}
EOF

cat > "${PI_GEN_DIR}/config" <<'EOF'
IMG_NAME='pizero2w-hid-composite'
RELEASE='bookworm'
TARGET_HOSTNAME='pizero-hid'
FIRST_USER_NAME='pi'
FIRST_USER_PASS='raspberry'
ENABLE_SSH=1
STAGE_LIST="stage0 stage1 stage2 stage-hid"
DEPLOY_COMPRESSION='none'
EOF

if command -v docker >/dev/null 2>&1; then
  echo "Using Docker build (recommended)..."
  (cd "${PI_GEN_DIR}" && sudo ./build-docker.sh)
else
  echo "Docker not found. Falling back to native build..."
  (cd "${PI_GEN_DIR}" && sudo ./build.sh)
fi

echo
echo "Build complete. Check output in: ${PI_GEN_DIR}/deploy"
