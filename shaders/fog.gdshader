shader_type canvas_item;
// Fog banks drifting over the map (Weather "fog"): thick along the top edge where the enemies come
// in, thinning out toward the Keep. Same cheap value noise as the cloud shadows. Owner: Claude.

uniform float amount = 0.0; // 0 = clear, 1 = full fog
uniform vec2 drift = vec2(5.0, 1.2);
uniform float scale = 95.0;
uniform vec4 tint : source_color = vec4(0.92, 0.92, 0.9, 1.0);
uniform float top = 0.95; // opacity along the top edge
uniform float bottom = 0.3; // opacity at the Keep

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
	float n = noise(q) * 0.5 + noise(q * 2.3 + 3.7 + vec2(TIME * 0.03, 0.0)) * 0.32 + noise(q * 5.1 + 8.2) * 0.18;
	float bank = smoothstep(0.38, 0.62, n);
	float dens = mix(top, bottom, smoothstep(60.0, 560.0, p.y));
	COLOR = vec4(tint.rgb, amount * dens * (0.2 + 0.8 * bank));
}
