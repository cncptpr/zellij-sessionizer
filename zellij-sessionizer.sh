#!/usr/bin/env bash

# What ungodly thing is [[ "${ZELLIJ+x}" ]];?
if [[ "${ZELLIJ+x}" ]]; then
    echo "Zellij environment detected!"
    echo "Script only works outside of Zellij."
    echo ""
    echo "This is because nested Zellij sessions are not recommended,"
    echo "and it is currently not possible to change Zellij sessions"
    echo "from within a script."
    echo ""
    echo "Exit Zellij and try again,"
    echo "or unset ZELLIJ env var to force this script to work."
    exit 1
fi

# Why are arrays so weird in bash!?!
# Why does nix force me to care about this!?!
declare -a paths_input
paths_input=("$@")

if [[ ${#paths_input[@]} -eq 0 ]]; then
  echo "No paths were specified, usage: ./zellij-sessionizer path1 path2 etc.."
  exit 0
fi

declare -a candidates

# Process each input path
for p in "${paths_input[@]}"; do
  # Remove trailing slash
  p_normalized="${p%/}"
  if [ -d "$p_normalized" ]; then
    candidates+=( "$p_normalized" )
  else
    echo "Warning: Not a directory: $p_normalized" >&2
  fi
done

# If no valid directories were found after processing, exit
if [[ ${#candidates[@]} -eq 0 ]]; then
  echo "No valid directories found to choose from."
  exit 0
fi

# Use fzf to select a path from the collected candidates
selected_path=$(printf "%s\n" "${candidates[@]}" | fzf)

# If nothing was picked, silently exit
if [[ -z $selected_path ]]; then
  exit 0
fi

# Get the name of the selected directory, replacing "." with "_"
session_name=$(basename "$selected_path" | tr . _)

cd "$selected_path" || exit 1 # Exit if cd fails

# -c will make zellij to either create a new session or to attach into an existing one
zellij attach "$session_name" -c
exit 0
