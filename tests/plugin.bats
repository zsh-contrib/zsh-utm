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

# Loads the plugin with gum and utmctl stubbed, see tests/stubs.zsh
load_plugin() {
  echo "
    source \"\$PLUGIN_DIR/tests/stubs.zsh\"
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

@test "utm list: prints name and status, names may contain spaces" {
  run zsh -c "$(load_plugin); utm list"

  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == $'Ubuntu\tstarted' ]]
  [[ "${lines[1]}" == $'Linux 2\tstopped' ]]
}

@test "utm start: requires a vm" {
  run zsh -c "$(load_plugin); utm start"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Missing required argument: vm"* ]]
}

@test "utm start: starts the vm" {
  run zsh -c "$(load_plugin); utm start Ubuntu"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"utmctl start Ubuntu"* ]]
  [[ "$output" != *"--disposable"* ]]
}

@test "utm start: --disposable starts without saving" {
  run zsh -c "$(load_plugin); utm start Ubuntu --disposable"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"utmctl start Ubuntu --disposable"* ]]
}

@test "utm start: passes a UUID through" {
  run zsh -c "$(load_plugin); utm start 5D419106-2824-4FED-BFE1-24A7F7E253D8"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"utmctl start 5D419106-2824-4FED-BFE1-24A7F7E253D8"* ]]
}

@test "utm start: keeps a name with quotes and spaces as one argument" {
  run zsh -c "$(load_plugin)
    utmctl() { print -r -- \"argc: \$#\"; print -r -- \"\$2\"; }
    utm start 'My \"VM\" 2'"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *'argc: 2'* ]]
  [[ "$output" == *'My "VM" 2'* ]]
}

@test "utm start: --wait returns once the vm reports started" {
  run zsh -c "$(load_plugin); utm start Ubuntu --wait"

  [[ "$status" -eq 0 ]]
}

@test "utm stop: requests a shutdown by default" {
  run zsh -c "$(load_plugin); utm stop Ubuntu"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"utmctl stop Ubuntu --request"* ]]
}

@test "utm stop: --force" {
  run zsh -c "$(load_plugin); utm stop Ubuntu -f"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"utmctl stop Ubuntu --force"* ]]
}

@test "utm stop: --kill" {
  run zsh -c "$(load_plugin); utm stop Ubuntu --kill"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"utmctl stop Ubuntu --kill"* ]]
}

@test "utm stop: --suspend saves state" {
  run zsh -c "$(load_plugin); utm stop Ubuntu -s"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"utmctl suspend Ubuntu --save-state"* ]]
}

@test "utm stop: --wait times out while the vm keeps running" {
  run zsh -c "$(load_plugin); ZSH_UTM_TIMEOUT=1; utm stop Ubuntu --wait"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Timed out"* ]]
}

@test "utm stop: --wait returns once the vm has stopped" {
  run zsh -c "$(load_plugin); STUB_STATUS=stopped; utm stop Ubuntu --wait"

  [[ "$status" -eq 0 ]]
}

@test "utm status: prints the status of a vm" {
  run zsh -c "$(load_plugin); utm status Ubuntu"

  [[ "$status" -eq 0 ]]
  [[ "$output" == "started" ]]
}

@test "utm status: lists every vm without an argument" {
  run zsh -c "$(load_plugin); utm status"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *$'Ubuntu\tstarted'* ]]
}

@test "utm snapshot: lists snapshot names by default" {
  run zsh -c "$(load_plugin); utm snapshot Ubuntu"

  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "second" ]]
  [[ "${lines[1]}" == "first" ]]
  [[ "$output" != *"disks only"* ]]
}

@test "utm snapshot: create passes the snapshot name" {
  run zsh -c "$(load_plugin); utm snapshot Ubuntu create clean"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Snapshot 'clean' created on 'Ubuntu'"* ]]
}

@test "utm snapshot: each action calls the matching utmctl command" {
  log="$BATS_TEST_TMPDIR/utmctl.log"

  run zsh -c "$(load_plugin); export STUB_LOG='$log'
    for action in create restore overwrite delete; do utm snapshot Ubuntu \$action clean; done
    utm snapshot Ubuntu rename clean fresh"

  [[ "$status" -eq 0 ]]
  run cat "$log"
  [[ "${lines[0]}" == "utmctl snapshot create Ubuntu --name clean" ]]
  [[ "${lines[1]}" == "utmctl snapshot restore Ubuntu --snapshot clean" ]]
  [[ "${lines[2]}" == "utmctl snapshot overwrite Ubuntu --snapshot clean" ]]
  [[ "${lines[3]}" == "utmctl snapshot delete Ubuntu --snapshot clean" ]]
  [[ "${lines[4]}" == "utmctl snapshot rename Ubuntu --snapshot clean --to fresh" ]]
}

@test "utm snapshot: requires a name" {
  for action in create restore overwrite delete; do
    run zsh -c "$(load_plugin); utm snapshot Ubuntu $action"

    [[ "$status" -eq 1 ]]
    [[ "$output" == *"Missing required argument: snapshot name"* ]]
  done
}

@test "utm snapshot: rename needs both names" {
  run zsh -c "$(load_plugin); utm snapshot Ubuntu rename clean"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Missing required argument: snapshot name and new name"* ]]
}

@test "utm snapshot: rejects an unknown action" {
  run zsh -c "$(load_plugin); utm snapshot Ubuntu bogus clean"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Unknown snapshot action: bogus"* ]]
}

@test "utm: reports utmctl failures" {
  run zsh -c "$(load_plugin)
    utmctl() { print -r -u2 -- 'Error: Virtual machine not found.'; return 1; }
    utm start Nope"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Virtual machine not found"* ]]
}
