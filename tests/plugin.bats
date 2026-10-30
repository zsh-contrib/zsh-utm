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

# Prepares what utm create needs in the test directory: an ISO, a directory to share and the
# bundle UTM would have made for the virtual machine called $1.
prepare_create() {
  export ZSH_UTM_DOCUMENTS="$BATS_TEST_TMPDIR/documents"
  mkdir -p "$ZSH_UTM_DOCUMENTS/$1.utm/Data" "$BATS_TEST_TMPDIR/repo"
  : > "$BATS_TEST_TMPDIR/installer.iso"
  export LOG="$BATS_TEST_TMPDIR/calls.log"
  : > "$LOG"
}

@test "utm create: requires a spec" {
  run zsh -c "$(load_plugin); utm create"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Missing required argument: spec"* ]]
}

@test "utm create: fails when the spec does not exist" {
  run zsh -c "$(load_plugin); utm create '$BATS_TEST_TMPDIR/missing.toml'"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Spec not found"* ]]
}

@test "utm create: needs a name" {
  echo 'memory = 4096' > "$BATS_TEST_TMPDIR/vm.toml"

  run zsh -c "$(load_plugin); utm create '$BATS_TEST_TMPDIR/vm.toml'"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"The spec needs a name"* ]]
}

@test "utm create: rejects a backend other than qemu" {
  printf 'name = "vm"\nbackend = "apple"\n' > "$BATS_TEST_TMPDIR/vm.toml"

  run zsh -c "$(load_plugin); utm create '$BATS_TEST_TMPDIR/vm.toml'"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Unsupported backend: apple"* ]]
}

@test "utm create: rejects an unknown network mode" {
  printf 'name = "vm"\n[network]\nmode = "bridged"\n' > "$BATS_TEST_TMPDIR/vm.toml"

  run zsh -c "$(load_plugin); utm create '$BATS_TEST_TMPDIR/vm.toml'"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Unsupported network mode: bridged"* ]]
}

@test "utm create: fails when the iso does not exist" {
  printf 'name = "vm"\niso = "nowhere.iso"\n' > "$BATS_TEST_TMPDIR/vm.toml"

  run zsh -c "$(load_plugin); utm create '$BATS_TEST_TMPDIR/vm.toml'"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"ISO not found"* ]]
}

@test "utm create: creates the vm and writes the rest of the spec into its config" {
  prepare_create nixos
  cat > "$BATS_TEST_TMPDIR/vm.toml" <<TOML
name = "nixos"
cpus = 4
memory = 4096
disk = 20480
iso = "installer.iso"
share = "repo"
clipboard = true
icon = "linux"

[network]
mode = "emulated"
forward = [{ host = 2222, guest = 22 }]

[plist]
"Virtualization.Rosetta" = true
"System.CPUCount" = 2
TOML

  run zsh -c "$(load_plugin); export STUB_LOG='$LOG'; utm create '$BATS_TEST_TMPDIR/vm.toml'"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Created 'nixos'"* ]]

  # The plugin resolves symlinks of the paths in the spec, /var is /private/var on macOS
  real="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
  plist="$ZSH_UTM_DOCUMENTS/nixos.utm/config.plist"
  run cat "$LOG"
  [[ "$output" == *"osascript create.applescript nixos $real/installer.iso 4 4096 20480 true"* ]]
  [[ "$output" == *"plutil -replace Drive.0.ImageName -string installer.iso $plist"* ]]
  [[ "$output" == *"plutil -replace Network.0.Mode -string Emulated $plist"* ]]
  [[ "$output" == *'plutil -replace Network.0.PortForward -json [{"Protocol":"TCP","GuestAddress":"","GuestPort":22,"HostAddress":"127.0.0.1","HostPort":2222}]'* ]]
  [[ "$output" == *"plutil -replace Sharing.ClipboardSharing -bool true $plist"* ]]
  [[ "$output" == *"plutil -replace Information.Icon -string linux $plist"* ]]
  [[ "$output" == *"plutil -replace Virtualization.Rosetta -json true $plist"* ]]
  [[ "$output" == *"plutil -replace System.CPUCount -json 2 $plist"* ]]
  [[ "${lines[-1]}" == "osascript apply.applescript nixos $real/repo" ]]
  [[ -f "$ZSH_UTM_DOCUMENTS/nixos.utm/Data/installer.iso" ]]
}

@test "utm create: falls back to defaults for a minimal spec" {
  prepare_create vm
  echo 'name = "vm"' > "$BATS_TEST_TMPDIR/vm.toml"

  run zsh -c "$(load_plugin); export STUB_LOG='$LOG'; utm create '$BATS_TEST_TMPDIR/vm.toml'"

  [[ "$status" -eq 0 ]]
  run cat "$LOG"
  [[ "$output" == *"osascript create.applescript vm  0 8192 81920 "* ]]
  [[ "$output" == *"plutil -replace Network.0.Mode -string Shared"* ]]
  [[ "$output" == *'"Hardware":"virtio-gpu-pci"'* ]]
  [[ "$output" != *"PortForward"* ]]
  [[ "$output" != *"ImageName"* ]]
  [[ "$output" != *"ClipboardSharing"* ]]
}

@test "utm create: refuses to replace an existing vm without --force" {
  prepare_create Ubuntu
  echo 'name = "Ubuntu"' > "$BATS_TEST_TMPDIR/vm.toml"

  run zsh -c "$(load_plugin); export STUB_LOG='$LOG'; utm create '$BATS_TEST_TMPDIR/vm.toml'"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Virtual machine already exists: Ubuntu"* ]]
  run cat "$LOG"
  [[ "$output" != *"create.applescript"* ]]
}

@test "utm create: --force deletes the existing vm first" {
  prepare_create Ubuntu
  echo 'name = "Ubuntu"' > "$BATS_TEST_TMPDIR/vm.toml"

  run zsh -c "$(load_plugin); export STUB_LOG='$LOG'; utm create '$BATS_TEST_TMPDIR/vm.toml' --force"

  [[ "$status" -eq 0 ]]
  run cat "$LOG"
  [[ "${lines[0]}" == "utmctl list" ]]
  [[ "${lines[1]}" == "utmctl delete Ubuntu" ]]
  [[ "${lines[2]}" == "osascript create.applescript Ubuntu"* ]]
}

@test "utm create: removes the vm again when writing its config fails" {
  prepare_create vm
  echo 'name = "vm"' > "$BATS_TEST_TMPDIR/vm.toml"

  run zsh -c "$(load_plugin); export STUB_LOG='$LOG' STUB_PLUTIL_FAIL=1; utm create '$BATS_TEST_TMPDIR/vm.toml'"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Could not finish 'vm', removing it"* ]]
  run cat "$LOG"
  [[ "$output" == *"utmctl delete vm"* ]]
}

@test "utm create: makes the dictionaries on the way to a key path of the plist" {
  prepare_create vm
  printf 'name = "vm"\n[plist]\n"Virtualization.Rosetta" = true\n' > "$BATS_TEST_TMPDIR/vm.toml"

  run zsh -c "$(load_plugin); export STUB_LOG='$LOG' STUB_PLUTIL_MISSING=1; utm create '$BATS_TEST_TMPDIR/vm.toml'"

  [[ "$status" -eq 0 ]]
  run cat "$LOG"
  [[ "$output" == *"plutil -type Virtualization "* ]]
  [[ "$output" == *"plutil -insert Virtualization -dictionary "* ]]
  [[ "$output" == *"plutil -replace Virtualization.Rosetta -json true "* ]]
}
