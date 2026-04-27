#!/bin/bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_NAME="$(basename "$0")"
# shellcheck source=./script_utils.sh
source "${SCRIPT_DIR}/script_utils.sh"

if [[ -n "${EMULATOR_NAME:-}" ]]; then
  readonly TARGET_EMULATOR_NAME="${EMULATOR_NAME}"
else
  readonly TARGET_EMULATOR_NAME="nexus"
fi

EMULATOR_PID=""

kill_existing_emulators() {
  while read -r device_id _; do
    [[ "${device_id}" == emulator-* ]] || continue
    log_warn "Stopping existing emulator instance ${device_id}"
    adb -s "${device_id}" emu kill >/dev/null 2>&1 || true
  done < <(adb devices)
}

launch_emulator() {
  assert_emulator_supported
  require_command emulator
  require_command adb

  if [[ -z "${EMULATOR_NAME:-}" ]]; then
    log_warn "EMULATOR_NAME is not set, defaulting to ${TARGET_EMULATOR_NAME}"
  fi

  kill_existing_emulators
  log_info "Launching emulator ${TARGET_EMULATOR_NAME} in headed mode"
  emulator -avd "${TARGET_EMULATOR_NAME}" -no-boot-anim -gpu off &
  EMULATOR_PID=$!
}

wait_for_emulator() {
  local timeout="${EMULATOR_TIMEOUT:-300}"
  local start_time
  local current_time
  local elapsed_time
  local boot_state

  start_time="$(date +%s)"
  log_info "Waiting for emulator boot completion (timeout: ${timeout}s)"

  while true; do
    if ! kill -0 "${EMULATOR_PID}" >/dev/null 2>&1; then
      abort_with_error "Emulator exited before boot completed"
    fi

    boot_state="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [[ "${boot_state}" == "1" ]]; then
      adb shell input keyevent 82 >/dev/null 2>&1 || true
      log_success "Emulator ${TARGET_EMULATOR_NAME} is ready"
      return 0
    fi

    current_time="$(date +%s)"
    elapsed_time=$((current_time - start_time))
    if (( elapsed_time > timeout )); then
      abort_with_error "Timed out after ${timeout}s waiting for the emulator to boot"
    fi

    if (( elapsed_time > 0 && elapsed_time % 20 == 0 )); then
      log_info "Still waiting for emulator boot completion (${elapsed_time}s elapsed)"
    fi

    sleep 4
  done
}

disable_animation() {
  log_info "Disabling Android system animations"
  adb shell "settings put global window_animation_scale 0.0" >/dev/null
  adb shell "settings put global transition_animation_scale 0.0" >/dev/null
  adb shell "settings put global animator_duration_scale 0.0" >/dev/null
  log_success "System animations disabled"
}

cleanup() {
  if [[ -n "${EMULATOR_PID}" ]] && kill -0 "${EMULATOR_PID}" >/dev/null 2>&1; then
    log_warn "Stopping emulator ${TARGET_EMULATOR_NAME}"
    kill "${EMULATOR_PID}" >/dev/null 2>&1 || true
  fi
}

main() {
  launch_emulator
  wait_for_emulator
  disable_animation
  wait "${EMULATOR_PID}"
}

trap cleanup EXIT SIGINT SIGTERM SIGHUP

main