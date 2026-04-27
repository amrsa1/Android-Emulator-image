#!/bin/bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_NAME="$(basename "$0")"
# shellcheck source=./script_utils.sh
source "${SCRIPT_DIR}/script_utils.sh"

XVFB_PID=""
FLUXBOX_PID=""
VNC_PID=""
readonly FLUXBOX_LOG_FILE="/tmp/fluxbox.log"

main() {
    log_info "Starting VNC session"
    warn_if_shell_only_session
    launch_xvfb
    launch_window_manager
    run_vnc_server
}

warn_if_shell_only_session() {
    local architecture
    architecture="$(cpu_architecture)"

    if is_arm64_arch "${architecture}"; then
        log_warn "ARM64 container detected; VNC provides a Fluxbox desktop, not a runnable Android emulator"
        log_warn "$(emulator_support_note)"
        log_info "Use ./start_appium.sh for Apple Silicon or run the emulator directly on an amd64 host"
    fi
}

ensure_fluxbox_profile() {
    local profile_dir="${HOME}/.fluxbox"
    local defaults_dir="/etc/X11/fluxbox"

    if [[ -f "${profile_dir}/init" ]]; then
        return 0
    fi

    mkdir -p "${profile_dir}"
    cp -n "${defaults_dir}"/* "${profile_dir}/"
    log_info "Initialized default Fluxbox profile in ${profile_dir}"
}

launch_xvfb() {
    require_command Xvfb
    require_command xdpyinfo

    export DISPLAY="${XVFB_DISPLAY:-:1}"
    local screen="${XVFB_SCREEN:-0}"
    local resolution="${XVFB_RESOLUTION:-1280x1024x24}"
    local timeout="${XVFB_TIMEOUT:-5}"
    local loop_count=0

    log_info "Starting Xvfb on ${DISPLAY} with screen ${screen} and resolution ${resolution}"
    Xvfb "${DISPLAY}" -screen "${screen}" "${resolution}" &
    XVFB_PID=$!

    until xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; do
        if ! kill -0 "${XVFB_PID}" >/dev/null 2>&1; then
            abort_with_error "Xvfb exited before the display became ready"
        fi

        loop_count=$((loop_count + 1))
        if (( loop_count > timeout )); then
            abort_with_error "Timed out waiting ${timeout}s for Xvfb to become ready"
        fi

        sleep 1
    done

    log_success "Xvfb is ready on ${DISPLAY}"
}

launch_window_manager() {
    require_command fluxbox
    require_command wmctrl

    local timeout="${XVFB_TIMEOUT:-5}"
    local loop_count=0

    ensure_fluxbox_profile
    log_info "Starting Fluxbox window manager"
    fluxbox >"${FLUXBOX_LOG_FILE}" 2>&1 &
    FLUXBOX_PID=$!

    until wmctrl -m >/dev/null 2>&1; do
        if ! kill -0 "${FLUXBOX_PID}" >/dev/null 2>&1; then
            abort_with_error "Fluxbox exited before the window manager became ready"
        fi

        loop_count=$((loop_count + 1))
        if (( loop_count > timeout )); then
            abort_with_error "Timed out waiting ${timeout}s for Fluxbox to become ready"
        fi

        sleep 1
    done

    log_success "Fluxbox window manager is ready"
}

run_vnc_server() {
    require_command x11vnc

    local -a password_args=(-nopw)

    if [[ -n "${VNC_PASSWORD:-}" ]]; then
        local password_file_path="${HOME}/x11vnc.pass"

        if ! x11vnc -storepasswd "${VNC_PASSWORD}" "${password_file_path}" >/dev/null; then
            abort_with_error "Failed to store the x11vnc password"
        fi

        password_args=(-rfbauth "${password_file_path}")
        log_info "VNC authentication is enabled"
    else
        log_warn "VNC authentication is disabled"
    fi

    log_success "Starting VNC server on display ${DISPLAY}"
    x11vnc -ncache_cr -display "${DISPLAY}" -forever "${password_args[@]}" &
    VNC_PID=$!
    wait "${VNC_PID}"
}

cleanup() {
    if [[ -n "${VNC_PID}" ]] && kill -0 "${VNC_PID}" >/dev/null 2>&1; then
        kill "${VNC_PID}" >/dev/null 2>&1 || true
    fi

    if [[ -n "${FLUXBOX_PID}" ]] && kill -0 "${FLUXBOX_PID}" >/dev/null 2>&1; then
        kill "${FLUXBOX_PID}" >/dev/null 2>&1 || true
    fi

    if [[ -n "${XVFB_PID}" ]] && kill -0 "${XVFB_PID}" >/dev/null 2>&1; then
        kill "${XVFB_PID}" >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT SIGINT SIGTERM SIGHUP

main