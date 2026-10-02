extends SceneTree
const MOBILE = preload("res://scripts/services/mobile_tuning.gd")
func _initialize():
 call_deferred("go")
func go():
 var arena = load("res://scenes/arena/Arena.tscn").instantiate()
 root.add_child(arena)
 await process_frame
 MOBILE.set_device_hints_override_for_tests({"ua_mobile":true,"ua_tablet":true,"touch_available":true,"mouse_available":false})
 var actor = root.get_node("GameManager").player
 print("CAMERA_DIAG raw=",actor._camera_viewport_size()," view=",MOBILE.ui_layout_size(actor._camera_viewport_size())," tier=",MOBILE.layout_tier(actor._camera_viewport_size())," tbl=",MOBILE.LayoutTier.TABLET," heroMOBILE_same=",actor.MOBILE_TUNING==MOBILE," hasloop=",arena.has_node("LoopWorldTopology")," zoom=",actor._leader_camera_zoom())
 quit()
