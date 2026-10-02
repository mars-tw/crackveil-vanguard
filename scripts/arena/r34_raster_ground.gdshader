shader_type canvas_item;

uniform sampler2D ground_tex : repeat_disable, filter_linear_mipmap;
uniform vec2 world_origin = vec2(0.0);
uniform vec2 world_span = vec2(1280.0, 720.0);
uniform vec2 map_world_span = vec2(1240.0, 790.0);
uniform vec2 seed_offset = vec2(0.0);

void fragment() {
	vec2 world = world_origin + UV * world_span;
	vec2 map_space = (world + seed_offset) / map_world_span + vec2(0.5);
	// A single finite painted stage: no wrapping, mirror, repeated copies,
	// screen-locked framing or smaller texture tiles. Arena owns camera limits.
	vec2 map_uv = clamp(map_space, vec2(0.0001), vec2(0.9999));
	COLOR = texture(ground_tex, map_uv);
}
