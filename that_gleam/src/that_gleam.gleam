import argv
import envoy
import gleam/bool
import gleam/int
import gleam/io.{println}
import gleam/list
import gleam/result
import gleam/string
import gleamyshell.{CommandOutput}
import simplifile

const ansi_reset = "\u{001b}[0m"

const ansi_red = "\u{001b}[31m"

const ansi_green = "\u{001b}[32m"

pub fn is_dir(path: String) -> Bool {
  simplifile.is_directory(path) |> result.unwrap(False)
}

fn quote_shell(s: String) -> String {
  let escaped = string.replace(s, "'", "'\\''")
  "'" <> escaped <> "'"
}

pub fn expand_path(path: String) -> List(String) {
  case string.ends_with(path, "/*") {
    True -> {
      let base = string.slice(path, 0, string.length(path) - 2)
      case is_dir(base) {
        False -> {
          println("Warning: Directory not found: " <> base)
          []
        }
        True -> {
          case simplifile.read_directory(base) {
            Error(_) -> []
            Ok(dirs) -> {
              dirs
              |> list.filter(fn(e) { e != "" })
              |> list.map(fn(e) { base <> "/" <> e })
              |> list.filter(fn(p) { is_dir(p) })
            }
          }
        }
      }
    }
    False -> {
      case is_dir(path) {
        True -> [path]
        False -> {
          println("Warning: Directory not found: " <> path)
          []
        }
      }
    }
  }
}

fn basename(path: String) -> String {
  let assert Ok(name) =
    path
    |> string.split(on: "/")
    |> list.reverse
    |> list.filter(fn(seg) { seg != "" })
    |> list.first()
  name
}

fn sanitize_session_name(name: String) -> String {
  string.replace(name, ".", "_")
}

pub fn main() {
  let args = argv.load().arguments
  // use <- bool.lazy_guard(envoy.get("ZELLIJ") |> result.is_ok(), fn() {
  //   println(
  //     ansi_red
  //     <> "Zellij environment detected!"
  //     <> ansi_reset
  //     <> "\nScript only works outside of Zellij.\n\nThis is because nested Zellij sessions are not recommended,\nand it is currently not possible to change Zellij sessions\nfrom within a script.\n\nExit Zellij and try again,\nor unset "
  //     <> ansi_green
  //     <> "ZELLIJ"
  //     <> ansi_reset
  //     <> " env var to force this script to work.\n",
  //   )
  // })

  use <- bool.lazy_guard(list.is_empty(args), fn() {
    println(
      "No paths were specified, usage: ./zellij-sessionizer path1 path2/* etc..",
    )
  })

  let candidates = concat_map(args, expand_path)

  use <- bool.lazy_guard(list.is_empty(candidates), fn() {
    println("No valid directories found to choose from.")
  })
  let data = string.join(candidates, "\n")
  let cmd = "printf '%s\\n' " <> quote_shell(data) <> " | fzf"
  let chosen = gleamyshell.execute("bash", in: ".", args: ["-c", cmd])
  case chosen {
    Ok(CommandOutput(0, chosen)) -> {
      let chosen = string.trim(chosen)
      use <- bool.guard(string.is_empty(chosen), Nil)
      let name = sanitize_session_name(basename(chosen))

      let _ =
        gleamyshell.execute("zellij", in: chosen, args: [
          quote_shell(name),
          "-c",
        ])
      Nil
    }
    Ok(CommandOutput(exit_code, out)) -> {
      println("Fzf failed with " <> int.to_string(exit_code) <> ": " <> out)
    }
    Error(msg) -> println("Failed to run fzf: " <> msg)
  }

  Nil
}

fn concat_map(xs: List(String), f: fn(String) -> List(String)) -> List(String) {
  case xs {
    [] -> []
    [head, ..tail] -> list.append(f(head), concat_map(tail, f))
  }
}
