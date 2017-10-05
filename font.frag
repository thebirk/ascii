#version 330 core

in vec3 fg;
in vec3 bg;
in int c;

out vec4 color;

uniform sampler2D texture;
uniform uint cells_w;
uniform uint cells_h;

void main() {

	color = vec4(1, 1, 1, 1);
}