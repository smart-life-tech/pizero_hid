#!/usr/bin/env bash
set -euo pipefail

GADGET_DIR="/sys/kernel/config/usb_gadget/pi_hid"

if [[ -d "${GADGET_DIR}" ]] && [[ -f "${GADGET_DIR}/UDC" ]] && [[ -n "$(cat "${GADGET_DIR}/UDC" 2>/dev/null || true)" ]]; then
  exit 0
fi

modprobe libcomposite

mkdir -p "${GADGET_DIR}"
cd "${GADGET_DIR}"

echo 0x1d6b > idVendor
echo 0x0104 > idProduct
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

mkdir -p strings/0x409
echo "DEADBEEF1234" > strings/0x409/serialnumber
echo "Raspberry Pi" > strings/0x409/manufacturer
echo "Pi Zero HID Composite" > strings/0x409/product

mkdir -p configs/c.1/strings/0x409
echo "Config 1: Keyboard + Mouse" > configs/c.1/strings/0x409/configuration
echo 250 > configs/c.1/MaxPower

mkdir -p functions/hid.keyboard
echo 1 > functions/hid.keyboard/protocol
echo 1 > functions/hid.keyboard/subclass
echo 8 > functions/hid.keyboard/report_length
echo -ne '\x05\x01\x09\x06\xA1\x01\x05\x07\x19\xE0\x29\xE7\x15\x00\x25\x01\x75\x01\x95\x08\x81\x02\x95\x01\x75\x08\x81\x01\x95\x05\x75\x01\x05\x08\x19\x01\x29\x05\x91\x02\x95\x01\x75\x03\x91\x01\x95\x06\x75\x08\x15\x00\x25\x65\x05\x07\x19\x00\x29\x65\x81\x00\xC0' > functions/hid.keyboard/report_desc

mkdir -p functions/hid.mouse
echo 2 > functions/hid.mouse/protocol
echo 1 > functions/hid.mouse/subclass
echo 4 > functions/hid.mouse/report_length
echo -ne '\x05\x01\x09\x02\xA1\x01\x09\x01\xA1\x00\x05\x09\x19\x01\x29\x03\x15\x00\x25\x01\x95\x03\x75\x01\x81\x02\x95\x01\x75\x05\x81\x01\x05\x01\x09\x30\x09\x31\x09\x38\x15\x81\x25\x7F\x75\x08\x95\x03\x81\x06\xC0\xC0' > functions/hid.mouse/report_desc

ln -sf functions/hid.keyboard configs/c.1/
ln -sf functions/hid.mouse configs/c.1/

UDC_DEVICE="$(ls /sys/class/udc | head -n 1)"
if [[ -z "${UDC_DEVICE}" ]]; then
  echo "No UDC device found; cannot bind gadget" >&2
  exit 1
fi

echo "${UDC_DEVICE}" > UDC
