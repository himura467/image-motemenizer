const std = @import("std");
const im = @import("image_motemenizer");

fn printUsage() !void {
    const stderr: std.fs.File = .stderr();
    try stderr.writeAll(
        \\Usage: image_motemenizer <input> <output> <blocks_width> <blocks_height> [color_space]
        \\
        \\Arguments:
        \\  input          Path to input image file
        \\  output         Path to output image file
        \\  blocks_width   Number of mosaic blocks horizontally
        \\  blocks_height  Number of mosaic blocks vertically
        \\  color_space    Color space for averaging: 'rgb' or 'oklab' (default: rgb)
        \\
        \\Example:
        \\  image_motemenizer input.jpg output.png 32 32 oklab
        \\
    );
}

pub fn main() !void {
    // Use C allocator since we're already linking libc for stb_image
    const allocator = std.heap.c_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 5) {
        try printUsage();
        std.process.exit(1);
    }

    const input_path = args[1];
    const output_path = args[2];
    const blocks_width = try std.fmt.parseInt(usize, args[3], 10);
    const blocks_height = try std.fmt.parseInt(usize, args[4], 10);

    var color_space: im.ColorSpace = .Rgb;
    if (args.len >= 6) {
        if (std.mem.eql(u8, args[5], "rgb")) {
            color_space = .Rgb;
        } else if (std.mem.eql(u8, args[5], "oklab")) {
            color_space = .Oklab;
        } else {
            std.debug.print("Invalid color space: {s}. Use 'rgb' or 'oklab'.\n", .{args[5]});
            std.process.exit(1);
        }
    }

    std.debug.print("Loading image from {s}...\n", .{input_path});

    // Add null terminator for C string
    const input_path_z = try allocator.dupeZ(u8, input_path);
    defer allocator.free(input_path_z);

    var img = im.Image.load(allocator, input_path_z) catch |err| {
        std.debug.print("Failed to load image: {any}\n", .{err});
        std.process.exit(1);
    };
    defer img.deinit();

    std.debug.print("Image loaded: {d}x{d}\n", .{ img.width, img.height });
    std.debug.print("Applying mosaic effect: {d}x{d} blocks, {s} color space...\n", .{
        blocks_width,
        blocks_height,
        @tagName(color_space),
    });

    const mosaic = im.Mosaic.init(blocks_width, blocks_height, color_space);

    var result = mosaic.apply(allocator, img) catch |err| {
        std.debug.print("Failed to apply mosaic: {any}\n", .{err});
        std.process.exit(1);
    };
    defer result.deinit();

    std.debug.print("Saving result to {s}...\n", .{output_path});

    // Add null terminator for C string
    const output_path_z = try allocator.dupeZ(u8, output_path);
    defer allocator.free(output_path_z);

    result.save(output_path_z) catch |err| {
        std.debug.print("Failed to save image: {any}\n", .{err});
        std.process.exit(1);
    };

    std.debug.print("Done!\n", .{});
}
