extends Node

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const DEATH_BURST_SCENE := preload("res://scenes/vfx/DeathBurst.tscn")
const EXPLOSION_SCENE := preload("res://scenes/projectiles/ExplosionArea.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const LEVEL_UP_SCENE := preload("res://scenes/ui/LevelUpScreen.tscn")
const STAGE_VICTORY_SCENE := preload("res://scenes/ui/StageVictoryScreen.tscn")
var failed: bool = false


func _ready() -> void:
	_test_mobile_composite_contract()
	_test_death_composites()
	_test_explosion_composite()
	_test_weapon_growth_stats()
	_test_boss_volume_and_projectile()
	_test_ui_motion()
	if failed:
		print("M4_REGRESSION_FAIL")
		get_tree().quit(1)
	else:
		print("M4_REGRESSION_PASS")
		get_tree().quit(0)


func _test_mobile_composite_contract() -> void:
	MOBILE_TUNING.set_force_mobile_lod_for_tests(false)
	_assert(MOBILE_TUNING.vfx_composite_layer_count(Vector2(1280.0, 720.0)) == 4, "desktop composite must keep four layers")
	MOBILE_TUNING.set_force_mobile_lod_for_tests(true)
	_assert(MOBILE_TUNING.vfx_composite_layer_count(Vector2(390.0, 844.0)) == 2, "mobile composite must drop to two detail layers")
	MOBILE_TUNING.set_force_mobile_lod_for_tests(false)


func _test_death_composites() -> void:
	var burst := DEATH_BURST_SCENE.instantiate()
	add_child(burst)
	burst.pool_on_acquire()
	burst.pool_reset({"position": Vector2.ZERO, "color": Color(0.9, 0.42, 1.0), "scale": 2.0, "style": "boss_phase", "particle_multiplier": 1.0, "composite_layers": 4})
	_assert(burst.get_node_or_null("CoreFlash") != null, "death composite missing core")
	_assert(burst.get_node_or_null("ImpactRing") != null, "death composite missing ring")
	_assert(burst.get_node_or_null("Smoke") != null and burst.get_node("Smoke").visible, "desktop death composite missing smoke")
	_assert(burst.get_node_or_null("BurstParticles") != null and burst.get_node("BurstParticles").emitting, "desktop death composite missing debris")
	burst.pool_on_release()
	burst.pool_on_acquire()
	burst.pool_reset({"position": Vector2.ZERO, "color": Color.ORANGE, "scale": 1.0, "style": "elite_death", "particle_multiplier": 0.6, "composite_layers": 2})
	_assert(not burst.get_node("Smoke").visible and not burst.get_node("BurstParticles").emitting, "mobile death composite did not drop smoke/debris")
	burst.queue_free()


func _test_explosion_composite() -> void:
	var explosion := EXPLOSION_SCENE.instantiate()
	add_child(explosion)
	explosion.pool_on_acquire()
	explosion.pool_reset({"position": Vector2.ZERO, "stats": {"area_radius": 90.0, "effect_lifetime": 0.4, "color": Color.ORANGE, "composite_layers": 4, "particle_multiplier": 1.0}, "source": null})
	for child_name in ["CoreFlash", "ShockwaveSprite", "Smoke", "Debris"]:
		_assert(explosion.get_node_or_null(child_name) != null, "explosion composite missing %s" % child_name)
	_assert(explosion.get_node("Smoke").visible and explosion.get_node("Debris").emitting, "desktop explosion layers inactive")
	explosion.queue_free()


func _test_weapon_growth_stats() -> void:
	var weapon: Resource = load("res://resources/weapons/riftline_emitter.tres").make_runtime_copy()
	var base_stats: Dictionary = weapon.to_projectile_stats()
	weapon.apply_upgrade("weapon_damage")
	weapon.apply_upgrade("riftline_fork")
	var upgraded_stats: Dictionary = weapon.to_projectile_stats()
	_assert(int(base_stats.get("visual_level", -1)) == 0, "base weapon visual level incorrect")
	_assert(int(upgraded_stats.get("visual_level", 0)) >= 2, "weapon upgrades are not visible in stats")
	_assert(upgraded_stats.has("evolved_visual"), "weapon evolution visual flag missing")


func _test_boss_volume_and_projectile() -> void:
	var boss := ENEMY_SCENE.instantiate()
	add_child(boss)
	boss.pool_on_acquire()
	boss.pool_reset({"position": Vector2.ZERO, "enemy_id": "boss_test", "spawn_token": 1, "config": {"max_hp": 100.0, "radius": 42.0, "color": Color(0.7, 0.22, 0.86), "sprite_path": "res://assets/sprites/enemy_tank.png", "behavior_id": "boss", "is_boss": true}})
	_assert(boss.get_node("BossInnerGlow").visible and boss.get_node("BossCoreGlow").visible, "boss volume glows inactive")
	var projectile_stats: Dictionary = boss.call("_enemy_projectile_stats")
	_assert(str(projectile_stats.get("source_weapon_id", "")) == "boss_ring", "boss ring projectile lacks dedicated style id")
	_assert(str(projectile_stats.get("projectile_sprite_path", "")).contains("kenney_particle"), "boss ring projectile lacks dedicated texture")
	boss.queue_free()


func _test_ui_motion() -> void:
	var level_screen := LEVEL_UP_SCENE.instantiate()
	add_child(level_screen)
	level_screen.show_options([{"name": "測試升級", "description": "看得見成長", "upgrade_category": "evolution"}])
	level_screen.call("_animate_cards_in")
	var buttons: Array = level_screen.get("option_buttons")
	_assert(buttons.size() == 1, "upgrade card entry animation has no card")
	level_screen.call("_set_pending_mobile_confirm", buttons[0], Time.get_ticks_msec())
	_assert(buttons[0].has_meta("selection_tween"), "selected card glow tween missing")
	level_screen.queue_free()

	var victory_screen := STAGE_VICTORY_SCENE.instantiate()
	add_child(victory_screen)
	victory_screen.show_summary({"elapsed_time": 210.0, "kills": 320, "elites_killed": 3, "gold": 92, "echo_progress": {"shards": 12}})
	var count_tween: Tween = victory_screen.get("summary_tween")
	_assert(count_tween != null and count_tween.is_valid(), "result count-up tween missing")
	victory_screen.queue_free()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("M4 regression: " + message)
