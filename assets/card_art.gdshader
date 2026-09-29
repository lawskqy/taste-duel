shader_type canvas_item;
varying vec4 tile_tint;

void vertex() {
	tile_tint = COLOR;
}

// Give existing food illustrations a warm, rounded tile without new bitmap assets.
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float paper = smoothstep(0.92, 0.99, min(art.r, min(art.g, art.b)));
	art.rgb = mix(art.rgb, vec3(0.957, 0.918, 0.839), paper);
	vec2 corner = abs(UV - 0.5) - vec2(0.36);
	float distance_to_edge = length(max(corner, 0.0)) + min(max(corner.x, corner.y), 0.0) - 0.14;
	art.a *= 1.0 - smoothstep(-0.008, 0.008, distance_to_edge);
	COLOR = art * tile_tint;
}
