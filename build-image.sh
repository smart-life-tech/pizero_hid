#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_GEN_DIR="${ROOT_DIR}/pi-gen"
CUSTOM_STAGE_SRC="${ROOT_DIR}/custom-stage"
CUSTOM_STAGE_DST="${PI_GEN_DIR}/stage-hid"

WIFI_SSID="${WIFI_SSID:-}"
WIFI_PSK="${WIFI_PSK:-}"
WIFI_COUNTRY="${WIFI_COUNTRY:-US}"
PI_GEN_BRANCH="${PI_GEN_BRANCH:-bookworm}"

if [[ -n "${SSH_CONNECTION:-}" ]] && [[ -z "${TMUX:-}" ]] && [[ -z "${STY:-}" ]]; then
  echo "INFO: Running over SSH without tmux/screen."
  echo "      If the network drops, your shell may terminate the build."
  echo "      Prefer: ./run-build-safe.sh"
fi

run_privileged() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    return 1
  fi
}

safe_unmount_target() {
  local target="$1"

  if [[ ! -e "${target}" ]]; then
    return 0
  fi

  run_privileged umount "${target}" >/dev/null 2>&1 \
    || run_privileged umount -l "${target}" >/dev/null 2>&1 \
    || true
}

cleanup_pi_gen_mounts() {
  local work_dir="${PI_GEN_DIR}/work"
  local found_stage=0

  if [[ ! -d "${work_dir}" ]]; then
    return 0
  fi

  while IFS= read -r -d '' stage_dir; do
    local rootfs="${stage_dir}/rootfs"
    local -a mount_targets=()
    local target

    if [[ ! -d "${rootfs}" ]]; then
      continue
    fi

    found_stage=1
    echo "Attempting stale mount cleanup in: ${stage_dir}"

    # Kill any process still holding open files in the chroot.
    if command -v fuser >/dev/null 2>&1; then
      run_privileged fuser -km "${rootfs}" >/dev/null 2>&1 || true
    fi

    if command -v findmnt >/dev/null 2>&1; then
      while IFS= read -r target; do
        mount_targets+=("${target}")
      done < <(findmnt -R -n -o TARGET "${rootfs}" 2>/dev/null | tac)
    fi

    if (( ${#mount_targets[@]} == 0 )); then
      mount_targets=(
        "${rootfs}/sys"
        "${rootfs}/proc"
        "${rootfs}/dev/pts"
        "${rootfs}/dev"
        "${rootfs}/run"
      )
    fi

    for target in "${mount_targets[@]}"; do
      safe_unmount_target "${target}"
    done
  done < <(find "${work_dir}" -mindepth 1 -maxdepth 2 -type d -name 'stage*' -print0 2>/dev/null)

  if (( found_stage == 1 )); then
    echo "Stale mount cleanup pass finished."
  fi
}

run_pi_gen_build() {
  if command -v docker >/dev/null 2>&1; then
    echo "Using Docker build (recommended)..."
    (cd "${PI_GEN_DIR}" && run_privileged ./build-docker.sh)
  else
    echo "Docker not found. Falling back to native build..."
    ensure_native_deps
    cleanup_pi_gen_mounts
    (cd "${PI_GEN_DIR}" && run_privileged ./build.sh)
  fi
}

ensure_native_deps() {
  # Only pre-check on Debian-like systems where we can provide exact package help.
  if ! command -v dpkg-query >/dev/null 2>&1; then
    return 0
  fi

  local -a required_pkgs=(
    quilt
    debootstrap
    zerofree
    libarchive-tools
    pigz
    arch-test
  )
  local -a missing_pkgs=()
  local pkg

  for pkg in "${required_pkgs[@]}"; do
    if ! dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "install ok installed"; then
      missing_pkgs+=("${pkg}")
    fi
  done

  # Some distros provide user-mode emulation via qemu-user-static instead.
  if ! dpkg-query -W -f='${Status}' qemu-user-binfmt 2>/dev/null | grep -q "install ok installed" \
    && ! dpkg-query -W -f='${Status}' qemu-user-static 2>/dev/null | grep -q "install ok installed"; then
    missing_pkgs+=("qemu-user-binfmt")
  fi

  # xxd may be shipped by either `xxd` or `vim-common`, depending on distro.
  if ! command -v xxd >/dev/null 2>&1; then
    if ! dpkg-query -W -f='${Status}' xxd 2>/dev/null | grep -q "install ok installed" \
      && ! dpkg-query -W -f='${Status}' vim-common 2>/dev/null | grep -q "install ok installed"; then
      missing_pkgs+=("xxd")
    fi
  fi

  if (( ${#missing_pkgs[@]} > 0 )); then
    echo "ERROR: Missing native pi-gen dependencies: ${missing_pkgs[*]}"
    echo
    echo "Install them with:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y ${missing_pkgs[*]}"
    echo "  # If qemu-user-binfmt is unavailable, try: sudo apt-get install -y qemu-user-static binfmt-support"
    echo
    echo "Then re-run: ./build-image.sh"
    exit 1
  fi
}

if [[ -z "${WIFI_SSID}" || -z "${WIFI_PSK}" ]]; then
  echo "ERROR: Set WIFI_SSID and WIFI_PSK before running."
  echo "Example: WIFI_SSID=\"ember_wolf\" WIFI_PSK=\"password\" ./build-image.sh"
  exit 1
fi

if [[ ! -d "${PI_GEN_DIR}" ]]; then
  git clone --depth 1 --branch "${PI_GEN_BRANCH}" https://github.com/RPi-Distro/pi-gen.git "${PI_GEN_DIR}"
else
  current_branch="$(git -C "${PI_GEN_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -n "${current_branch}" && "${current_branch}" != "${PI_GEN_BRANCH}" ]]; then
    echo "WARNING: pi-gen is on branch '${current_branch}', expected '${PI_GEN_BRANCH}'."
    echo "         This can trigger RELEASE mismatch warnings during build."
    echo "         To align: cd \"${PI_GEN_DIR}\" && git fetch --all && git checkout \"${PI_GEN_BRANCH}\""
  fi
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

if ! run_pi_gen_build; then
  echo
  echo "Build failed. Running emergency cleanup for stuck pi-gen mounts..."
  cleanup_pi_gen_mounts
  echo
  echo "If this persists, inspect holders with:"
  echo "  sudo lsof +D \"${PI_GEN_DIR}/work\""
  echo "Then retry: ./build-image.sh"
  exit 1
fi

echo
echo "Build complete. Check output in: ${PI_GEN_DIR}/deploy"
