import "core:fmt.odin"

import "ascii.odin"

main :: proc() {
	font: ascii.Font;
	font.cell_w = 8;
	font.cell_h = 16;
	ascii.open_window("ascii", 80, 25, font, true, true);	

	// Switch to event
	close := false;
	for !close {
		close = ascii.update_and_render();
		ascii.swap_buffers(); // Pull into update_and_render?
	}
}