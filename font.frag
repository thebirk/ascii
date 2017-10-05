#version 330 core

flat in uint c;
in vec3 fg;
in vec3 bg;

out vec4 color;

uniform sampler2D texture;
uniform uint cells_w;
uniform uint cells_h;

void main() {

	color = vec4(1, 1, 0, 1);
}