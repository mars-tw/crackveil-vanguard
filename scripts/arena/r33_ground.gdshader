shader_type canvas_item;

uniform sampler2D ground_tex : repeat_enable, filter_linear;
uniform vec2 world_origin = vec2(0.0);
uniform vec2 world_span = vec2(1280.0, 720.0);
uniform vec2 tile_span = vec2(960.0, 768.0);

void fragment() {
	vec2 world = world_origin + UV * world_span;
	// Floor-plane diamonds: projected diagonals match the elliptical seals.
	vec2 plane = vec2(world.x * 0.707 + world.y * 1.05, -world.x * 0.707 + world.y * 1.05);
	vec2 world_uv = plane / tile_span;
	vec4 stone = texture(ground_tex, world_uv);
	// Quiet edge falloff keeps action readable without hiding the material.
	float edge = smoothstep(0.35, 0.82, length((UV - 0.5) * vec2(0.85, 1.10)));
	COLOR = vec4(stone.rgb * (1.0 - edge * 0.13), stone.a);
}
