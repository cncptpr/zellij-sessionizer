#!/usr/bin/env lua

local lfs = require("lfs")

---@alias path string Path to a file
---@alias error_type
---| "NESTED_ZELLIJ_NOT_ALLOWED"
---| "NO_PATH_SPECIFIED"
---| "DIR_NOT_FOUND"
---| "NO_VALIDE_DIRS"
---| "FZF_EXECUTION_FAILED"

local ANSI = {
  RESET = "\x1B[0m",
  RED = "\x1B[31m",
  GREEN = "\x1B[32m",
  YELLOW = "\x1B[33m",
}

---Prints error message of provided type
---This function feels horrible, but I wanted to try out the enum type alias :)
---@param type error_type
---@param ctx path?
local function error(type, ctx)
  if type == "NO_PATH_SPECIFIED" then
    print "No paths were specified, usage: ./zellij-sessionizer path1 path2 etc.."
  elseif type == "NESTED_ZELLIJ_NOT_ALLOWED" then
    print(ANSI.RED .. "Zellij environment detected!" .. ANSI.RESET)
    print("Script only works outside of Zellij.")
    print("")
    print("This is because nested Zellij sessions are not recommended,")
    print("and it is currently not possible to change Zellij sessions")
    print("from within a script.")
    print("")
    print("Unset " .. ANSI.GREEN .. "ZELLIJ" .. ANSI.RESET .. " env var to force this script to work.")
  elseif type == "DIR_NOT_FOUND" then
    print(ANSI.YELLOW .. "Warning:" .. ANSI.RESET .. " Directory not found: " .. ctx)
    return -- no error, just warning
  elseif type == "NO_VALIDE_DIRS" then
    print("No valid directories found to choose from.")
  elseif type == "FZF_EXECUTION_FAILED" then
    print(ANSI.RED .. "Error:" .. ANSI.RESET .. " Failed to execute fzf")
  end
  os.exit(1)
end

---Checks wether path is a dir
---@param path path
---@return boolean
local function is_dir(path)
  local attr = lfs.attributes(path)
  return attr and attr.mode == "directory"
end

---Append the dir to the path.
---Returns flase, if the path is not a dir.
---@param list table<path>
---@param path path
---@return boolean
local function append_path(list, path)
  if is_dir(path) then
    table.insert(list, path)
    return true
  end
  return false
end

--- Appends the dir or all subdirs (if path ends in "/*") to the list.
--- Returns false, if the path is not a dir.
--- @param list table<path>
--- @param path path
--- @return boolean
local function append_all_paths(list, path)
  if path:sub(-2) ~= "/*" then
    return append_path(list, path)
  end

  local base_path = path:sub(1, -3) -- Remove the '/*' suffix
  if not is_dir(base_path) then
    error("DIR_NOT_FOUND", base_path)
    return false
  end

  for dir in lfs.dir(base_path) do
    append_path(list, base_path .. "/" .. dir)
  end
  return true
end

---Uses fzf cli to promt user with entries from list
---@param list table<path>
---@return path selected entry
local function fzf(list)
  local fzf_input = table.concat(list, "\n")
  local fzf_handle = io.popen("printf '%s\\n' '" .. fzf_input .. "' | fzf")
      or error("FZF_EXECUTION_FAILED")
  local selected_path = fzf_handle:read("*l")
  fzf_handle:close()
  return selected_path
end

local function main(paths)
  if os.getenv("ZELLIJ") ~= nil then
    error "NESTED_ZELLIJ_NOT_ALLOWED"
  end

  if #paths == 0 then
    error "NO_PATH_SPECIFIED"
  end

  -- Collect all requested dirs and subdirs
  local candidates = {}
  for _, path in ipairs(paths) do
    if not append_all_paths(candidates, path) then
      error("DIR_NOT_FOUND", path)
    end
  end

  if #candidates == 0 then
    error "NO_VALIDE_DIRS"
  end

  local selected_path = fzf(candidates)
  if not selected_path or selected_path == "" then
    -- If nothing was picked, silently exit
    os.exit(0)
  end

  -- replacing "." in path with "_" for the session name
  local session_name = selected_path:match("([^/]+)$"):gsub("%.", "_")

  os.execute("cd " .. selected_path .. " && zellij attach " .. session_name .. " -c")
  os.exit(0)
end

main({ ... })
