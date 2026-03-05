#!/bin/bash -e

install -m 755 files/usb-hid-gadget.sh "${ROOTFS_DIR}/usr/local/sbin/usb-hid-gadget.sh"
install -m 755 files/hid-postboot-verify.sh "${ROOTFS_DIR}/usr/local/sbin/hid-postboot-verify.sh"
install -m 644 files/hid-gadget.service "${ROOTFS_DIR}/etc/systemd/system/hid-gadget.service"
install -m 600 files/wpa_supplicant-wlan0.conf "${ROOTFS_DIR}/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"

on_chroot << 'EOF'
systemctl enable ssh
systemctl enable hid-gadget.service
EOF

CONFIG_TXT="${BOOTFS_DIR}/config.txt"
if ! grep -q '^dtoverlay=dwc2' "${CONFIG_TXT}"; then
  echo 'dtoverlay=dwc2,dr_mode=peripheral' >> "${CONFIG_TXT}"
fi

CMDLINE_TXT="${BOOTFS_DIR}/cmdline.txt"
if ! grep -q 'modules-load=dwc2' "${CMDLINE_TXT}"; then
  sed -i '1 s/$/ modules-load=dwc2/' "${CMDLINE_TXT}"
fi
