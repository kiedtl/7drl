// This file is a placeholder for a more sophisticated font handling code

const std = @import("std");

const c_imp = @cImport({
    @cInclude("png.h");
    @cInclude("stdio.h"); // for fdopen()
});

const err = @import("err.zig");
const colors = @import("colors.zig");
const state = @import("state.zig");

pub const FONT_HEIGHT = 16; //8;
pub const FONT_WIDTH = 8; //7;
pub const FONT_FALLBACK_GLYPH = 0x7F;
pub const FONT_PATH = "font/spleen.png";

pub var font_data: []u8 = undefined;

var png_ctx: ?*c_imp.png_struct = null;
var png_info: ?*c_imp.png_info = null;

fn _png_err(_: ?*c_imp.png_struct, msg: [*c]const u8) callconv(.C) void {
    err.fatal("libPNG error: {s}", .{msg});
}

pub fn loadFontData() void {
    png_ctx = c_imp.png_create_read_struct(c_imp.PNG_LIBPNG_VER_STRING, null, _png_err, null);
    png_info = c_imp.png_create_info_struct(png_ctx);

    if (png_ctx == null or png_info == null) {
        err.fatal("Failed to read font data: libPNG error", .{});
    }

    var font_f = (std.fs.cwd().openDir("data", .{}) catch err.wat())
        .openFile(FONT_PATH, .{ .read = true }) catch |e|
        err.fatal("Failed to read font data: {s}", .{@errorName(e)});
    defer font_f.close();

    c_imp.png_init_io(png_ctx, c_imp.fdopen(font_f.handle, "r"));
    c_imp.png_set_strip_alpha(png_ctx);
    c_imp.png_set_scale_16(png_ctx);
    c_imp.png_set_expand(png_ctx);
    c_imp.png_read_png(png_ctx, png_info, c_imp.PNG_TRANSFORM_GRAY_TO_RGB, null);

    const width = c_imp.png_get_image_width(png_ctx, png_info);
    const height = c_imp.png_get_image_height(png_ctx, png_info);

    font_data = state.GPA.allocator().alloc(u8, width * height) catch err.oom();

    const rows = c_imp.png_get_rows(png_ctx, png_info);
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            const rgb: u32 =
                @intCast(u32, rows[y][(x * 3) + 0]) << 16 |
                @intCast(u32, rows[y][(x * 3) + 1]) << 8 |
                @intCast(u32, rows[y][(x * 3) + 2]);
            font_data[y * width + x] = @intCast(u8, colors.filterGrayscale(rgb) >> 16 & 0xFF);
        }
    }
}

pub fn freeFontData() void {
    c_imp.png_destroy_read_struct(&png_ctx, &png_info, null);
    state.GPA.allocator().free(font_data);
}

// zig fmt: off
pub const z_font_data = [96 * 8][]const u8{
    // space
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    // '!'
    ".......",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    ".......",
    "..xx...",
    ".......",
    // '"'
    ".......",
    ".x..x..",
    ".x..x..",
    ".x..x..",
    ".......",
    ".......",
    ".......",
    ".......",
    // '#'
    ".......",
    ".xx.x..",
    "xxxxxx.",
    ".xx.x..",
    ".xx.x..",
    "xxxxxx.",
    ".xx.x..",
    ".......",
    // '$'
    ".......",
    "...x...",
    "xxxxxx.",
    "xx.x...",
    "xxxxxx.",
    "...x.x.",
    "xxxxxx.",
    "...x...",
    // '%'
    ".......",
    "xx...x.",
    "xx..x..",
    "...x...",
    "..x....",
    ".x..xx.",
    "x...xx.",
    ".......",
    // '&'
    ".......",
    ".xxxx..",
    "xx.....",
    "xx..x..",
    "xxxxxx.",
    "xx..x..",
    ".xxxxx.",
    ".......",
    // '''
    ".......",
    "...x...",
    "...x...",
    "...x...",
    ".......",
    ".......",
    ".......",
    ".......",
    // '('
    ".......",
    "..xxxx.",
    ".xx....",
    ".xx....",
    ".xx....",
    ".xx....",
    ".xx....",
    "..xxxx.",
    // ')'
    ".......",
    "xxxx...",
    "...xx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "xxxx...",
    // '*'
    ".......",
    "x.x.x..",
    ".xxx...",
    ".xxx...",
    "x.x.x..",
    ".......",
    ".......",
    ".......",
    // '+'
    ".......",
    ".......",
    "..x....",
    "..x....",
    "xxxxx..",
    "..x....",
    "..x....",
    ".......",
    // ','
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    "...xx..",
    "...xx..",
    "..xx...",
    // '-'
    ".......",
    ".......",
    ".......",
    ".......",
    "xxxxxxx",
    ".......",
    ".......",
    ".......",
    // '.'
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    "..xx...",
    "..xx...",
    ".......",
    // '/'
    ".......",
    ".....x.",
    "....x..",
    "...x...",
    "..x....",
    ".x.....",
    "x......",
    ".......",
    // '0'
    ".......",
    ".xxxx..",
    "xx..xx.",
    "xx.x.x.",
    "xx.x.x.",
    "xxx..x.",
    ".xxxx..",
    ".......",
    // '1'
    ".......",
    ".xxxx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "...xx..",
    ".......",
    // '2'
    ".......",
    ".xxxx..",
    "x...xx.",
    "....xx.",
    "..xx...",
    "xx.....",
    "xxxxxx.",
    ".......",
    // '3'
    ".......",
    "xxxxxx.",
    "...xx..",
    "..xxx..",
    "....xx.",
    "x...xx.",
    ".xxxx..",
    ".......",
    // '4'
    ".......",
    "..xxx..",
    ".x.xx..",
    "x..xx..",
    "xxxxxx.",
    "...xx..",
    "...xx..",
    ".......",
    // '5'
    ".......",
    "xxxxxx.",
    "xx.....",
    "xxxxx..",
    ".....x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // '6'
    ".......",
    "..xxx..",
    ".x.....",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // '7'
    ".......",
    "xxxxxx.",
    ".....x.",
    "...xx..",
    "..xx...",
    "..xx...",
    "..xx...",
    ".......",
    // '8'
    ".......",
    ".xxxx..",
    "xx...x.",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // '9'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    ".xxxxx.",
    "....xx.",
    ".xxx...",
    ".......",
    // ':'
    ".......",
    ".......",
    "..xx...",
    "..xx...",
    ".......",
    "..xx...",
    "..xx...",
    ".......",
    // ';'
    ".......",
    ".......",
    "...xx..",
    "...xx..",
    ".......",
    "...xx..",
    "...xx..",
    "..xx...",
    // '<'
    ".......",
    ".......",
    "...xx..",
    "..xx...",
    ".xx....",
    "..xx...",
    "...xx..",
    ".......",
    // '='
    ".......",
    ".......",
    ".......",
    "xxxxxx.",
    ".......",
    "xxxxxx.",
    ".......",
    ".......",
    // '>'
    ".......",
    ".......",
    ".xx....",
    "..xx...",
    "...xx..",
    "..xx...",
    ".xx....",
    ".......",
    // '?'
    ".......",
    ".xxxx..",
    "xx...x.",
    ".....x.",
    "...xx..",
    "..xx...",
    "..xx...",
    ".......",
    // '@'
    ".......",
    ".xxxx..",
    "x....x.",
    "x.xxxx.",
    "x.xxxx.",
    "x......",
    ".xxxx..",
    ".......",
    // 'A'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xxxxxx.",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'B'
    ".......",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    "xx...x.",
    "xxxxx..",
    ".......",
    // 'C'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx.....",
    "xx.....",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'D'
    ".......",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    ".......",
    // 'E'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx.....",
    "xxxxxx.",
    "xx.....",
    ".xxxx..",
    ".......",
    // 'F'
    ".......",
    ".xxxxx.",
    "xx.....",
    "xx.....",
    "xxxxx..",
    "xx.....",
    "xx.....",
    ".......",
    // 'G'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx.....",
    "xx.xxx.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'H'
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xxxxxx.",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'I'
    ".......",
    "xxxxxx.",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    "xxxxxx.",
    ".......",
    // 'J'
    ".......",
    "..xxxx.",
    "....xx.",
    "....xx.",
    "....xx.",
    "x...xx.",
    ".xxxx..",
    ".......",
    // 'K'
    ".......",
    "xx...x.",
    "xx..x..",
    "xxxx...",
    "xx..x..",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'L'
    ".......",
    "xx.....",
    "xx.....",
    "xx.....",
    "xx.....",
    "xx.....",
    "xxxxxx.",
    ".......",
    // 'M'
    ".......",
    ".xxxx..",
    "xx.x.x.",
    "xx.x.x.",
    "xx.x.x.",
    "xx.x.x.",
    "xx...x.",
    ".......",
    // 'N'
    ".......",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'O'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'P'
    ".......",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    "xx.....",
    "xx.....",
    ".......",
    // 'Q'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xx.x.x.",
    "xx..x..",
    ".xxx.x.",
    ".......",
    // 'R'
    ".......",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'S'
    ".......",
    ".xxxx..",
    "xx...x.",
    ".xxxx..",
    ".....x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'T'
    ".......",
    "xxxxxx.",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    ".......",
    // 'U'
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'V'
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx..x..",
    "xxxx...",
    ".......",
    // 'W'
    ".......",
    "xx...x.",
    "xx.x.x.",
    "xx.x.x.",
    "xx.x.x.",
    "xx.x.x.",
    ".xxxx..",
    ".......",
    // 'X'
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'Y'
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    "...x...",
    "...x...",
    ".......",
    // 'Z'
    ".......",
    "xxxxxx.",
    "....x..",
    "...x...",
    "..x....",
    ".x.....",
    "xxxxxx.",
    ".......",
    // '['
    ".......",
    ".xxxxx.",
    ".xx....",
    ".xx....",
    ".xx....",
    ".xx....",
    ".xx....",
    ".xxxxx.",
    // '\'
    ".......",
    "x......",
    ".x.....",
    "..x....",
    "...x...",
    "....x..",
    ".....x.",
    ".......",
    // ']'
    ".......",
    "xxxxx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "xxxxx..",
    // '^'
    ".......",
    "...x...",
    "..x.x..",
    ".x...x.",
    ".......",
    ".......",
    ".......",
    ".......",
    // '_'
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    "xxxxxx.",
    ".......",
    // '`'
    ".......",
    ".x.....",
    "..x....",
    "...x...",
    ".......",
    ".......",
    ".......",
    ".......",
    // 'a'
    ".......",
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xx..xx.",
    ".xxx.x.",
    ".......",
    // 'b'
    ".......",
    "xx.....",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    ".......",
    // 'c'
    ".......",
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx.....",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'd'
    ".......",
    "....xx.",
    ".xxxxx.",
    "x...xx.",
    "x...xx.",
    "x...xx.",
    ".xxxxx.",
    ".......",
    // 'e'
    ".......",
    ".......",
    ".xxxx..",
    "xx...x.",
    "xxxxxx.",
    "xx.....",
    ".xxxx..",
    ".......",
    // 'f'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xxxx...",
    "xx.....",
    "xx.....",
    ".......",
    // 'g'
    ".......",
    ".......",
    ".xxxxx.",
    "xx...x.",
    "xx...x.",
    ".xxxxx.",
    ".....x.",
    ".xxxx..",
    // 'h'
    ".......",
    "xx.....",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'i'
    ".......",
    ".xx....",
    ".......",
    ".xx....",
    ".xx....",
    ".xx....",
    "..xxx..",
    ".......",
    // 'j'
    ".......",
    "....xx.",
    ".......",
    "....xx.",
    "....xx.",
    "....xx.",
    "x...xx.",
    ".xxxx..",
    // 'k'
    ".......",
    "xx.....",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'l'
    ".......",
    "xxx....",
    ".xx....",
    ".xx....",
    ".xx....",
    ".xx....",
    "..xxxx.",
    ".......",
    // 'm'
    ".......",
    ".......",
    ".xxxx..",
    "xx.x.x.",
    "xx.x.x.",
    "xx.x.x.",
    "xx...x.",
    ".......",
    // 'n'
    ".......",
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'o'
    ".......",
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'p'
    ".......",
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    "xx.....",
    "xx.....",
    // 'q'
    ".......",
    ".......",
    ".xxxx..",
    "x...xx.",
    "x...xx.",
    ".xxxxx.",
    "....xx.",
    "....xx.",
    // 'r'
    ".......",
    ".......",
    ".xxxxx.",
    "xx.....",
    "xx.....",
    "xx.....",
    "xx.....",
    ".......",
    // 's'
    ".......",
    ".......",
    ".xxxxx.",
    "xxx....",
    ".xxxx..",
    ".....x.",
    ".xxxx..",
    ".......",
    // 't'
    ".......",
    ".xx....",
    "xxxxxx.",
    ".xx....",
    ".xx....",
    ".xx..x.",
    "..xxx..",
    ".......",
    // 'u'
    ".......",
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'v'
    ".......",
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx..x..",
    "xxxx...",
    ".......",
    // 'w'
    ".......",
    ".......",
    "xx...x.",
    "xx.x.x.",
    "xx.x.x.",
    "xx.x.x.",
    ".xxxx..",
    ".......",
    // 'x'
    ".......",
    ".......",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'y'
    ".......",
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxxx.",
    ".....x.",
    ".xxxx..",
    // 'z'
    ".......",
    ".......",
    "xxxxxx.",
    "....x..",
    "..xx...",
    ".x.....",
    "xxxxxx.",
    ".......",
    // '{'
    ".......",
    "...xxx.",
    "..xx...",
    "..xx...",
    "xxxx...",
    "..xx...",
    "..xx...",
    "...xxx.",
    // '|'
    ".......",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    // '}'
    ".......",
    "xxx....",
    "..xx...",
    "..xx...",
    "..xxxx.",
    "..xx...",
    "..xx...",
    "xxx....",
    // '~'
    ".......",
    ".......",
    ".......",
    ".xxx.xx",
    "xx.xxx.",
    ".......",
    ".......",
    ".......",
    // delete
    "xxxxxxx",
    "xxxxxxx",
    "xxxxxxx",
    "xxxxxxx",
    "xxxxxxx",
    "xxxxxxx",
    "xxxxxxx",
    "xxxxxxx",
};
// zig fmt: on
