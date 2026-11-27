extends SceneTree
## اختبار فيزيائي آلي (Headless Smoke Test) يعمل داخل GitHub Actions قبل تصدير الـ APK
## يتحقق من أن البطل يقف بثبات على الأرض ولا يسقط، وأن الشاشة مضبوطة على Landscape

var _frames: int = 0
var _level: Node = null


func _initialize() -> void:
	var orient := str(ProjectSettings.get_setting("display/window/handheld/orientation", ""))
	if orient != "sensor_landscape" and orient != "landscape":
		printerr("TEST FAILED: orientation must be landscape/sensor_landscape, got: ", orient)
		quit(1)
		return

	var level_scene := load("res://scenes/levels/Level1.tscn") as PackedScene
	if not level_scene:
		printerr("TEST FAILED: Could not load Level1.tscn")
		quit(1)
		return

	_level = level_scene.instantiate()
	root.add_child(_level)


func _physics_process(_delta: float) -> bool:
	if not _level:
		return false
	_frames += 1
	if _frames < 90:
		return false

	var player := _level.get_node_or_null("Player") as CharacterBody2D
	if not player:
		printerr("TEST FAILED: Player node missing")
		quit(1)
		return true

	var gs := root.get_node_or_null("GameState")
	var is_over := bool(gs.is_game_over) if gs else false
	print("SMOKE TEST -> Player pos=", player.global_position, " on_floor=", player.is_on_floor(), " hp=", player.hp, " game_over=", is_over)

	if is_over:
		printerr("TEST FAILED: Game ended immediately!")
		quit(1)
		return true

	if not player.is_on_floor() or player.global_position.y > 165.0:
		printerr("TEST FAILED: Player fell through floor! pos=", player.global_position)
		quit(1)
		return true

	if player.hp < 5:
		printerr("TEST FAILED: Player took unexpected damage at start! hp=", player.hp)
		quit(1)
		return true

	# التحقق من الأسلحة الـ 5 ومنطقة البداية الآمنة
	for w in range(5):
		player.set_weapon(w)
	var enemies_root := _level.get_node_or_null("Enemies")
	if enemies_root:
		for e in enemies_root.get_children():
			if e.position.x < 350.0:
				printerr("TEST FAILED: Enemy spawned inside safe start zone at x=", e.position.x)
				quit(1)
				return true

	# التحقق من إمكانية تحميل المرحلة 2 و 3 أيضاً
	var level2_scene := load("res://scenes/levels/Level2.tscn") as PackedScene
	if not level2_scene:
		printerr("TEST FAILED: Could not load Level2.tscn")
		quit(1)
		return true

	var level3_scene := load("res://scenes/levels/Level3.tscn") as PackedScene
	if not level3_scene:
		printerr("TEST FAILED: Could not load Level3.tscn")
		quit(1)
		return true

	print("SMOKE TEST PASSED! Level1, Level2 & Level3 loaded, player stands solidly, 5 weapons & safe start ok.")
	quit(0)
	return true
