import "core:fmt.odin"

import "ascii.odin"

main :: proc() {
	font := ascii.load_font("bw_font.bmp", 8, 12);
	ascii.open_window("ascii", 80, 25, font, true, true);	

	// Switch to event
	close := false;
	for !close {
		close = ascii.update_and_render();
		ascii.swap_buffers(); // Pull into update_and_render?
	}
}