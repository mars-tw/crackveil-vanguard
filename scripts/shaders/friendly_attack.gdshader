shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float light = max(source.r, max(source.g, source.b));
	COLOR = vec4(vec3(0.40, 0.80, 1.0) * light, source.a * 0.66);
}
