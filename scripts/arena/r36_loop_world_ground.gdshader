shader_type canvas_item;

uniform sampler2D field_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D road_tex : repeat_enable, filter_linear_mipmap;
uniform vec2 world_origin;
uniform vec2 view_span = vec2(1280.0, 720.0);
uniform vec2 loop_period = vec2(4096.0, 3072.0);
uniform vec2 texture_world_span = vec2(512.0, 512.0);
uniform vec2 ring_radii = vec2(1400.0, 1000.0);
uniform vec2 seed_offset = vec2(0.0);
uniform vec4 field_tint : source_color = vec4(0.88, 0.91, 1.0, 1.0);
uniform vec4 road_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Smooth macro patches break up repeated stones without another texture or a
// per-pixel trigonometric function. Cell indices wrap at the same world period.
float patch_hash(vec2 cell) {
	vec2 wrapped = mod(cell, loop_period / texture_world_span);
	return fract(dot(wrapped, vec2(0.1031, 0.11369)) * dot(wrapped + vec2(19.19, 41.79), vec2(0.71, 0.29)));
}

float material_patch(vec2 world) {
	vec2 cell = (world + loop_period * 0.5) / texture_world_span;
	vec2 grid = floor(cell);
	vec2 blend = fract(cell);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float a = mix(patch_hash(grid), patch_hash(grid + vec2(1.0, 0.0)), blend.x);
	float b = mix(patch_hash(grid + vec2(0.0, 1.0)), patch_hash(grid + vec2(1.0, 1.0)), blend.x);
	return mix(a, b, blend.y);
}

void fragment() {
	vec2 world = world_origin + UV * view_span;
	vec2 p = mod(world + loop_period * 0.5, loop_period) - loop_period * 0.5;
	vec2 material_uv = (p + seed_offset) / texture_world_span;
	vec4 field = texture(field_tex, material_uv) * field_tint;
	vec4 paving = texture(road_tex, material_uv + vec2(0.17, 0.31)) * road_tint;
	float patch = material_patch(p);
	float k0 = length(p / ring_radii);
	float k1 = length(p / (ring_radii * ring_radii));
	float ring_distance = abs(k0 * (k0 - 1.0) / max(k1, 0.000001));
	float edge_variation = (patch - 0.5) * 18.0;
	float ring_edge = ring_distance + edge_variation;
	float ring = 1.0 - smoothstep(96.0, 132.0, ring_edge);
	float horizontal_end = 1.0 - smoothstep(1370.0, 1490.0, abs(p.x));
	float vertical_end = 1.0 - smoothstep(970.0, 1090.0, abs(p.y));
	float horizontal_edge = abs(p.y) + edge_variation * 0.45;
	float vertical_edge = abs(p.x) + edge_variation * 0.45;
	float horizontal = (1.0 - smoothstep(60.0, 96.0, horizontal_edge)) * horizontal_end;
	float vertical = (1.0 - smoothstep(60.0, 96.0, vertical_edge)) * vertical_end;
	float center_distance = length(p);
	float hub = 1.0 - smoothstep(235.0, 285.0, center_distance);
	float road = max(max(ring, hub), max(horizontal, vertical));
	float outer_ring = 1.0 - smoothstep(127.0, 159.0, ring_edge);
	float outer_horizontal = (1.0 - smoothstep(92.0, 120.0, horizontal_edge)) * horizontal_end;
	float outer_vertical = (1.0 - smoothstep(92.0, 120.0, vertical_edge)) * vertical_end;
	float outer_hub = 1.0 - smoothstep(280.0, 310.0, center_distance);
	float shoulder = max(max(outer_ring, outer_hub), max(outer_horizontal, outer_vertical)) * (1.0 - road);
	// Textured terrain extends over the full period. These are soft material
	// transitions, never hard grid lines, a donut collider, or a giant platform.
	vec3 field_color = field.rgb * mix(0.73, 0.91, patch);
	field_color *= mix(vec3(0.93, 0.98, 1.0), vec3(1.02, 1.0, 0.92), patch);
	field_color *= 1.0 - shoulder * 0.16;
	vec3 road_color = paving.rgb * mix(0.94, 1.05, patch);
	COLOR = vec4(mix(field_color, road_color, road * 0.89), 1.0);
}
