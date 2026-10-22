shader_type canvas_item;
uniform bool attack_sector = false;
void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float light = max(source.r, max(source.g, source.b));
	float mask = attack_sector ? smoothstep(0.05, 0.25, (UV.x - 0.5) / max(0.01, length(UV - vec2(0.5)))) : 1.0;
	COLOR = vec4(vec3(0.52, 0.84, 1.0) * light, source.a * 0.66 * mask);
}
