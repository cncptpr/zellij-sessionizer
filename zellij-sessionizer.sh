#!/usr/bin/env bash

paths_input=$@

if [[ -z $paths_input ]]; then
  echo "No paths were specified, usage: ./zellij-sessionizer path1 path2 etc.."
  exit 0
fi

declare -a candidates

# Process each input path
for p in $paths_input; do
  if [[ "$p" == */\* ]]; then
    # Path ends with /*, so we want to list subdirectories
    # Remove the '/*' suffix
    base_path="${p%/*}"
    if [ -d "$base_path" ]; then
      if [ -x "$(command -v fd)" ]; then
        # Using fd for subdirectories
        mapfile -t < <(fd . "$base_path" --min-depth 1 --max-depth 1 --type d)
      else
        # Using find for subdirectories
        mapfile -t < <(find "$base_path" -mindepth 1 -maxdepth 1 -type d)
      fi
      candidates+=( "${MAPFILE[@]}" )
    else
      echo "Warning: Directory not found: $base_path" >&2
    fi
  else
    # Path is a direct directory, add it if it exists and is a directory
    if [ -d "$p" ]; then
      candidates+=( "$p" )
    else
      echo "Warning: Directory not found: $p" >&2
	  fi
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

# We're outside of zellij, so let's create a new session or attach to a new one.
if [[ -z $ZELLIJ ]]; then
  cd "$selected_path" || exit 1 # Exit if cd fails
  # -c will make zellij to either create a new session or to attach into an existing one
  zellij attach "$session_name" -c
  exit 0
fi

# We're inside zellij so we'll open a new pane and move into the selected directory
zellij action new-pane

# Hopefully they'll someday support specifying a directory and this won't be as laggy
# thanks to @msirringhaus for getting this from the community some time ago!
zellij action write-chars "cd \"$selected_path\"" && zellij action write 10
