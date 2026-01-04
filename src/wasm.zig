const std = @import("std");
const im = @import("image_motemenizer");

var allocator = std.heap.wasm_allocator;

export fn alloc(len: usize) ?[*]u8 {
    const slice = allocator.alloc(u8, len) catch return null;
    return slice.ptr;
}

export fn free(ptr: [*]u8, len: usize) void {
    allocator.free(ptr[0..len]);
}

/// Apply mosaic effect to image data
/// Returns null on error (invalid color space, image load failure, or processing error)
export fn applyMosaic(
    input_ptr: [*]const u8,
    input_len: usize,
    blocks_width: u32,
    blocks_height: u32,
    color_space_ptr: [*]const u8,
    color_space_len: usize,
    output_format: u32,
    output_len: *usize,
) ?[*]u8 {
    const color_space_str = color_space_ptr[0..color_space_len];
    const color_space = im.ColorSpace.fromStr(color_space_str) orelse return null;

    var image = im.Image.loadFromMemory(allocator, input_ptr[0..input_len]) catch return null;
    defer image.deinit();

    const mosaic = im.Mosaic.init(blocks_width, blocks_height, color_space);
    var result = mosaic.apply(allocator, image) catch return null;
    defer result.deinit();

    // Parse output format (0=PNG, 1=JPG, 2=BMP, default to PNG)
    const format: im.image.ImageFormat = switch (output_format) {
        1 => .Jpg,
        2 => .Bmp,
        else => .Png,
    };

    const output = result.writeToMemory(allocator, format) catch return null;

    output_len.* = output.len;
    return output.ptr;
}

/// Get image dimensions from image data
/// Returns 0 on success, -1 on error
export fn getDimensions(
    input_ptr: [*]const u8,
    input_len: usize,
    width: *u32,
    height: *u32,
) i32 {
    const image = im.Image.loadFromMemory(allocator, input_ptr[0..input_len]) catch return -1;
    defer image.deinit();

    width.* = @intCast(image.width);
    height.* = @intCast(image.height);
    return 0;
}

/// Get library version string (null-terminated)
export fn version() [*:0]const u8 {
    return "0.0.0";
}
