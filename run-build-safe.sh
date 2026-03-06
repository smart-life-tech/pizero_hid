#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${ROOT_DIR}/logs"
mkdir -p "${LOG_DIR}"

WIFI_SSID="${WIFI_SSID:-}"
WIFI_PSK="${WIFI_PSK:-}"
WIFI_COUNTRY="${WIFI_COUNTRY:-US}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/build-$(date +%Y%m%d-%H%M%S).log}"

if [[ -z "${WIFI_SSID}" || -z "${WIFI_PSK}" ]]; then
  echo "ERROR: Set WIFI_SSID and WIFI_PSK before running."
  echo "Example: WIFI_SSID=\"ember_wolf\" WIFI_PSK=\"password\" ./run-build-safe.sh"
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "ERROR: sudo is required."
  exit 1
fi

if ! command -v nohup >/dev/null 2>&1; then
  echo "ERROR: nohup is required."
  exit 1
fi

# Prime sudo credentials up front so detached execution won't stall on a password prompt.
echo "Checking sudo access..."
sudo -v

echo "Starting detached build..."
echo "Log file: ${LOG_FILE}"

nohup env \
  WIFI_SSID="${WIFI_SSID}" \
  WIFI_PSK="${WIFI_PSK}" \
  WIFI_COUNTRY="${WIFI_COUNTRY}" \
  "${ROOT_DIR}/build-image.sh" > "${LOG_FILE}" 2>&1 &

PID=$!
echo "Build started with PID: ${PID}"
echo "Follow log with: tail -f \"${LOG_FILE}\""
echo "Check process with: ps -fp ${PID}"
