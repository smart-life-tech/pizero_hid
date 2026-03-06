#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo ./setup-live-pizero.sh"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="${ROOT_DIR}/custom-stage/files"
APPLY_WIFI="${APPLY_WIFI:-0}"

if [[ ! -d "${FILES_DIR}" ]]; then
  echo "ERROR: Missing files directory: ${FILES_DIR}"
  exit 1
fi

BOOT_DIR="/boot/firmware"
if [[ ! -d "${BOOT_DIR}" ]]; then
  BOOT_DIR="/boot"
fi

CONFIG_TXT="${BOOT_DIR}/config.txt"
CMDLINE_TXT="${BOOT_DIR}/cmdline.txt"

if [[ ! -f "${CONFIG_TXT}" || ! -f "${CMDLINE_TXT}" ]]; then
  echo "ERROR: Could not find boot files in ${BOOT_DIR}"
  exit 1
fi

install -m 755 "${FILES_DIR}/usb-hid-gadget.sh" /usr/local/sbin/usb-hid-gadget.sh
install -m 755 "${FILES_DIR}/hid-postboot-verify.sh" /usr/local/sbin/hid-postboot-verify.sh
install -m 644 "${FILES_DIR}/hid-gadget.service" /etc/systemd/system/hid-gadget.service

if [[ "${APPLY_WIFI}" == "1" ]]; then
  if [[ -z "${WIFI_SSID:-}" || -z "${WIFI_PSK:-}" ]]; then
    echo "ERROR: APPLY_WIFI=1 requires WIFI_SSID and WIFI_PSK"
    exit 1
  fi

  install -d -m 755 /etc/wpa_supplicant
  cat > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=${WIFI_COUNTRY:-US}

network={
    ssid="${WIFI_SSID}"
    psk="${WIFI_PSK}"
    key_mgmt=WPA-PSK
}
EOF
  chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
else
  echo "Skipping Wi-Fi config update (APPLY_WIFI=${APPLY_WIFI})."
fi

if ! grep -q '^dtoverlay=dwc2' "${CONFIG_TXT}"; then
  echo 'dtoverlay=dwc2,dr_mode=peripheral' >> "${CONFIG_TXT}"
fi

if ! grep -q 'modules-load=dwc2' "${CMDLINE_TXT}"; then
  sed -i '1 s/$/ modules-load=dwc2/' "${CMDLINE_TXT}"
fi

systemctl daemon-reload
systemctl enable ssh
systemctl enable hid-gadget.service

echo "Setup complete. Reboot required: sudo reboot"
echo "After reboot, verify with: sudo /usr/local/sbin/hid-postboot-verify.sh"
