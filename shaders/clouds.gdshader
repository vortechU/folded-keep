shader_type canvas_item;
// Soft cloud shadows drifting over the map with the wind (drawn above units, inside the map, so
// they fold with it). Cheap: 3 octaves of value noise. Owner: Claude.

uniform vec2 drift = vec2(6.6, 2.4); // px per second, along Wind.DIR
uniform float strength = 0.13;
uniform float scale = 150.0;
uniform vec4 tint : source_color = vec4(0.23, 0.16, 0.11, 1.0);

varying vec2 p;

float hash(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	p = VERTEX;
}

void fragment() {
	vec2 q = (p - drift * TIME) / scale;
	float n = noise(q) * 0.55 + noise(q * 2.1 + 5.3) * 0.3 + noise(q * 4.3 + 9.1) * 0.15;
	float cloud = smoothstep(0.52, 0.72, n);
	COLOR = vec4(tint.rgb, cloud * strength);
}
