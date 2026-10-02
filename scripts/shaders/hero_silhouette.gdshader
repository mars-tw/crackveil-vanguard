shader_type canvas_item;

// One texel edge preserves the baked poses and costumes at small screen sizes.
uniform vec4 edge_color : source_color = vec4(0.35, 0.85, 1.0, 0.85);
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 tint = vertex_tint;
	vec4 body = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	float neighbor = max(max(texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a,
		texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, pixel.y)).a,
		texture(TEXTURE, UV - vec2(0.0, pixel.y)).a));
	float edge = max(0.0, neighbor - body.a) * edge_color.a;
	COLOR = vec4(mix(edge_color.rgb, body.rgb * tint.rgb, body.a),
		max(body.a, edge) * tint.a);
}
