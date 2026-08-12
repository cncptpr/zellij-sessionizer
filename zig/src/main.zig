const std = @import("std");

const ZSErrors = error{ ZELLIJ_ENVIRONMENT_DETECTED, NO_PATHS_SPECIFIED, DIR_NOT_FOUND, NO_VALIDE_DIR_FOUND, ZELLIJ_LAUNCH_FAILED, FZF_NO_OUTPUT, FZF_FAILED_TO_EXECUTE };

const ANSI_RESET = "\x1B[0m";
const ANSI_RED = "\x1B[31m";
const ANSI_GREEN = "\x1B[32m";
const ANSI_YELLOW = "\x1B[33m";

// TODO: Maybe `isDir` is the wrong name. Something like `shouldAppendPath` might be better.
fn isDir(path: []const u8) bool {
    const result = std.fs.cwd().statFile(path) catch return false;
    return result.kind == .directory;
}

fn appendPath(gpa: std.mem.Allocator, list: *std.ArrayList([]const u8), path: []const u8) !void {
    if (isDir(path)) {
        try list.append(gpa, path);
    }
}

fn appendAllPaths(gpa: std.mem.Allocator, list: *std.ArrayList([]const u8), path: []const u8) !void {
    const suffix = "/*";
    if (!std.mem.endsWith(u8, path, suffix)) {
        // Not a glob – just treat it as a normal path
        return try appendPath(gpa, list, path);
    }

    const base_len = path.len - suffix.len;

    const base_path = try gpa.dupe(u8, path[0..base_len]);
    defer gpa.free(base_path);

    if (!isDir(base_path)) {
        std.debug.print(ANSI_YELLOW ++ "Warning:" ++ ANSI_RESET ++ " Directory not found: {s}\n", .{base_path});
        return ZSErrors.DIR_NOT_FOUND;
    }

    var dir = try std.fs.cwd().openDir(base_path, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.name[0] == '.' and (std.mem.eql(u8, entry.name, ".") or std.mem.eql(u8, entry.name, ".."))) continue;

        const full_path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ base_path, entry.name });
        _ = try appendPath(gpa, list, full_path);
    }
}

fn fzf(gpa: std.mem.Allocator, paths: *std.ArrayList([]const u8)) ![]const u8 {
    const paths_joined = try std.mem.join(gpa, "\n", paths.items);
    defer gpa.free(paths_joined);

    const cmd = try std.fmt.allocPrint(gpa, "printf '%s\\n' '{s}' | fzf", .{paths_joined});
    defer gpa.free(cmd);

    var child = std.process.Child.init(&.{ "sh", "-c", cmd }, gpa);

    child.stdout_behavior = .Pipe;
    try child.spawn();

    const stdout = child.stdout.?;
    const read = try stdout.readToEndAlloc(gpa, std.math.maxInt(usize));
    errdefer gpa.free(read);

    const trimmed = std.mem.trim(u8, read, "\r\n");
    if (trimmed.len == 0) return ZSErrors.FZF_NO_OUTPUT;

    const status = try child.wait();
    std.debug.print("{}", .{status});
    if (status == .Exited and status.Exited != 0)
        return ZSErrors.FZF_FAILED_TO_EXECUTE;
    return trimmed;
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    if (std.process.getEnvVarOwned(gpa, "ZELLIJ")) |_| {
        std.debug.print(ANSI_RED ++ "Zellij environment detected!" ++ ANSI_RESET ++ "\n" ++
            "Script only works outside of Zellij.\n\n" ++
            "This is because nested Zellij sessions are not recommended,\n" ++
            "and it is currently not possible to change Zellij sessions\n" ++
            "from within a script.\n\n" ++
            "Exit Zellij and try again,\n" ++
            "or unset " ++ ANSI_GREEN ++ "ZELLIJ" ++ ANSI_RESET ++
            " env var to force this script to work.\n", .{});
        return ZSErrors.ZELLIJ_ENVIRONMENT_DETECTED;
    } else |err| if (err != std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound) {
        return err;
    }

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    if (args.len < 2) {
        std.debug.print("No paths were specified, usage: ./zellij-sessionizer path1 path2/* etc..\n", .{});
        return ZSErrors.NO_PATHS_SPECIFIED;
    }

    var candidates = std.ArrayList([]const u8).empty;
    defer {
        for (candidates.items) |s| gpa.free(s);
        candidates.deinit(gpa);
    }

    for (args) |arg| {
        appendAllPaths(gpa, &candidates, arg) catch
            std.debug.print(ANSI_YELLOW ++ "Warning:" ++ ANSI_RESET ++ " Directory not found: {s}\n", .{arg});
    }

    if (candidates.items.len == 0) {
        std.debug.print("No valid directories found to choose from.\n", .{});
        return ZSErrors.NO_VALIDE_DIR_FOUND;
    }

    const result = try fzf(gpa, &candidates);
    defer gpa.free(result);
    if (!std.unicode.utf8ValidateSlice(result)) {
        std.debug.print("result: invalide utf-8!!!!\n", .{});
        return;
    }

    // Derive session name from selected path
    const file_name = std.fs.path.basename(result);

    // Run: zellij attach <session_name> -c
    if (!std.unicode.utf8ValidateSlice(file_name)) {
        std.debug.print("file_name: invalide utf-8!!!!\n", .{});
        return;
    }

    std.debug.print("{s}\n", .{file_name});
    var cmd = std.process.Child.init(&.{ "zellij", "attach", file_name, "-c" }, gpa);
    cmd.cwd = result;

    cmd.spawn() catch {
        std.debug.print("Failed launch zellij-session.\n", .{});
        return ZSErrors.ZELLIJ_LAUNCH_FAILED;
    };

    // Wait for zellij to exit (optional)
    _ = try cmd.wait();
}
