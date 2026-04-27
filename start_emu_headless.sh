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

readonly EMULATOR_LOG_FILE="/tmp/android-emulator-headless.log"
EMULATOR_PID=""

check_hardware_acceleration() {
  if [[ -n "${HW_ACCEL_OVERRIDE:-}" ]]; then
    printf '%s\n' "${HW_ACCEL_OVERRIDE}"
    return 0
  fi

  local hw_accel_support=0

  if [[ "${OSTYPE}" == darwin* ]]; then
    hw_accel_support="$(sysctl -a 2>/dev/null | grep -E -c '(vmx|svm)')"
  elif [[ -r /proc/cpuinfo ]]; then
    hw_accel_support="$(grep -E -c '(vmx|svm)' /proc/cpuinfo)"
  fi

  if [[ "${hw_accel_support}" == "0" ]]; then
    printf '%s\n' '-accel off'
  else
    printf '%s\n' '-accel on'
  fi
}

resolve_gpu_mode() {
  if [[ "${OSTYPE}" == *linux* ]]; then
    printf '%s\n' 'off'
    return 0
  fi

  if [[ "${OSTYPE}" == *darwin* ]] || [[ "${OSTYPE}" == *macos* ]]; then
    printf '%s\n' 'swiftshader_indirect'
    return 0
  fi

  abort_with_error "Unsupported operating system for emulator startup: ${OSTYPE}"
}

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

  local hw_accel_flag
  local gpu_mode
  local -a command_args

  hw_accel_flag="$(check_hardware_acceleration)"
  gpu_mode="$(resolve_gpu_mode)"

  kill_existing_emulators

  command_args=(
    -avd "${TARGET_EMULATOR_NAME}"
    -no-window
    -no-snapshot
    -noaudio
    -no-boot-anim
    -memory 2048
    -camera-back none
    -gpu "${gpu_mode}"
  )

  if [[ "${hw_accel_flag}" == "-accel off" ]]; then
    command_args+=(-accel off)
  else
    command_args+=(-accel on)
  fi

  log_info "Launching emulator ${TARGET_EMULATOR_NAME} in headless mode"
  log_info "Hardware acceleration: ${hw_accel_flag}; GPU mode: ${gpu_mode}; log: ${EMULATOR_LOG_FILE}"
  nohup emulator "${command_args[@]}" >"${EMULATOR_LOG_FILE}" 2>&1 &
  EMULATOR_PID=$!
}

check_emulator_status() {
  local timeout="${EMULATOR_TIMEOUT:-300}"
  local start_time
  local current_time
  local elapsed_time
  local boot_state

  start_time="$(date +%s)"
  log_info "Waiting for emulator boot completion (timeout: ${timeout}s)"

  while true; do
    if ! kill -0 "${EMULATOR_PID}" >/dev/null 2>&1; then
      abort_with_error "Emulator exited before boot completed; see ${EMULATOR_LOG_FILE}"
    fi

    boot_state="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [[ "${boot_state}" == "1" ]]; then
      adb devices -l
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

hidden_policy() {
  log_info "Relaxing hidden API policy"
  adb shell "settings put global hidden_api_policy_pre_p_apps 1;settings put global hidden_api_policy_p_apps 1;settings put global hidden_api_policy 1" >/dev/null
  log_success "Hidden API policy updated"
}

cleanup() {
  if [[ -n "${EMULATOR_PID}" ]] && kill -0 "${EMULATOR_PID}" >/dev/null 2>&1; then
    log_warn "Stopping emulator ${TARGET_EMULATOR_NAME}"
    kill "${EMULATOR_PID}" >/dev/null 2>&1 || true
  fi
}

main() {
  launch_emulator
  check_emulator_status
  disable_animation
  hidden_policy
  wait "${EMULATOR_PID}"
}

trap cleanup EXIT SIGINT SIGTERM SIGHUP

main