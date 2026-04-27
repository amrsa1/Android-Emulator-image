#!/bin/bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_NAME="$(basename "$0")"
readonly DEFAULT_APPIUM_PORT="4723"
# shellcheck source=./script_utils.sh
source "${SCRIPT_DIR}/script_utils.sh"

resolve_appium_port() {
    local port="${APPIUM_PORT:-}"

    if [[ -z "${port}" ]] || [[ "${port}" == "null" ]]; then
        log_warn "APPIUM_PORT is not set, defaulting to ${DEFAULT_APPIUM_PORT}"
        printf '%s\n' "${DEFAULT_APPIUM_PORT}"
        return 0
    fi

    if ! is_valid_port "${port}"; then
        abort_with_error "APPIUM_PORT must be an integer between 1 and 65535"
    fi

    printf '%s\n' "${port}"
}

main() {
    require_command appium

    local port
    port="$(resolve_appium_port)"

    log_info "Starting Appium server on port ${port}"
    exec appium -p "${port}"
}

main