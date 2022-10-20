#version 330 core
layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 in_color;
layout (location = 2) in vec2 in_uv;

out vec3 color;
out vec2 uv;

void main() {
	color = in_color;
	uv = in_uv;
	gl_Position = vec4(pos, 1.0);
}