// Folded Keep — the map fold. Owner: Claude (see DESIGN.md).
// Draws the map texture, and while a fold is active: the lifted region shows the
// table, the flap's back lands mirrored across the fold line, and the flap casts a shadow.
shader_type canvas_item;

uniform vec2 map_size = vec2(360.0, 640.0);
uniform bool fold_active = false;
uniform vec2 fold_point = vec2(0.0);   // point on the fold line (map px)
uniform vec2 fold_normal = vec2(1.0, 0.0); // unit normal, points toward the flap side
uniform float lift = 0.0;              // 1 = flap held up (shadow, translucent), 0 = pressed flat
uniform float flash = 0.0;             // impact flare on the flap's back, 1 -> 0
uniform vec4 table_color : source_color = vec4(0.165, 0.114, 0.078, 1.0);
uniform vec4 back_color : source_color = vec4(0.86, 0.79, 0.62, 1.0);
uniform int crease_count = 0;
uniform vec4 creases[16]; // xy = point on crease, zw = normal
uniform int hole_count = 0;
uniform vec3 holes[8];    // tears in the map: xy = center, z = radius

bool inside(vec2 p) {
	return p.x >= 0.0 && p.y >= 0.0 && p.x < map_size.x && p.y < map_size.y;
}

vec2 mirror(vec2 p) {
	return p - 2.0 * dot(p - fold_point, fold_normal) * fold_normal;
}

float edge_dist(vec2 p) {
	vec2 e = min(p, map_size - p);
	return min(e.x, e.y);
}

vec3 front(vec3 c, vec2 p) {
	c *= mix(0.72, 1.0, smoothstep(0.0, 9.0, edge_dist(p))); // aged edge
	for (int i = 0; i < 16; i++) {
		if (i >= crease_count) {
			break;
		}
		float d = dot(p - creases[i].xy, creases[i].zw);
		if (abs(d) < 0.75) {
			c *= 0.8;
		} else if (d > 0.0 && d < 2.0) {
			c *= 1.07;
		}
	}
	return c;
}

// Signed distance-ish to the nearest tear: < 0 inside a hole. Ragged edge from a few sines.
float tear_dist(vec2 p) {
	float best = 1e5;
	for (int i = 0; i < 8; i++) {
		if (i >= hole_count) {
			break;
		}
		vec2 v = p - holes[i].xy;
		float a = atan(v.y, v.x);
		float r = holes[i].z * (1.0 + 0.16 * sin(a * 7.0 + holes[i].x) + 0.07 * sin(a * 17.0 + holes[i].y));
		best = min(best, length(v) - r);
	}
	return best;
}

void fragment() {
	vec2 p = UV * map_size;
	vec3 col = front(texture(TEXTURE, p / map_size).rgb, p);
	float td = tear_dist(p);
	if (td < 0.0) {
		col = table_color.rgb * (0.75 + 0.25 * smoothstep(-6.0, 0.0, td)); // looking down the hole
	} else if (td < 2.5) {
		col = mix(vec3(0.96, 0.92, 0.8), col * 0.7, smoothstep(0.0, 2.5, td)); // torn paper fibers
	}
	if (fold_active) {
		float d = dot(p - fold_point, fold_normal);
		if (d > 0.0) {
			// Paper lifted away here: we see the table.
			col = table_color.rgb * (0.9 + 0.1 * smoothstep(0.0, 40.0, d));
		} else {
			vec2 q = mirror(p);
			if (inside(q) && tear_dist(q) >= 0.0) {
				// Back of the flap. Its ink shows through faintly, mirrored.
				vec3 ink = texture(TEXTURE, q / map_size).rgb;
				vec3 b = mix(back_color.rgb, ink * 0.92, 0.24);
				// While lifted the flap is translucent so you can aim through it.
				b = mix(b, col, 0.38 * lift);
				b *= mix(0.8, 1.0, smoothstep(0.0, 16.0, -d)); // curl shading at the crease
				b *= mix(0.7, 1.0, smoothstep(0.0, 2.5, edge_dist(q))); // paper edge
				col = b * (1.0 + 0.05 * lift);
				col = mix(col, vec3(1.0, 0.97, 0.88), flash * 0.55);
			} else {
				// Flap shadow on the map.
				vec2 off = vec2(2.0, 4.0) * (0.5 + 2.5 * lift);
				vec2 s = p - off;
				if (dot(s - fold_point, fold_normal) <= 0.0 && inside(mirror(s))) {
					col *= 0.7;
				}
			}
		}
	}
	COLOR = vec4(col, 1.0);
}
