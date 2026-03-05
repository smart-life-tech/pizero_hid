#!/usr/bin/env bash
set -euo pipefail

failures=0

check_ok() {
  local message="$1"
  echo "[OK] ${message}"
}

check_fail() {
  local message="$1"
  echo "[FAIL] ${message}"
  failures=$((failures + 1))
}

if systemctl is-enabled hid-gadget.service >/dev/null 2>&1; then
  check_ok "hid-gadget.service is enabled"
else
  check_fail "hid-gadget.service is not enabled"
fi

if systemctl is-active hid-gadget.service >/dev/null 2>&1; then
  check_ok "hid-gadget.service is active"
else
  check_fail "hid-gadget.service is not active"
fi

service_result="$(systemctl show -p Result --value hid-gadget.service 2>/dev/null || true)"
if [[ "${service_result}" == "success" || "${service_result}" == "" ]]; then
  check_ok "hid-gadget.service result is healthy (${service_result:-n/a})"
else
  check_fail "hid-gadget.service result is ${service_result}"
fi

if [[ -c /dev/hidg0 ]]; then
  check_ok "/dev/hidg0 exists"
else
  check_fail "/dev/hidg0 missing"
fi

if [[ -c /dev/hidg1 ]]; then
  check_ok "/dev/hidg1 exists"
else
  check_fail "/dev/hidg1 missing"
fi

if [[ ${failures} -eq 0 ]]; then
  echo "HID verification PASSED"
  exit 0
fi

echo "HID verification FAILED (${failures} issue(s))"
exit 1
