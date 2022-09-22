#version 330 core
out vec4 frag_color;

in vec3 color;
in vec2 uv;

uniform sampler2D screen;

void main() {
	// https://near.sh/video/color-emulation
	// Thanks to Talarubi + Near for the Colour Correction
	// Thanks to fleur + mattrb for the Shader Impl

	vec4 color = texture(screen, uv);
	color.rgb = pow(color.rgb, vec3(4.0)); // LCD Gamma
  
	frag_color = vec4(
		pow(vec3(
		  	  0 * color.b +  50 * color.g + 255 * color.r,
	     	 30 * color.b + 230 * color.g +  10 * color.r,
			220 * color.b +  10 * color.g +  50 * color.r
		) / 255, vec3(1.0 / 2.2)), // Out Gamma
	1.0); 
}

