#!/bin/bash
renkit_brand_run() {
    local renderer_args=(--keep-footer --allow-pipe-output)
    # Shell-function callbacks and redirected output keep their existing behavior.
    if ! declare -F "$1" >/dev/null && [ -t 0 ] &&
        { [ -t 1 ] || [ "${RENKIT_BRAND_TTY:-0}" = 1 ]; } &&
        [ "${TERM:-}" != dumb ] && command -v python3 >/dev/null 2>&1; then
        [ -z "${RENKIT_BRAND_LOG:-}" ] || renderer_args+=(--log-file "$RENKIT_BRAND_LOG")
        python3 "$PROJECT_ROOT/scripts/terminal_brand.py" "${renderer_args[@]}" -- "$@"
    elif [ -n "${RENKIT_BRAND_LOG:-}" ]; then
        "$@" 2>&1 | tee "$RENKIT_BRAND_LOG"
        return "${PIPESTATUS[0]}"
    else
        "$@"
    fi
}
