import "core:fmt.odin"

import "ascii.odin"

main :: proc() {
	width := 80;
	height := 24;
	// ascii.init("ASCII :D", width, height, "fonts/bw_font.png", 8, 12, false, true)
	ascii.init("ASCII :D", width, height, "fonts/VGA8x16.png", 8, 16, false, true);

	// Switch to event
	close := false;

	time := cast(f32)ascii.get_time();

	for !close {
		glyph: ascii.Glyph;
		for y := 0; y < height; y += 1 {
			for x := 0; x < width; x += 1 {
				glyph.char += 1;
				if glyph.char >= 255 do glyph.char = 0;

				glyph.fg.r += 0.5 * time;
				glyph.fg.g += 0.1 * time;
				glyph.fg.b += 0.2 * time;

				if glyph.fg.r >= 1 do glyph.fg.r = 0;
				if glyph.fg.g >= 1 do glyph.fg.g = 0;
				if glyph.fg.b >= 1 do glyph.fg.b = 0;

				/*glyph.bg.r += 0.1;
				glyph.bg.g += 0.1;
				glyph.bg.b += 0.1;*/

				ascii.set_glyph(x, y, glyph);
			}
		}

		close = ascii.update_and_render();
		ascii.swap_buffers(); // Pull into update_and_render?
	}
}