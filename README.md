# Zellij Sessionizer

Inspired by the Primeagen's 'tmux sessionizer', this script/program lets you pick from some preconfigured directories, and opens a Zellij session unique to the directory.

The bash script `zellij-sessionizer.sh` was originally taken from some Github Gist, and then modified to show less directories and not open new panes when inside Zellij.

By now this has turned into some sort of language playground, with the script reimplemented (mostly by ai) in lua, c, zig, rust, ts and gleam.

The c version is imo the best one, being noticeably faster than the bash one, while still being setupable (is that a word?) with tools installed on any linux (gcc).

In generall, I link the version that I am currently using into `~/.local/bin` (don't forget to add to PATH) or `/usr/bin/` (sudo required), or bring it into PATH any other way you like.
Then I add an alias to my config, that has my directories configured.

## Versions

Quick summary for the versions:

## Bash

Works great, just a bit slow and the code is... well, bash.

## Lua

Works great, and I kinda like lua. This was also the first reimplementation.
But lua needs a library for file system operations, wich needs to be installed over lua rocks.
I couldn't figure out how environments work, so I just installed it gloably, python style.

### Setup

1. Install `luac`
1. Install `luarocks`
1. `$ luarocks install luafilesystem` to install `luafilesystem`

## C

Didn't wanna install everything lua, while setting up zellij sessionizer on a new machine, so I reimplemented it in c.
Went relatively painless, though [`nob.h`](https://github.com/tsoding/nob.h) helped a lot with string operations. I use it as a 'buildsystem', though it's main usage was in the actual program.

### Compile

1. `$ gcc -o nob nob.c` once for bootstapping
1. `$ ./nob` to (re)compile

## Zig

At this point I just wanted to try out more languages.

Zig was exeptionally painfull:
AI is not very good at it, so the generated version had a lot of errors.
Of all the errors, zls showed me two. After those were fixed, it said it was fine.
The rest of the dozens of errors where given to me **one by one** by the zig compiler. (Why can't it show more?)
While the compiler is not slow, it also isn't fast enough that recompiling dozens of times wouldn't take it sweet time. And zig was often not helpfull in figuring out what the errors were.
The fixing of the generated version took multiple hours, and was my far the most time I put into any of those programs. And I don't even like the code more than c's.

Waste of time, but works.

Compile like you would any other zig program with `$ zig build`

## Rust

After zig I was a bit worried, until AI wrote code that almost just worked.
To the two or so errors, rustc just told me the solution.

Quickes one to write, slowest one to compile. 10/10
And apparently not in the repo? Where did it go? I'll find it somewhere.

## Ts and Gleam

I like ts for writing scripts, and gleam is my favorite language.
The ts version was quick to write (or let write).
For gleam, the AI didn't even get the syntax right to a point where the highlighter recognised it...
But, while manually, also quick to write.

Sadly both versions have a problem: They don't work.
Thier runtimes (node.js or bun, and beam) apparently can't setup a terminal environment correctly.

With node.js and bun, zellij complains that the terminal was not suitable (ENOTTY, not a tty, or something). I tried a lot of the different options and ways on how to start another process, but it just doesn't work. fzf works fine, so it probably is a missconfiguration on node/buns part, and a lot of checks on zellij's part. The capabillity of running an interactive tui are obviously there.

With gleam I need a libary to run other processes (and for the fs), and neither fzf nor zellij want to run.
To run `$ bun zellij-sessionizer.ts` and `$ gleam run` accordingly.
The package.json for ts are just the node types for the lsp, no dependencies.

## Ocaml

Not yet written.

## Python

God, I hate python. Not coming.

# TODO:

For some reason I though I needed to do globbing myself. Turns out the shell does it for you. So...

|       | globbing | verbose |
|  -    | -        | -       |
| bash  | x        | -       |
| lua   | -        | -       |
| c     | x        | x       |
| zig   | -        | -       |
| rust  | -        | -       |
| ts    | -        | -       |
| gleam | -        | -       |
