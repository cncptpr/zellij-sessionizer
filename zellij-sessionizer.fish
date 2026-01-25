#!/usr/bin/env fish

# This script helps manage Zellij sessions based on project directories.

if set -q ZELLIJ
    set_color red
    echo "Zellij environment detected!"
    set_color normal
    echo "Script only works outside of Zellij."
    echo ""
    echo "This is because nested Zellij sessions are not recommended,"
    echo "and it is currently not possible to change Zellij sessions"
    echo "from within a script."
    echo ""
    echo "Exit Zellij and try again,"
    echo -n "or unset "
    set_color green
    echo -n ZELLIJ
    set_color normal
    echo " env var to force this script to work."
    exit 1
end

if test (count $argv) -eq 0
    echo "No paths were specified, usage: ./zellij-sessionizer.fish path1 path2 etc.."
    exit 0
end

set candidates
for p in $argv
    # Remove trailing slash
    set p_normalized (string trim -r -c / -- $p)
    if test -d "$p_normalized"
        set -a candidates "$p_normalized"
    else
        echo "Warning: Not a directory: $p_normalized" >&2
    end
end

if test (count $candidates) -eq 0
    echo "No valid directories found to choose from."
    exit 0
end

# Use fzf to select a path from the collected candidates
set selected_path (printf "%s\n" $candidates | fzf)

# If nothing was picked, silently exit
if test -z "$selected_path"
    exit 0
end

# Get the name of the selected directory, replacing "." with "_"
set session_name (basename "$selected_path" | string replace -r "\." "_")

cd "$selected_path" or exit 1

# -c will make zellij to either create a new session or to attach into an existing one
zellij attach "$session_name" -c
exit 0
