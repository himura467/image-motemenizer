const std = @import("std");
pub const color = @import("color.zig");
pub const image = @import("image.zig");
pub const mosaic = @import("mosaic.zig");

pub const Rgb = color.Rgb;
pub const RgbU8 = color.RgbU8;
pub const Oklab = color.Oklab;
pub const ColorSpace = color.ColorSpace;
pub const Image = image.Image;
pub const Mosaic = mosaic.Mosaic;

test {
    std.testing.refAllDecls(@This());
}
