shader_type canvas_item;
render_mode unshaded;

uniform float intro_time = 2.0;
uniform float logo_center = 250.0;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec4 ink = texture(TEXTURE, UV) * COLOR;
	vec2 tile = floor(local_position / 4.0);
	float seed = fract(sin(dot(tile, vec2(12.9898, 78.233))) * 43758.5453);
	float outward = clamp(abs(local_position.x - logo_center) / 150.0, 0.0, 1.0);
	float arrival = 0.06 + outward * 0.30 + seed * 0.16;
	float assembled = smoothstep(arrival, arrival + 0.09, intro_time);
	// The complete mark remains readable underneath the arriving pixel blocks.
	ink.a *= mix(0.16, 1.0, assembled);
	float sweep_x = logo_center - 180.0 + (intro_time - 1.35) * 850.0;
	float band = 1.0 - step(9.0, abs(local_position.x + local_position.y * 0.28 - sweep_x));
	float sweep = band * step(1.35, intro_time) * (1.0 - step(1.81, intro_time));
	ink.rgb = mix(ink.rgb, vec3(0.98, 0.94, 0.72), sweep * 0.65);
	COLOR = ink;
}
