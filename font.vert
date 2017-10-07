#version 330 core

// Vertex data
layout(location = 0) in vec2 vert;
layout(location = 1) in vec2 in_offsets;// Offset from top-right corner used by fragments shader to what corner to sample

// Character data
layout(location = 2) in uint in_c;
layout(location = 3) in vec3 in_fg;
layout(location = 4) in vec3 in_bg;

flat out uint c;
out vec3 fg;
out vec3 bg;
out vec2 offsets;

uniform mat4 projection;

void main() {
	fg = in_fg;
	bg = in_bg;
	c = in_c;
	offsets = in_offsets;
	
	gl_Position = projection * vec4(vert, 0.0, 1.0);
}