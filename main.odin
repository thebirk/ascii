import "core:fmt.odin"

import "ascii.odin"

main :: proc() {
	ascii.open_window("ascii", 80, 25, "bw_font.png", 8, 12, true, true);

	// Switch to event
	close := false;

	time := cast(f32)ascii.get_time();

	for !close {
		glyph: ascii.Glyph;
		for y := 0; y < 25; y += 1 {
			for x := 0; x < 80; x += 1 {
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