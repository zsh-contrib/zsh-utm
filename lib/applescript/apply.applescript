-- Reload the configuration written to the bundle and share a directory with the VM when given one.
-- Usage: osascript apply.applescript <name> <directory or "">
on run argv
  set vmName to item 1 of argv
  set vmDirectory to item 2 of argv

  -- A file object has to be made outside of the tell, inside it UTM would try to resolve it
  if vmDirectory is not "" then set vmDirectoryFile to POSIX file vmDirectory

  tell application "UTM"
    set vm to virtual machine named vmName
    reload configuration vm

    if vmDirectory is not "" then
      update registry vm with {vmDirectoryFile}
    end if
  end tell
end run
