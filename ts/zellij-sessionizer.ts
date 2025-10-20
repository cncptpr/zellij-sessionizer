#!/usr/bin/env bun

import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';

const ANSI_RESET = "\x1B[0m"
const ANSI_RED = "\x1B[31m"
const ANSI_GREEN = "\x1B[32m"
const ANSI_YELLOW = "\x1B[33m"

const a = JSON.parse('{"hello": "world"}');
const b = {hello: "world"};

type Path = string;

const WARN_DIR_NOT_FOUND_MESSAGE = (dir: Path) =>
  `Warning: Directory not found: ${dir}`;
enum ErrorType {
  NESTED_ZELLIJ_NOT_ALLOWED = "Zellij environment detected! Script only works outside of Zellij. Unset ZELLIJ env var to force this script to work.",
  NO_PATH_SPECIFIED = "No paths were specified, usage: ./zellij-sessionizer path1 path2 etc...",
  // DIR_NOT_FOUND = (ctx: Path) => `Warning: Directory not found: ${ctx}`,
  NO_VALID_DIRS = "No valid directories found to choose from.",
  FZF_EXECUTION_FAILED = "Error: Failed to execute fzf",
}

function isDirectory(dirPath: Path): boolean {
  return fs.existsSync(dirPath) && fs.lstatSync(dirPath).isDirectory();
}

function appendPath(list: Path[], dirPath: Path): boolean {
  if (isDirectory(dirPath)) {
    list.push(dirPath);
    return true;
  }
  return false;
}

function appendAllPaths(list: Path[], dirPath: Path): boolean {
  if (!dirPath.endsWith('/*')) {
    return appendPath(list, dirPath);
  }

  const basePath = dirPath.slice(0, -2);
  if (!isDirectory(basePath)) {
    console.log(`Warning: Directory not found: ${dirPath}`);
  }

  const entries = fs.readdirSync(basePath);
  for (const entry of entries) {
    appendPath(list, path.join(basePath, entry));
  }
  return true;
}

function fzf(list: Path[]): Path | undefined {
  const fzfInput = list.join('\n');
  try {
    const selectedPath = execSync(`printf '%s\\n' '${fzfInput}' | fzf`).toString().trim();
    return selectedPath || undefined;
  } catch {
    console.log("Error: Failed to execute fzf");
    return;
  }
}


function main(paths: Path[]): number | undefined {
  // if (process.env.ZELLIJ !== undefined) {
  //   console.log(`
  //     ${ANSI_RED}Zellij environment detected!${ANSI_RESET}
  //     Script only works outside of Zellij.
  
  //     This is because nested Zellij sessions are not recommended,
  //     and it is currently not possible to change Zellij sessions
  //     from within a script.
  
  //     Exit Zellij and try again,
  //     or unset ${ANSI_GREEN}ZELLIJ${ANSI_RESET} env var to force this script to work.
  //   `);
  //   return 1;
  // }

  if (paths.length === 0) {
    console.log("No paths were specified, usage: ./zellij-sessionizer path1 path2/* etc...");
    return 1;
  }

  const candidates: Path[] = [];
  for (const dirPath of paths) {
    if (!appendAllPaths(candidates, dirPath)) {
      console.log(`Warning: Directory not found: ${dirPath}`);
    }
  }

  if (candidates.length === 0) {
    console.log("No valid directories found to choose from.")
    return;
  }

  const selectedPath = fzf(candidates);
  if (!selectedPath) {
    // If nothing was picked, silently exit
    return;
  }

  const sessionName = path.basename(selectedPath).replace('.', '_');
  process.chdir(selectedPath)
  execSync(`zellij attach "${sessionName}" -c`);
}

const code = main(process.argv.slice(2))
process.exit(code);



