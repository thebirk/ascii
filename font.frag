#version 330 core

flat in uint c;
in vec3 fg;
in vec3 bg;
in vec2 offsets;

out vec4 color;

uniform sampler2D tex;
uniform uint cells_w;
uniform uint cells_h;
uniform uint font_width;
uniform uint font_height;

void main() {
	uint x = uint(c) % (font_width / cells_w);
	uint y = uint(c) / (font_height / cells_h);

	float xx = float(x) / float(font_width / cells_w);
	float yy = float(y) / float(font_height / cells_h);

	xx += offsets.x * (float(cells_w)/float(font_width));
	yy += offsets.y * (float(cells_h)/float(font_height));

	// color = vec4(1, 1, 0, 1);
	vec4 texture_color = texture(tex, vec2(xx, yy));

	if(texture_color.x == 1) {
		color = vec4(fg, 1);
	} else {
		color = vec4(bg, 1);
	}
	// color = vec4(xx, yy, 0, 1);
	// color = vec4(offsets.x, offsets.y, 0, 1);
}