#!/bin/bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_NAME="$(basename "$0")"
# shellcheck source=./script_utils.sh
source "${SCRIPT_DIR}/script_utils.sh"

main() {
    local architecture
    architecture="$(cpu_architecture)"

    if is_arm64_arch "${architecture}"; then
        log_warn "ARM64 container detected; Android emulator startup is disabled"
        log_info "Starting Appium with native adb support instead"
        exec "${SCRIPT_DIR}/start_appium.sh"
    fi

    log_info "Launching the Android emulator in headless mode"
    exec "${SCRIPT_DIR}/start_emu_headless.sh"
}

main