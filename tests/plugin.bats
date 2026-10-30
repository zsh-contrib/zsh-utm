#!/usr/bin/env bats

# Tests for the zsh-utm utm command
#
# Requires bats-core (https://github.com/bats-core/bats-core)
# Run: bats tests/plugin.bats

export PLUGIN_DIR
PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
  if ! command -v zsh &>/dev/null; then
    skip "zsh is not installed"
  fi
}

# Loads the plugin with gum and osascript stubbed. gum logs the bare message
# to stderr. The osascript stub prints its script and its arguments (after
# --), then a fixed "started" status, to stdout. With STUB_QUIET set it
# only prints the status, for tests that poll it.
load_plugin() {
  echo "
    gum() { shift 3; print -r -u2 -- \"\$*\"; }
    osascript() {
      [[ -n \"\$STUB_QUIET\" ]] && { print -r -- 'started'; return; }
      print -r -- \"\$2\"
      shift 3
      print -r -- \"args: \$*\"
      print -r -- 'started'
    }
    source \"\$PLUGIN_DIR/zsh-utm.plugin.zsh\"
  "
}

@test "utm: prints usage and fails without a command" {
  run zsh -c "$(load_plugin); utm"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Usage: utm <command>"* ]]
}

@test "utm: --help succeeds" {
  run zsh -c "$(load_plugin); utm --help"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"snapshot <vm>"* ]]
}

@test "utm: rejects an unknown command" {
  run zsh -c "$(load_plugin); utm bogus"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Unknown command: bogus"* ]]
}

@test "utm start: requires a vm" {
  run zsh -c "$(load_plugin); utm start"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Missing required argument: vm"* ]]
}

@test "utm start: starts the vm by name" {
  run zsh -c "$(load_plugin); utm start Ubuntu"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"start vm"* ]]
  [[ "$output" != *"without saving"* ]]
  [[ "$output" == *"args: name Ubuntu"* ]]
}

@test "utm start: --disposable starts without saving" {
  run zsh -c "$(load_plugin); utm start Ubuntu --disposable"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"start vm without saving"* ]]
}

@test "utm start: selects by id for a UUID" {
  run zsh -c "$(load_plugin); utm start 5D419106-2824-4FED-BFE1-24A7F7E253D8"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"args: id 5D419106-2824-4FED-BFE1-24A7F7E253D8"* ]]
}

@test "utm start: passes names with quotes through argv, not the script" {
  run zsh -c "$(load_plugin); utm start 'My \"VM\"'"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *'args: name My "VM"'* ]]
}

@test "utm start: --wait returns once the vm reports started" {
  run zsh -c "$(load_plugin); STUB_QUIET=1 utm start Ubuntu --wait"

  [[ "$status" -eq 0 ]]
}

@test "utm stop: requests a shutdown by default" {
  run zsh -c "$(load_plugin); utm stop Ubuntu"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"stop vm"* ]]
  [[ "$output" != *"by force"* ]]
}

@test "utm stop: --force" {
  run zsh -c "$(load_plugin); utm stop Ubuntu -f"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"stop vm by force"* ]]
}

@test "utm stop: --kill" {
  run zsh -c "$(load_plugin); utm stop Ubuntu --kill"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"stop vm by kill"* ]]
}

@test "utm stop: --suspend saves state" {
  run zsh -c "$(load_plugin); utm stop Ubuntu -s"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"suspend vm with saving"* ]]
}

@test "utm stop: --wait times out while the vm keeps running" {
  run zsh -c "$(load_plugin); ZSH_UTM_TIMEOUT=1 STUB_QUIET=1; utm stop Ubuntu --wait"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Timed out"* ]]
}

@test "utm status: prints the status of a vm" {
  run zsh -c "$(load_plugin); utm status Ubuntu"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"status of vm"* ]]
  [[ "${lines[-1]}" == "started" ]]
}

@test "utm status: lists every vm without an argument" {
  run zsh -c "$(load_plugin); utm status"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"repeat with vm in virtual machines"* ]]
}

@test "utm snapshot: lists snapshots by default" {
  run zsh -c "$(load_plugin); utm snapshot Ubuntu"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"name of every snapshot of vm"* ]]
}

@test "utm snapshot: create passes the snapshot name as an argument" {
  run zsh -c "$(load_plugin); utm snapshot Ubuntu create clean"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"create snapshot vm named (item 3 of argv)"* ]]
  [[ "$output" == *"args: name Ubuntu clean"* ]]
}

@test "utm snapshot: restore passes the snapshot name as an argument" {
  run zsh -c "$(load_plugin); utm snapshot Ubuntu restore clean"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"restore (first snapshot of vm whose name is (item 3 of argv))"* ]]
  [[ "$output" == *"args: name Ubuntu clean"* ]]
}

@test "utm snapshot: create requires a name" {
  run zsh -c "$(load_plugin); utm snapshot Ubuntu create"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Missing required argument: snapshot name"* ]]
}

@test "utm snapshot: rejects an unknown action" {
  run zsh -c "$(load_plugin); utm snapshot Ubuntu delete clean"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Unknown snapshot action: delete"* ]]
}

@test "utm: reports osascript failures" {
  run zsh -c "
    gum() { shift 3; print -r -u2 -- \"\$*\"; }
    osascript() { print -r -u2 -- 'UTM got an error: Invalid index. (-1719)'; return 1; }
    source \"\$PLUGIN_DIR/zsh-utm.plugin.zsh\"
    utm start Nope
  "

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Invalid index"* ]]
}
