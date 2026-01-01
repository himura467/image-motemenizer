# image-motemenizer

A Zig library for applying mosaic effects to images.

## Features

- **Multiple Color Spaces**: Support for RGB and Oklab color spaces
  - RGB: Standard color space
  - Oklab: Perceptually uniform color space for more accurate color averaging
- **Flexible Mosaic Dimensions**: Specify any number of horizontal and vertical blocks
- **Image Format Support**: Read and write PNG, JPG, and BMP files via stb_image
- **Zero Dependencies**: Only uses stb_image library (vendored)
- **Pure Zig Library**: Can be used as a library or CLI tool

## Usage

Requires Zig `0.15.2`.

### Command Line Interface

```bash
# Using RGB color space (default)
zig build run -- input.jpg output.png 32 24 rgb

# Using Oklab color space for perceptually accurate color averaging
zig build run -- input.jpg output.png 32 24 oklab
```

**Arguments:**
- `input` - Path to input image file (PNG, JPG, or BMP)
- `output` - Path to output image file (format determined by extension)
- `blocks_width` - Number of mosaic blocks horizontally
- `blocks_height` - Number of mosaic blocks vertically
- `color_space` - (Optional) Color space for averaging: `rgb` or `oklab` (default: `rgb`)

### Running Tests

```bash
zig build test
```

## License

MIT
