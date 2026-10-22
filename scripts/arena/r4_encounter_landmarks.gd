extends Node2D

const ATLAS:=preload("res://assets/art/r36/landmarks.png")
var props: Array[Sprite2D]=[]
var composition:=""
var atlas_indices: Array[int]=[]

func _ready() -> void:
	z_index=-1
	for number in range(2):
		var sprite:=Sprite2D.new()
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.centered=false
		add_child(sprite)
		props.append(sprite)

func _set_prop(number: int,index: int,position: Vector2,span: float) -> void:
	var region:=AtlasTexture.new()
	region.atlas=ATLAS
	var size:=ATLAS.get_size()/Vector2(4,2)
	region.region=Rect2(Vector2(index%4,index/4)*size,size)
	props[number].texture=region
	props[number].offset=Vector2(-size.x*0.5,-size.y*0.82)
	props[number].scale=Vector2.ONE*span/maxf(size.x,size.y)
	props[number].position=position
	props[number].show()

func _process(_delta: float) -> void:
	var director: Node=GameManager.tactical_director
	visible=GameManager.run_mode=="campaign" and is_instance_valid(director) and is_instance_valid(director.relay)
	if not visible:return
	var relay: Node=director.relay
	var next: String="boss" if relay.completed else str(relay.pressure.kind)
	var anchor: Vector2=relay.anchor
	if GameManager.boss_active:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.get("is_boss")==true and enemy.get("is_dying")!=true:anchor=enemy.global_position;break
	if next!=composition:
		composition=next
		for prop in props:prop.hide()
		match composition:
			"front":atlas_indices=[0];_set_prop(0,0,Vector2.ZERO,260)
			"pincer":atlas_indices=[2,2];_set_prop(0,2,Vector2.ZERO,180);_set_prop(1,2,Vector2.ZERO,180)
			"artillery":atlas_indices=[5,3];_set_prop(0,5,Vector2.ZERO,210);_set_prop(1,3,Vector2.ZERO,110)
			"boss":atlas_indices=[6];_set_prop(0,6,Vector2.ZERO,310)
	var offsets: Array=[Vector2(0,-110),Vector2.ZERO]
	if composition=="pincer":offsets=[Vector2(-160,-70),Vector2(160,-70)]
	elif composition=="artillery":offsets=[Vector2(120,-110),Vector2(-125,-75)]
	for number in range(atlas_indices.size()):props[number].global_position=anchor+offsets[number]
