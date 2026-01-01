const std = @import("std");
const color = @import("color.zig");
const image = @import("image.zig");

pub const MosaicError = error{
    InvalidDimensions,
    OutOfMemory,
};

fn averageRgb(img: image.Image, x_start: usize, y_start: usize, x_end: usize, y_end: usize) color.Rgb {
    var sum_r: f32 = 0.0;
    var sum_g: f32 = 0.0;
    var sum_b: f32 = 0.0;
    var count: f32 = 0.0;

    var y = y_start;
    while (y < y_end) : (y += 1) {
        var x = x_start;
        while (x < x_end) : (x += 1) {
            const pixel = img.getPixel(x, y);
            sum_r += pixel.r;
            sum_g += pixel.g;
            sum_b += pixel.b;
            count += 1.0;
        }
    }

    return color.Rgb{
        .r = sum_r / count,
        .g = sum_g / count,
        .b = sum_b / count,
    };
}

fn averageOklab(img: image.Image, x_start: usize, y_start: usize, x_end: usize, y_end: usize) color.Rgb {
    var sum_l: f32 = 0.0;
    var sum_a: f32 = 0.0;
    var sum_b: f32 = 0.0;
    var count: f32 = 0.0;

    var y = y_start;
    while (y < y_end) : (y += 1) {
        var x = x_start;
        while (x < x_end) : (x += 1) {
            const pixel = img.getPixel(x, y);
            const oklab = color.rgbToOklab(pixel);
            sum_l += oklab.l;
            sum_a += oklab.a;
            sum_b += oklab.b;
            count += 1.0;
        }
    }

    const avg_oklab = color.Oklab{
        .l = sum_l / count,
        .a = sum_a / count,
        .b = sum_b / count,
    };

    return color.oklabToRgb(avg_oklab);
}

pub const Mosaic = struct {
    blocks_width: usize,
    blocks_height: usize,
    color_space: color.ColorSpace,

    pub fn init(blocks_width: usize, blocks_height: usize, color_space: color.ColorSpace) Mosaic {
        return Mosaic{
            .blocks_width = blocks_width,
            .blocks_height = blocks_height,
            .color_space = color_space,
        };
    }

    pub fn apply(self: Mosaic, allocator: std.mem.Allocator, src: image.Image) MosaicError!image.Image {
        if (self.blocks_width == 0 or self.blocks_height == 0) {
            return MosaicError.InvalidDimensions;
        }

        var result = image.Image.init(allocator, src.width, src.height) catch {
            return MosaicError.OutOfMemory;
        };
        errdefer result.deinit();

        const block_width = @as(f32, @floatFromInt(src.width)) / @as(f32, @floatFromInt(self.blocks_width));
        const block_height = @as(f32, @floatFromInt(src.height)) / @as(f32, @floatFromInt(self.blocks_height));
        var block_y: usize = 0;
        while (block_y < self.blocks_height) : (block_y += 1) {
            var block_x: usize = 0;
            while (block_x < self.blocks_width) : (block_x += 1) {
                const x_start = @as(usize, @intFromFloat(@as(f32, @floatFromInt(block_x)) * block_width));
                const y_start = @as(usize, @intFromFloat(@as(f32, @floatFromInt(block_y)) * block_height));
                const x_end = @min(
                    @as(usize, @intFromFloat(@as(f32, @floatFromInt(block_x + 1)) * block_width)),
                    src.width,
                );
                const y_end = @min(
                    @as(usize, @intFromFloat(@as(f32, @floatFromInt(block_y + 1)) * block_height)),
                    src.height,
                );

                const avg_color = switch (self.color_space) {
                    .Rgb => averageRgb(src, x_start, y_start, x_end, y_end),
                    .Oklab => averageOklab(src, x_start, y_start, x_end, y_end),
                };
                var y = y_start;
                while (y < y_end) : (y += 1) {
                    var x = x_start;
                    while (x < x_end) : (x += 1) {
                        result.setPixel(x, y, avg_color);
                    }
                }
            }
        }

        return result;
    }
};

test "mosaic creates same size image" {
    const allocator = std.testing.allocator;

    var img = try image.Image.init(allocator, 100, 100);
    defer img.deinit();

    const mosaic = Mosaic.init(10, 10, .Rgb);

    var result = try mosaic.apply(allocator, img);
    defer result.deinit();

    try std.testing.expectEqual(img.width, result.width);
    try std.testing.expectEqual(img.height, result.height);
}

test "mosaic with single block returns average color" {
    const allocator = std.testing.allocator;

    var img = try image.Image.init(allocator, 4, 4);
    defer img.deinit();

    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();

    var sum_g: f32 = 0.0;
    var sum_b: f32 = 0.0;

    var y: usize = 0;
    while (y < 4) : (y += 1) {
        var x: usize = 0;
        while (x < 4) : (x += 1) {
            const g = random.float(f32);
            const b = random.float(f32);
            sum_g += g;
            sum_b += b;
            img.setPixel(x, y, color.Rgb.init(1.0, g, b));
        }
    }

    const expected_g = sum_g / 16.0;
    const expected_b = sum_b / 16.0;

    const mosaic = Mosaic.init(1, 1, .Rgb);

    var result = try mosaic.apply(allocator, img);
    defer result.deinit();

    const tolerance = 0.01;

    var test_y: usize = 0;
    while (test_y < 4) : (test_y += 1) {
        var test_x: usize = 0;
        while (test_x < 4) : (test_x += 1) {
            const pixel = result.getPixel(test_x, test_y);
            try std.testing.expect(@abs(pixel.r - 1.0) < tolerance);
            try std.testing.expect(@abs(pixel.g - expected_g) < tolerance);
            try std.testing.expect(@abs(pixel.b - expected_b) < tolerance);
        }
    }
}

test "mosaic with invalid dimensions" {
    const allocator = std.testing.allocator;

    var img = try image.Image.init(allocator, 100, 100);
    defer img.deinit();

    const mosaic = Mosaic.init(0, 10, .Rgb);

    const result = mosaic.apply(allocator, img);
    try std.testing.expectError(MosaicError.InvalidDimensions, result);
}
