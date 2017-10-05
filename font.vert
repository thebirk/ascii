#version 330 core

layout(location = 0) in vec2 vert;
layout(location = 1) in uint in_c;
layout(location = 2) in vec3 in_fg;
layout(location = 3) in vec3 in_bg;

out vec3 fg;
out vec3 bg;
out uint c;

uniform mat4 projection;

void main() {
	fg = in_fg;
	bg = in_bg;
	c = in_c;

	gl_Position = projection * vec4(vert, 0, 1);
}