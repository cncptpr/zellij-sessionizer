const std = @import("std");
const fs = std.fs;
const process = std.process;
const mem = std.mem;

// ANSI colour codes
const ANSI_RESET = "\x1B[0m";
const ANSI_RED = "\x1B[31m";
const ANSI_GREEN = "\x1B[32m";
const ANSI_YELLOW = "\x1B[33m";

fn isDir(path: []const u8) bool {
    var stat = std.fs.File.Stat{};
    const result = std.fs.cwd().statFile(path, &stat);
    return result == .Success and stat.kind == .Directory;
}

// Append a single directory path to the list if it exists
fn appendPath(allocator: *std.mem.Allocator, list: *std.ArrayList([]const u8), path: []const u8) !bool {
    if (isDir(path)) {
        try list.append(try allocator.dupe(u8, path));
        try list.append("\n");
        return true;
    }
    return false;
}

// Expand a pattern ending with "/*" and add all entries inside the directory
fn appendAllPaths(allocator: *std.mem.Allocator, list: *std.ArrayList([]const u8), path: []const u8) !bool {
    const suffix = "/*";
    if (!mem.endsWith(u8, path, suffix)) {
        // Not a glob – just treat it as a normal path
        return try appendPath(allocator, list, path);
    }

    const base_len = path.len - suffix.len;
    const base_path = try allocator.dupe(u8, path[0..base_len]);

    if (!isDir(base_path)) {
        std.debug.print(ANSI_YELLOW ++ "Warning:" ++ ANSI_RESET ++ " Directory not found: {s}\n", .{base_path});
        allocator.free(base_path);
        return false;
    }

    const dir = try fs.cwd().openDir(base_path, .{ .iterate = true });
    defer dir.close();

    var it = try dir.iterate();
    while (try it.next()) |entry| {
        if (entry.name[0] == '.' and (mem.eql(u8, entry.name, ".") or mem.eql(u8, entry.name, ".."))) continue;

        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_path, entry.name });
        defer allocator.free(full_path);
        _ = try appendPath(allocator, list, full_path);
    }

    allocator.free(base_path);
    return true;
}

// Run fzf with the given list and capture the selected line
fn fzf(allocator: *std.mem.Allocator, list: []const u8, out_result: []u8) !bool {
    // Build the command: printf '%s\n' '<list>' | fzf
    const cmd = try std.fmt.allocPrint(allocator, "printf '%s\\n' '{s}' | fzf", .{list});
    defer allocator.free(cmd);

    var child = try process.Child.init(&.{ "sh", "-c", cmd }, allocator);
    defer child.deinit();

    child.stdout_behavior = .Pipe;
    try child.spawn();

    const stdout = child.stdout.?;
    const read = try stdout.readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(read);

    // fzf writes the selected line (without trailing newline)
    const trimmed = std.mem.trim(u8, read, "\r\n");
    if (trimmed.len == 0) return false;

    const copy_len = @min(trimmed.len, out_result.len - 1);
    std.mem.copy(u8, out_result[0..copy_len], trimmed[0..copy_len]);
    out_result[copy_len] = 0;

    const status = try child.wait();
    return status == .Exited and status.Exited == 0;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Detect Zellij environment
    if (std.os.getenv("ZELLIJ") != null) {
        std.debug.print(
            ANSI_RED ++ "Zellij environment detected!" ++ ANSI_RESET ++ "\n" ++
                "Script only works outside of Zellij.\n\n" ++
                "This is because nested Zellij sessions are not recommended,\n" ++
                "and it is currently not possible to change Zellij sessions\n" ++
                "from within a script.\n\n" ++
                "Exit Zellij and try again,\n" ++
                "or unset " ++ ANSI_GREEN ++ "ZELLIJ" ++ ANSI_RESET ++
                " env var to force this script to work.\n",
        );
        return error.ExitCode(1);
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("No paths were specified, usage: ./zellij-sessionizer path1 path2/* etc..\n", .{});
        return error.ExitCode(1);
    }

    var candidates = std.ArrayList([]const u8).init(allocator);
    defer {
        for (candidates.items) |s| allocator.free(s);
        candidates.deinit();
    }

    // Process each argument
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const ok = try appendAllPaths(allocator, &candidates, args[i]);
        if (!ok) {
            std.debug.print(ANSI_YELLOW ++ "Warning:" ++ ANSI_RESET ++ " Directory not found: {s}\n", .{args[i]});
        }
    }

    if (candidates.items.len == 0) {
        std.debug.print("No valid directories found to choose from.\n", .{});
        return error.ExitCode(1);
    }

    // Join candidates into a single string
    const list_str = try std.mem.concat(allocator, u8, candidates.items);
    defer allocator.free(list_str);

    var selected_path: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const ok = try fzf(allocator, list_str, &selected_path);
    if (!ok or selected_path[0] == 0) return;

    // Derive session name from selected path
    const sel = std.mem.sliceTo(&selected_path, 0);
    const file_name = std.mem.lastIndexOf(u8, sel, "/");
    var session_name: [std.fs.MAX_PATH_BYTES]u8 = undefined;

    if (file_name) |idx| {
        const name_start = idx + 1;
        const name = sel[name_start..];
        // replace '.' with '_' in place
        var tmp = try allocator.dupe(u8, name);
        defer allocator.free(tmp);
        for (tmp) |*c| {
            if (c.* == '.') c.* = '_';
        }
        std.mem.copy(u8, &session_name, tmp);
    } else {
        std.mem.copy(u8, &session_name, sel);
    }

    // Change directory to the selected path
    try std.fs.cwd().setCurrentDir(sel);

    // Run: zellij attach <session_name> -c
    var cmd = process.Child.init(&.{ "zellij", "attach", session_name[0..std.mem.len(session_name)], "-c" }, allocator);
    defer cmd.deinit();

    const run_ok = try cmd.spawn();
    if (!run_ok) {
        std.debug.print("Failed launch zellij-session.\n", .{});
        return error.ExitCode(1);
    }

    // Wait for zellij to exit (optional)
    _ = try cmd.wait();
}
