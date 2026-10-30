#!/usr/bin/env zsh
# zsh-utm.plugin.zsh - UTM virtual machine control for zsh
#
# Main plugin entry point that loads libraries and sets up the utm command
# and its completions.

# Get plugin directory
0="${${FUNCNAME[0]:-${(%):-%x}}:A}"
ZSH_UTM_PLUGIN_DIR="${0:h}"

# Default settings
: ${ZSH_UTM_TIMEOUT:=60}
: ${GUM_LOG_LEVEL:="info"}

# DEBUG support: if DEBUG=1, enable debug logging and shell tracing
if [[ -n "$DEBUG" ]]; then
    export GUM_LOG_LEVEL="debug"
    set -x
fi

# Export GUM_LOG_LEVEL so gum can see it
export GUM_LOG_LEVEL

# Load library files
source "${ZSH_UTM_PLUGIN_DIR}/lib/log.zsh"
source "${ZSH_UTM_PLUGIN_DIR}/lib/utmctl.zsh"
source "${ZSH_UTM_PLUGIN_DIR}/lib/vm.zsh"
source "${ZSH_UTM_PLUGIN_DIR}/lib/snapshot.zsh"

# Add directories to fpath for autoload and completions
fpath=("${ZSH_UTM_PLUGIN_DIR}/functions" "${ZSH_UTM_PLUGIN_DIR}/completions" $fpath)

# Source user commands (functions with explicit definitions)
source "${ZSH_UTM_PLUGIN_DIR}/functions/utm"

# Autoload completion functions
autoload -Uz _utm
