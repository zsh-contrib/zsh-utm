#!/usr/bin/env zsh
# Stubs for the tools the plugin calls, sourced by the tests before the plugin.
#
# gum logs the bare message to stderr. utmctl prints the command line it was
# given, except for the commands whose output the plugin parses. STUB_STATUS
# sets the status it reports (started by default), STUB_LOG is a file every
# call is appended to. osascript and plutil only log their calls, plutil fails
# when STUB_PLUTIL_FAIL is set and reports no key path when STUB_PLUTIL_MISSING is.

gum() { shift 3; print -r -u2 -- "$*"; }

utmctl() {
    [[ -n "$STUB_LOG" ]] && print -r -- "utmctl $*" >> "$STUB_LOG"

    case "$1" in
    status) print -r -- "${STUB_STATUS:-started}" ;;
    list)
        print -r -- "UUID                                 Status   Name"
        print -r -- "5D419106-2824-4FED-BFE1-24A7F7E253D8 started  Ubuntu"
        print -r -- "0C7E6D3A-6F2B-4B9E-9C60-3D1F6A1E8B21 stopped  Linux 2"
        ;;
    snapshot)
        if [[ "$2" == list ]]; then
            print -r -- $'second\t30/10/2026, 18:47\tfirst\tdisks only'
            print -r -- $'first\t30/10/2026, 18:46\t-\tdisks only'
        else
            print -r -- "utmctl $*"
        fi
        ;;
    *) print -r -- "utmctl $*" ;;
    esac
}

osascript() {
    [[ -n "$STUB_LOG" ]] && print -r -- "osascript ${1:t} ${*:2}" >> "$STUB_LOG"
    return 0
}

plutil() {
    [[ -n "$STUB_LOG" ]] && print -r -- "plutil $*" >> "$STUB_LOG"
    [[ "$1" == -type && -n "$STUB_PLUTIL_MISSING" ]] && return 1
    [[ -z "$STUB_PLUTIL_FAIL" ]]
}
