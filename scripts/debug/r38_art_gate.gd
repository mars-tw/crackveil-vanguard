extends Node

const LIBRARY := preload("res://scripts/animation/true_animation_library.gd")
const VISUAL := preload("res://scripts/player/player_visual.gd")
const MANIFEST_PATH := "res://assets/art/r38/source_manifest.json"
var failures: Array[String] = []
var impact_count := 0
var early_impact := false
var observed_visual: Node = null


func _ready() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("R38_ART_FAIL: " + message)


func _image_hash(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()


func _on_impact() -> void:
	impact_count += 1
	if observed_visual == null or observed_visual.animated_sprite.frame != 2:
		early_impact = true


func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_check(int(manifest.get("original_actor_count", 0)) == 9 and int(manifest.get("original_pose_count", 0)) == 144, "original content count")
	_check(str(manifest.get("generation_mode", "")) == "built_in_imagegen", "source generation provenance")
	_check(LIBRARY.CHARACTER_INDEX.size() == 17 and LIBRARY.EXTERNAL_CHARACTER_INDEX.size() == 9, "legacy and external registries mixed")
	var old_frames: SpriteFrames = LIBRARY.get_sprite_frames("res://assets/sprites/hero_captain.png")
	var old_atlas: Texture2D = old_frames.get_frame_texture(&"idle", 0).atlas
	var shared_id := LIBRARY.get_shared_atlas_instance_id()
	_check(old_frames.has_animation(&"attack_combo_finisher") and old_frames.get_frame_count(&"attack_combo_finisher") == 6, "Captain combo lost")
	var external_id := LIBRARY.get_external_atlas_instance_id()
	_check(external_id != 0 and external_id != shared_id, "external sprites reused legacy atlas")
	for actor in manifest["actors"]:
		var actor_id := str(actor["id"])
		var path := "res://assets/sprites/%s.png" % actor_id
		_check(ResourceLoader.exists(path) and LIBRARY.has_character(path), "missing original actor icon or registry " + actor_id)
		_check(int(actor["source_alpha_nonzero"]) == int(actor["extracted_alpha_nonzero"]) and int(actor["source_alpha_sum"]) == int(actor["extracted_alpha_sum"]), "source alpha lost during extraction " + actor_id)
		_check(int(actor["unique_original_poses"]) == 16 and int(actor["walk_unique_poses"]) == 4 and int(actor["attack_unique_poses"]) == 6, "unarticulated body poses " + actor_id)
		var frames: SpriteFrames = LIBRARY.get_sprite_frames(path)
		_check(frames != null, "could not load frames " + actor_id)
		if frames == null:
			continue
		var atlas: Texture2D = (frames.get_frame_texture(&"idle", 0) as AtlasTexture).atlas
		_check(atlas.get_instance_id() == external_id and atlas != old_atlas, "actor escaped external atlas " + actor_id)
		var atlas_image: Image = atlas.get_image()
		var all_hashes := {}
		for state in LIBRARY.STATE_ORDER:
			_check(frames.get_frame_count(state) == int(LIBRARY.FRAME_COUNTS[state]), "playback frame count " + actor_id + " " + str(state))
			var state_hashes := {}
			for frame_index in range(frames.get_frame_count(state)):
				var region: Rect2 = (frames.get_frame_texture(state, frame_index) as AtlasTexture).region
				var image := atlas_image.get_region(Rect2i(region))
				_check(not image.is_invisible(), "blank body pose " + actor_id)
				var frame_hash := _image_hash(image)
				state_hashes[frame_hash] = true
				all_hashes[frame_hash] = true
			var expected_unique: int = 2 if state in [&"idle", &"hurt", &"death"] else 4 if state == &"walk" else 6
			_check(state_hashes.size() == expected_unique, "missing actual distinct pose pixels " + actor_id + " " + str(state))
		_check(all_hashes.size() == 16, "runtime did not preserve sixteen original poses " + actor_id)
		if actor_id.begins_with("hero_"):
			var host := CharacterBody2D.new()
			add_child(host)
			var visual := VISUAL.new()
			host.add_child(visual)
			visual.configure_visual(path, 1.0, 14.0)
			observed_visual = visual
			impact_count = 0
			early_impact = false
			visual.attack_impact.connect(_on_impact)
			_check(visual.play_attack(), "actual attack animation failed " + actor_id)
			await get_tree().create_timer(0.11).timeout
			_check(impact_count == 0, "damage before impact frame " + actor_id)
			await get_tree().create_timer(0.12).timeout
			_check(impact_count == 1 and not early_impact, "impact did not fire once at actual frame 2 " + actor_id)
			await get_tree().create_timer(0.34).timeout
			_check(impact_count == 1 and visual.get_animation_state() == &"idle", "attack failed recovery " + actor_id)
			host.queue_free()
		print("R38_ART_ACTOR id=%s original=16 walk=4 attack=6 playback=27 alpha_preserved=true" % actor_id)
	_check(LIBRARY.get_shared_atlas_instance_id() == shared_id, "legacy atlas identity changed")
	if failures.is_empty():
		print("R38_ART_GATE_PASS actors=9 original_poses=144 external_atlas=true legacy17_preserved=true three_hero_impact_frame2=true")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
