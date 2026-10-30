#!/usr/bin/env zsh
# lib/utmctl.zsh - bridge to utmctl, the command line tool that ships with UTM

# Run utmctl and print what it prints on success
# utmctl is on PATH when UTM was installed with Homebrew, otherwise it is inside the app bundle.
# Usage: _zsh_utm_ctl <utmctl-args...>
_zsh_utm_ctl() {
    local bin="utmctl"

    if ! command -v utmctl >/dev/null 2>&1; then
        bin="/Applications/UTM.app/Contents/MacOS/utmctl"
        if [[ ! -x "$bin" ]]; then
            _zsh_utm_log error "utmctl not found (zsh-utm requires UTM on macOS)"
            return 1
        fi
    fi

    # Keep stderr apart so error text never ends up in the returned value
    local errfile
    errfile=$(mktemp) || return 1

    local output error
    if ! output=$("$bin" "$@" 2>"$errfile"); then
        error=$(<"$errfile")
        rm -f "$errfile"
        error="${error:-${output:-utmctl failed}}"
        _zsh_utm_log error "${error#Error: }"
        return 1
    fi
    rm -f "$errfile"

    [[ -n "$output" ]] && print -r -- "$output"
    return 0
}
