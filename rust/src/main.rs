use std::env;
use std::ffi::OsStr;
use std::fs;
use std::io::{self, BufRead, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

const ANSI_RESET: &str = "\x1B[0m";
const ANSI_RED: &str = "\x1B[31m";
const ANSI_GREEN: &str = "\x1B[32m";
const ANSI_YELLOW: &str = "\x1B[33m";

/// Return true if `p` points to an existing directory.
fn is_dir(p: &Path) -> bool {
    p.is_dir()
}

/// Append a single directory path to `list` if it exists.
fn append_path(list: &mut Vec<String>, p: &Path) -> bool {
    if is_dir(p) {
        list.push(p.to_string_lossy().into_owned());
        true
    } else {
        false
    }
}

/// Expand a path that may end with `/*`.  
/// If the suffix is present, all entries inside the base directory are added.  
/// Otherwise the path itself is added (if it is a directory).
fn append_all_paths(list: &mut Vec<String>, raw: &str) -> bool {
    if raw.ends_with("/*") {
        let base = &raw[..raw.len() - 2];
        let base_path = Path::new(base);
        if !is_dir(base_path) {
            eprintln!(
                "{}Warning:{} Directory not found: {}",
                ANSI_YELLOW, ANSI_RESET, base
            );
            return false;
        }

        match fs::read_dir(base_path) {
            Ok(entries) => {
                for entry in entries.filter_map(Result::ok) {
                    let path = entry.path();
                    if path.is_dir() {
                        list.push(path.to_string_lossy().into_owned());
                    }
                }
                true
            }
            Err(_) => false,
        }
    } else {
        append_path(list, Path::new(raw))
    }
}

/// Run `fzf` on the newline‑separated list and capture the selected line.
fn run_fzf(candidates: &[String]) -> io::Result<Option<String>> {
    // Build the command: `printf '%s\n' "$list" | fzf`
    let mut child = Command::new("fzf")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()?;

    {
        // Feed the candidates to fzf's stdin.
        let stdin = child.stdin.as_mut().unwrap();
        for line in candidates {
            writeln!(stdin, "{}", line)?;
        }
    }

    let output = child.wait_with_output()?;
    if !output.status.success() {
        return Ok(None);
    }

    let selected = String::from_utf8_lossy(&output.stdout)
        .lines()
        .next()
        .map(|s| s.to_string());

    Ok(selected)
}

/// Convert a filesystem path into a Zellij‑compatible session name:
/// – use the final component,
/// – replace `.` with `_`.
fn session_name_from_path(p: &Path) -> String {
    let name = p.file_name().and_then(OsStr::to_str).unwrap();

    name.replace('.', "_")
}

fn main() -> io::Result<()> {
    // Detect Zellij environment variable.
    if env::var_os("ZELLIJ").is_some() {
        eprintln!(
            "{}Zellij environment detected!{}\
            \nScript only works outside of Zellij.\n\
            \nThis is because nested Zellij sessions are not recommended,\
            \nand it is currently not possible to change Zellij sessions\
            \nfrom within a script.\n\
            \nExit Zellij and try again,\
            \nor unset {}ZELLIJ{} env var to force this script to work.",
            ANSI_RED, ANSI_RESET, ANSI_GREEN, ANSI_RESET
        );
        std::process::exit(1);
    }

    // Expect at least one path argument.
    let args: Vec<String> = env::args().skip(1).collect();
    if args.is_empty() {
        eprintln!("No paths were specified, usage: ./zellij-sessionizer path1 path2/* etc..");
        std::process::exit(1);
    }

    // Build the candidate list.
    let mut candidates = Vec::new();
    for arg in args {
        if !append_all_paths(&mut candidates, &arg) {
            eprintln!(
                "{}Warning:{} Directory not found: {}",
                ANSI_YELLOW, ANSI_RESET, arg
            );
        }
    }

    if candidates.is_empty() {
        eprintln!("No valid directories found to choose from.");
        std::process::exit(1);
    }

    // Let the user pick a directory via fzf.
    let selected = match run_fzf(&candidates)? {
        Some(s) if !s.is_empty() => s,
        _ => return Ok(()), // user cancelled or fzf failed
    };
    let selected_path = PathBuf::from(selected);

    // Derive the session name.
    let session_name = session_name_from_path(&selected_path);

    // Change to the selected directory.
    env::set_current_dir(&selected_path)?;

    // Execute `zellij attach <session_name> -c`
    let status = Command::new("zellij")
        .arg("attach")
        .arg(&session_name)
        .arg("-c")
        .status()?;

    if !status.success() {
        eprintln!("Failed to launch zellij session.");
        std::process::exit(1);
    }

    Ok(())
}
