#!/bin/bash

if [[ -n "${__ANDROID_EMULATOR_SCRIPT_UTILS_SH:-}" ]]; then
    return 0
fi
readonly __ANDROID_EMULATOR_SCRIPT_UTILS_SH=1

: "${LOG_NAME:=$(basename "$0")}" 

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    readonly LOG_COLOR_INFO='\033[0;34m'
    readonly LOG_COLOR_WARN='\033[1;33m'
    readonly LOG_COLOR_ERROR='\033[0;31m'
    readonly LOG_COLOR_SUCCESS='\033[0;32m'
    readonly LOG_COLOR_RESET='\033[0m'
else
    readonly LOG_COLOR_INFO=''
    readonly LOG_COLOR_WARN=''
    readonly LOG_COLOR_ERROR=''
    readonly LOG_COLOR_SUCCESS=''
    readonly LOG_COLOR_RESET=''
fi

log_timestamp() {
    date '+%H:%M:%S'
}

log_message() {
    local level="$1"
    local color="$2"
    shift 2

    printf '%b[%s] %-5s%b [%s] %s\n' \
        "$color" \
        "$(log_timestamp)" \
        "$level" \
        "$LOG_COLOR_RESET" \
        "$LOG_NAME" \
        "$*"
}

log_info() {
    log_message "INFO" "$LOG_COLOR_INFO" "$*"
}

log_warn() {
    log_message "WARN" "$LOG_COLOR_WARN" "$*"
}

log_error() {
    log_message "ERROR" "$LOG_COLOR_ERROR" "$*"
}

log_success() {
    log_message "OK" "$LOG_COLOR_SUCCESS" "$*"
}

abort_with_error() {
    log_error "$*"
    exit 1
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        abort_with_error "Required command not found: ${command_name}"
    fi
}

is_valid_port() {
    local port="$1"

    [[ "$port" =~ ^[0-9]+$ ]] && (( port > 0 && port <= 65535 ))
}

cpu_architecture() {
    uname -m
}

is_arm64_arch() {
    local architecture="${1:-$(cpu_architecture)}"

    [[ "${architecture}" == "arm64" ]] || [[ "${architecture}" == "aarch64" ]]
}

emulator_support_note() {
    printf '%s\n' 'Android emulator is not supported inside this Docker image on ARM64/Apple Silicon. Use ./start_appium.sh with a real device, or run the emulator directly on the host machine.'
}

assert_emulator_supported() {
    local architecture
    architecture="$(cpu_architecture)"

    if is_arm64_arch "${architecture}"; then
        abort_with_error "$(emulator_support_note)"
    fi
}