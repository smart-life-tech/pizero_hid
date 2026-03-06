#!/usr/bin/env bash
set -euo pipefail

GADGET_DIR="/sys/kernel/config/usb_gadget/pi_hid"

# Defaults are intentionally conservative and Windows-friendly.
USB_VID="${USB_VID:-0x1d6b}"
USB_PID="${USB_PID:-0x0104}"
USB_BCD_DEVICE="${USB_BCD_DEVICE:-0x0100}"
USB_BCD_USB="${USB_BCD_USB:-0x0200}"
USB_SERIAL="${USB_SERIAL:-PIHID00000001}"
USB_MANUFACTURER="${USB_MANUFACTURER:-Raspberry Pi}"
USB_PRODUCT="${USB_PRODUCT:-Pi Zero HID Composite}"

write_desc() {
  local raw_bytes="$1"
  local out_file="$2"
  printf "%b" "${raw_bytes}" > "${out_file}"
}

if [[ -d "${GADGET_DIR}" ]] && [[ -f "${GADGET_DIR}/UDC" ]] && [[ -n "$(cat "${GADGET_DIR}/UDC" 2>/dev/null || true)" ]]; then
  exit 0
fi

modprobe libcomposite

mkdir -p "${GADGET_DIR}"
cd "${GADGET_DIR}"

echo "${USB_VID}" > idVendor
echo "${USB_PID}" > idProduct
echo "${USB_BCD_DEVICE}" > bcdDevice
echo "${USB_BCD_USB}" > bcdUSB

# Class at device level is per-interface (0x00) for HID composite.
echo 0x00 > bDeviceClass
echo 0x00 > bDeviceSubClass
echo 0x00 > bDeviceProtocol
echo 64 > bMaxPacketSize0

mkdir -p strings/0x409
echo "${USB_SERIAL}" > strings/0x409/serialnumber
echo "${USB_MANUFACTURER}" > strings/0x409/manufacturer
echo "${USB_PRODUCT}" > strings/0x409/product

mkdir -p configs/c.1/strings/0x409
echo "Config 1: Keyboard + Mouse" > configs/c.1/strings/0x409/configuration
echo 0x80 > configs/c.1/bmAttributes
echo 250 > configs/c.1/MaxPower

mkdir -p functions/hid.keyboard
# Boot keyboard (8-byte report) for maximum Windows compatibility.
echo 1 > functions/hid.keyboard/protocol
echo 1 > functions/hid.keyboard/subclass
echo 8 > functions/hid.keyboard/report_length
write_desc '\x05\x01\x09\x06\xA1\x01\x05\x07\x19\xE0\x29\xE7\x15\x00\x25\x01\x75\x01\x95\x08\x81\x02\x95\x01\x75\x08\x81\x01\x95\x05\x75\x01\x05\x08\x19\x01\x29\x05\x91\x02\x95\x01\x75\x03\x91\x01\x95\x06\x75\x08\x15\x00\x25\x65\x05\x07\x19\x00\x29\x65\x81\x00\xC0' functions/hid.keyboard/report_desc

mkdir -p functions/hid.mouse
# Boot mouse with wheel (4-byte report: buttons, X, Y, wheel).
echo 2 > functions/hid.mouse/protocol
echo 1 > functions/hid.mouse/subclass
echo 4 > functions/hid.mouse/report_length
write_desc '\x05\x01\x09\x02\xA1\x01\x09\x01\xA1\x00\x05\x09\x19\x01\x29\x03\x15\x00\x25\x01\x95\x03\x75\x01\x81\x02\x95\x01\x75\x05\x81\x01\x05\x01\x09\x30\x09\x31\x09\x38\x15\x81\x25\x7F\x75\x08\x95\x03\x81\x06\xC0\xC0' functions/hid.mouse/report_desc

ln -sf functions/hid.keyboard configs/c.1/
ln -sf functions/hid.mouse configs/c.1/

UDC_DEVICE="$(ls /sys/class/udc | head -n 1)"
if [[ -z "${UDC_DEVICE}" ]]; then
  echo "No UDC device found; cannot bind gadget" >&2
  exit 1
fi

echo "${UDC_DEVICE}" > UDC
