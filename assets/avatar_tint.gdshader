shader_type canvas_item;
uniform vec4 accent : source_color = vec4(1.0, 0.5, 0.4, 1.0);
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float mask = smoothstep(0.12, 0.4, min(pixel.r, pixel.b) - pixel.g);
	pixel.rgb = mix(pixel.rgb, accent.rgb * max(pixel.r, pixel.b), mask);
	COLOR = pixel * vertex_tint;
}
