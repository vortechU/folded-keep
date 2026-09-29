shader_type canvas_item;
// Aged parchment, baked once into a texture by paper.gd (so it costs nothing per frame):
// soft mottling, fibers, grain, foxing spots and ragged, sun-browned edges.
// Owner: Claude.

uniform vec2 size = vec2(360.0, 640.0);
uniform vec4 paper : source_color = vec4(0.918, 0.851, 0.690, 1.0);
uniform vec4 mid : source_color = vec4(0.847, 0.753, 0.541, 1.0);
uniform vec4 shade : source_color = vec4(0.722, 0.604, 0.384, 1.0);
uniform vec4 sepia : source_color = vec4(0.431, 0.294, 0.165, 1.0);
uniform float seed = 3.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += noise(p) * a;
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV * size + seed * 101.0;
	vec2 q = UV * size;
	// large soft mottling
	float mottle = fbm(p / 80.0);
	vec3 c = mix(paper.rgb, mid.rgb, smoothstep(0.38, 0.78, mottle) * 0.6);
	// long paper fibers and fine grain
	float fib = noise(vec2(p.x * 0.07, p.y * 1.1)) * 0.6 + noise(vec2(p.x * 1.3, p.y * 0.09)) * 0.4;
	c *= 1.0 + (fib - 0.5) * 0.06;
	c *= 1.0 + (hash(floor(UV * size * 2.0)) - 0.5) * 0.045;
	// foxing: little brown age spots
	float fox = noise(p / 11.0 + 40.0) * 0.7 + noise(p / 3.0) * 0.3;
	c = mix(c, shade.rgb, smoothstep(0.76, 0.88, fox) * 0.2);
	// ragged, sun-browned edges
	float e = min(min(q.x, size.x - q.x), min(q.y, size.y - q.y));
	e += (fbm(p / 14.0) - 0.5) * 14.0;
	c = mix(c, shade.rgb, smoothstep(30.0, 3.0, e) * 0.5);
	c = mix(c, sepia.rgb, smoothstep(5.0, -1.0, e) * 0.55);
	COLOR = vec4(c, 1.0);
}
