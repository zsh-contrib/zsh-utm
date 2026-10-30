-- Create a QEMU VM that runs on the hypervisor, with an optional ISO as a removable drive and a
-- blank disk. utmctl cannot create a VM, so this is the one place that needs AppleScript.
-- Usage: osascript create.applescript <name> <iso or ""> <cpus> <memory MiB> <disk MiB> \
--   <share true|false>
on run argv
  set vmName to item 1 of argv
  set vmIso to item 2 of argv
  set vmCpus to item 3 of argv as integer
  set vmMemory to item 4 of argv as integer
  set vmDisk to item 5 of argv as integer
  set vmShare to (item 6 of argv) is "true"

  -- A file object has to be made outside of the tell, inside it UTM would try to resolve it
  if vmIso is not "" then set vmIsoFile to POSIX file vmIso

  tell application "UTM"
    if (count of (every virtual machine whose name is vmName)) > 0 then
      error "VM already exists: " & vmName
    end if

    if vmIso is "" then
      set vmDrives to {{guest size:vmDisk}}
    else
      set vmDrives to {{removable:true, source:vmIsoFile}, {guest size:vmDisk}}
    end if

    if vmShare then
      set vmShareMode to VirtFS
    else
      set vmShareMode to none
    end if

    make new virtual machine with properties ¬
      {backend:qemu, ¬
        configuration:{ ¬
          name:vmName, ¬
          architecture:"aarch64", ¬
          memory:vmMemory, ¬
          cpu cores:vmCpus, ¬
          hypervisor:true, ¬
          uefi:true, ¬
          directory share mode:vmShareMode, ¬
          drives:vmDrives}}
  end tell
end run
