shader_type canvas_item;
// Ink printed on the parchment: hand-drawn "line boil" (the drawing re-traces itself a few times a
// second) and a reveal that soaks the ink in (0 = blank paper, 1 = fully printed) with a dark wet
// front. Used by units and buildings (one material per node, `reveal` set from code).
// Owner: Claude.

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float boil = 1.0; // wobble in screen pixels
uniform float boil_fps = 4.0;
uniform float seed = 0.0;
uniform vec4 wet_ink : source_color = vec4(0.13, 0.09, 0.06, 1.0);
// the reveal spreads out from here (local coordinates), reaching `radius` when reveal = 1
uniform vec2 center = vec2(0.0, -7.0);
uniform float radius = 14.0;

varying vec2 local;

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

void vertex() {
	local = VERTEX;
	// shapes drawn in code have many vertices: nudge each one, re-rolled every boil frame
	float st = floor(TIME * boil_fps) + seed;
	VERTEX += (vec2(noise(VERTEX * 0.4 + st * 7.13), noise(VERTEX * 0.4 + st * 3.71 + 19.0)) - 0.5) * boil * 0.6;
}

void fragment() {
	float st = floor(TIME * boil_fps) + seed;
	// textures: wobble the lookup by about `boil` screen pixels
	vec2 px = fwidth(UV);
	vec2 wob = vec2(noise(local * 0.7 + st * 5.7), noise(local * 0.7 + st * 2.9 + 7.0)) - 0.5;
	vec4 c = texture(TEXTURE, UV + wob * boil * px) * COLOR;
	if (reveal < 0.999) {
		// a blot soaking outward from the center, with a ragged fibrous edge
		float d = length(local - center) / radius;
		float n = d * 0.75 + noise(local * 0.22 + seed * 13.0) * 0.3 + noise(local * 0.9 - seed) * 0.08;
		float front = reveal * 1.25;
		float inked = smoothstep(front + 0.03, front - 0.03, n);
		float wet = smoothstep(front - 0.35, front, n) * inked;
		c.rgb = mix(c.rgb, wet_ink.rgb, wet * 0.8);
		c.a *= inked;
	}
	COLOR = c;
}
