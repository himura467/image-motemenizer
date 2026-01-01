const std = @import("std");
const math = std.math;

pub const Rgb = struct {
    r: f32,
    g: f32,
    b: f32,

    pub fn init(r: f32, g: f32, b: f32) Rgb {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn toRgbU8(self: Rgb) RgbU8 {
        return .{
            .r = @intFromFloat(@round(self.r * 255.0)),
            .g = @intFromFloat(@round(self.g * 255.0)),
            .b = @intFromFloat(@round(self.b * 255.0)),
        };
    }
};

pub const RgbU8 = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn init(r: u8, g: u8, b: u8) RgbU8 {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn toRgb(self: RgbU8) Rgb {
        return .{
            .r = @as(f32, @floatFromInt(self.r)) / 255.0,
            .g = @as(f32, @floatFromInt(self.g)) / 255.0,
            .b = @as(f32, @floatFromInt(self.b)) / 255.0,
        };
    }
};

pub const Oklab = struct {
    l: f32,
    a: f32,
    b: f32,

    pub fn init(l: f32, a: f32, b: f32) Oklab {
        return .{ .l = l, .a = a, .b = b };
    }
};

fn rgbToLinear(c: f32) f32 {
    if (c <= 0.04045) {
        return c / 12.92;
    } else {
        return math.pow(f32, (c + 0.055) / 1.055, 2.4);
    }
}

fn linearToRgb(c: f32) f32 {
    if (c <= 0.0031308) {
        return c * 12.92;
    } else {
        return 1.055 * math.pow(f32, c, 1.0 / 2.4) - 0.055;
    }
}

// https://bottosson.github.io/posts/oklab/#converting-from-linear-srgb-to-oklab
pub fn rgbToOklab(rgb: Rgb) Oklab {
    const lr = rgbToLinear(rgb.r);
    const lg = rgbToLinear(rgb.g);
    const lb = rgbToLinear(rgb.b);

    const l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb;
    const m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb;
    const s = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb;

    const l_ = math.cbrt(l);
    const m_ = math.cbrt(m);
    const s_ = math.cbrt(s);

    return Oklab{
        .l = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        .a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        .b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
    };
}

// https://bottosson.github.io/posts/oklab/#converting-from-linear-srgb-to-oklab
pub fn oklabToRgb(oklab: Oklab) Rgb {
    const l_ = oklab.l + 0.3963377774 * oklab.a + 0.2158037573 * oklab.b;
    const m_ = oklab.l - 0.1055613458 * oklab.a - 0.0638541728 * oklab.b;
    const s_ = oklab.l - 0.0894841775 * oklab.a - 1.2914855480 * oklab.b;

    const l = l_ * l_ * l_;
    const m = m_ * m_ * m_;
    const s = s_ * s_ * s_;

    const lr = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
    const lg = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
    const lb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

    return Rgb{
        .r = math.clamp(linearToRgb(lr), 0.0, 1.0),
        .g = math.clamp(linearToRgb(lg), 0.0, 1.0),
        .b = math.clamp(linearToRgb(lb), 0.0, 1.0),
    };
}

pub const ColorSpace = enum {
    Rgb,
    Oklab,
};

test "RGB to Oklab conversion round-trip" {
    const original = Rgb.init(0.5, 0.3, 0.7);
    const oklab = rgbToOklab(original);
    const back = oklabToRgb(oklab);

    const tolerance = 0.01;
    try std.testing.expect(@abs(back.r - original.r) < tolerance);
    try std.testing.expect(@abs(back.g - original.g) < tolerance);
    try std.testing.expect(@abs(back.b - original.b) < tolerance);
}
