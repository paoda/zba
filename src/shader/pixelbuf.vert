#version 330 core
out vec2 uv;

const vec2 pos[3] = vec2[3](vec2(-1.0f, -1.0f), vec2(-1.0f, 3.0f), vec2(3.0f, -1.0f));
const vec2 uvs[3] = vec2[3](vec2( 0.0f,  0.0f), vec2( 0.0f, 2.0f), vec2(2.0f,  0.0f));

void main() {
	uv = uvs[gl_VertexID];
	gl_Position = vec4(pos[gl_VertexID], 0.0, 1.0);
}
