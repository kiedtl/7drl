usingnamespace @import("types.zig");

pub const ConstructedBasalt = Material{
    .name = "constructed basalt",
    .description = "TODO",
    .density = 1.5, // half of basalt
    .color_fg = 0x9e9e9e,
    .color_bg = 0x272727, // bg of basalt floor
    .glyph = '#',
    .melting_point = 700, // FIXME: not accurate
    .combust_point = null,
    .specific_heat = 0.25, // half of basalt
    .luminescence = 0,
    .opacity = 1.0,
};

pub const Basalt = Material{
    .name = "basalt",
    .description = "TODO",
    .density = 2.9,
    .color_fg = 0x404040,
    .color_bg = 0x837462,
    .glyph = '#',
    .melting_point = 1257,
    .combust_point = null,
    .specific_heat = 0.84, // FIXME: not accurate!
    .luminescence = 0,
    .opacity = 1.0,
};
