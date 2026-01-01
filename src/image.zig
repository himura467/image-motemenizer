const std = @import("std");
const color = @import("color.zig");

const c = @cImport({
    @cInclude("stb_image.h");
    @cInclude("stb_image_write.h");
});

pub const ImageError = error{
    OutOfMemory,
    LoadFailed,
    WriteFailed,
    UnsupportedFormat,
};

pub const Image = struct {
    width: usize,
    height: usize,
    data: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) ImageError!Image {
        const data = allocator.alloc(u8, width * height * 3) catch {
            return ImageError.OutOfMemory;
        };
        @memset(data, 0);

        return Image{
            .width = width,
            .height = height,
            .data = data,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Image) void {
        self.allocator.free(self.data);
    }

    pub fn load(allocator: std.mem.Allocator, path: [:0]const u8) ImageError!Image {
        var width: c_int = 0;
        var height: c_int = 0;
        var channels: c_int = 0;

        // Force RGB format (3 channels) for consistent pixel data layout
        const data_ptr = c.stbi_load(path.ptr, &width, &height, &channels, 3);
        if (data_ptr == null) {
            return ImageError.LoadFailed;
        }

        const w = @as(usize, @intCast(width));
        const h = @as(usize, @intCast(height));
        const size = w * h * 3;

        const data = allocator.alloc(u8, size) catch {
            c.stbi_image_free(data_ptr);
            return ImageError.OutOfMemory;
        };

        @memcpy(data, data_ptr[0..size]);
        c.stbi_image_free(data_ptr);

        return Image{
            .width = w,
            .height = h,
            .data = data,
            .allocator = allocator,
        };
    }

    pub fn save(self: Image, path: [:0]const u8) ImageError!void {
        const width = @as(c_int, @intCast(self.width));
        const height = @as(c_int, @intCast(self.height));

        const ext = std.fs.path.extension(path);
        const result = if (std.mem.eql(u8, ext, ".png"))
            c.stbi_write_png(path.ptr, width, height, 3, self.data.ptr, width * 3)
        else if (std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".jpeg"))
            // Quality 90 (out of 100) provides good balance between file size and image quality
            c.stbi_write_jpg(path.ptr, width, height, 3, self.data.ptr, 90)
        else if (std.mem.eql(u8, ext, ".bmp"))
            c.stbi_write_bmp(path.ptr, width, height, 3, self.data.ptr)
        else
            return ImageError.UnsupportedFormat;

        if (result == 0) {
            return ImageError.WriteFailed;
        }
    }

    pub fn getPixel(self: Image, x: usize, y: usize) color.Rgb {
        const idx = (y * self.width + x) * 3;
        const rgb_u8 = color.RgbU8.init(self.data[idx], self.data[idx + 1], self.data[idx + 2]);
        return rgb_u8.toRgb();
    }

    pub fn setPixel(self: *Image, x: usize, y: usize, rgb: color.Rgb) void {
        const idx = (y * self.width + x) * 3;
        const rgb_u8 = rgb.toRgbU8();
        self.data[idx] = rgb_u8.r;
        self.data[idx + 1] = rgb_u8.g;
        self.data[idx + 2] = rgb_u8.b;
    }
};
