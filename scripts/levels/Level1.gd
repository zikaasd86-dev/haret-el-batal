extends Node2D
## مرحلة "حارة البطل" — تدعم المرحلة 1 (غسق الحارة 2400px) والمرحلة 2 (أسطح الحارة ليلاً 2400px)
## خلفية 16-bit متعددة الطبقات بألوان ساطعة وتباين قوي + تصادمات صلبة + زعيم طويل 3 مراحل

const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const CRATE_SCENE := preload("res://scenes/levels/PickupCrate.tscn")

const TILE_SIZE := 16
const LEVEL_TILES_W := 280 # 4480 بكسل طول المرحلة (كبيرة وغنية بتشكيلة الأعداء الخمسة!)
const GROUND_ROW := 10     # y = 160
const BOSS_TRIGGER_X := 4120.0

@export var stage_number: int = 1
@export var night_theme: bool = false

var _boss_locked: bool = false
var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0

@onready var solid_tiles: TileMapLayer = $SolidTiles
@onready var platform_tiles: TileMapLayer = $PlatformTiles
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var enemies_root: Node2D = $Enemies
@onready var boss: StaticBody2D = $Boss


func _ready() -> void:
	GameState.prepare_stage(stage_number)
	GameState.screen_shake_requested.connect(_on_screen_shake)
	_setup_tilesets()
	_build_alley_layout()
	_build_physics_colliders()
	_spawn_enemies()
	_spawn_supply_crates()
	_setup_camera()
	queue_redraw()


func _setup_camera() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = LEVEL_TILES_W * TILE_SIZE
	camera.limit_bottom = 180
	camera.global_position = Vector2(180, 90)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	var half_w := get_viewport().get_visible_rect().size.x * 0.5
	var boss_cam_x := float(LEVEL_TILES_W * TILE_SIZE) - half_w

	if not _boss_locked and player.global_position.x >= BOSS_TRIGGER_X:
		_boss_locked = true
		if is_instance_valid(boss) and boss.has_method("activate"):
			boss.activate()

	var target_x: float
	if _boss_locked:
		target_x = boss_cam_x
		# حصر البطل داخل ساحة الزعيم حتى لا يستطيع الوقوف بعيداً وتفادي كل الطلقات
		var min_arena_x := maxf(boss_cam_x - half_w + 16.0, float(LEVEL_TILES_W * TILE_SIZE) - 320.0)
		player.global_position.x = maxf(player.global_position.x, min_arena_x)
	else:
		target_x = clampf(player.global_position.x + 28.0, half_w, boss_cam_x)

	camera.global_position.x = lerpf(camera.global_position.x, target_x, minf(1.0, delta * 8.0))
	camera.global_position.y = 90.0

	if _shake_timer > 0.0:
		_shake_timer -= delta
		camera.offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
	else:
		camera.offset = Vector2.ZERO


func _on_screen_shake(intensity: float, duration: float) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_timer = maxf(_shake_timer, duration)


## رسم خلفية 16-bit غنية بالألوان والتباين (سماء متدرجة + أفق قاهري + عمارات مرتفعة + فوانيس)
func _draw() -> void:
	var level_w := float(LEVEL_TILES_W * TILE_SIZE)

	if night_theme:
		# سماء ليلية ساحرة للمرحلة 2
		draw_rect(Rect2(0, 0, level_w, 58), Palette.SKY_NIGHT_TOP)
		draw_rect(Rect2(0, 56, level_w, 56), Palette.SKY_NIGHT_MID)
		draw_rect(Rect2(0, 110, level_w, 70), Palette.SKY_NIGHT_LOW)
		# نجوم وقمر مضيء على امتداد الأفق
		for s in range(0, int(level_w), 48):
			draw_rect(Rect2(float(s + (s * 7) % 30), float(8 + (s * 13) % 44), 2, 2), Palette.C_CREAM)
		for mx in [240.0, 960.0, 1680.0]:
			draw_circle(Vector2(mx, 30.0), 14.0, Palette.C_CREAM)
			draw_circle(Vector2(mx + 4.0, 27.0), 12.0, Palette.SKY_NIGHT_TOP)
	else:
		# تدرج سماء غسق دافئ 16-bit للمرحلة 1
		draw_rect(Rect2(0, 0, level_w, 46), Palette.SKY_DUSK_TOP)
		draw_rect(Rect2(0, 44, level_w, 48), Palette.SKY_DUSK_MID)
		draw_rect(Rect2(0, 90, level_w, 44), Palette.SKY_DUSK_LOW)
		draw_rect(Rect2(0, 132, level_w, 48), Palette.C_DARK_BROWN)

	# طبقة الأفق البعيد (قباب ومآذن قاهرية داكنة لإعطاء عمق)
	var sx := 24.0
	var s_idx := 0
	while sx < level_w:
		var sil_col := Palette.SKY_NIGHT_TOP.lightened(0.08) if night_theme else Palette.SKY_DUSK_MID.darkened(0.42)
		if s_idx % 2 == 0:
			# مئذنة رشيقة في الأفق
			draw_rect(Rect2(sx, 26, 8, 134), sil_col)
			draw_rect(Rect2(sx - 2, 54, 12, 4), sil_col)
			draw_circle(Vector2(sx + 4, 24), 4.0, sil_col)
		else:
			# قبة بعيدة
			draw_circle(Vector2(sx + 16, 86), 16.0, sil_col)
			draw_rect(Rect2(sx, 86, 32, 74), sil_col)
		sx += 130.0
		s_idx += 1

	# عمارات الحارة المرتفعة (بألوان أغمق قليلاً لتبرز الشخصيات والطلقات بوضوح عالٍ!)
	var b_x := 4.0
	var idx := 0
	while b_x < level_w - 30.0:
		var bw := 50.0 + float((idx * 19) % 26)
		var bh := 118.0 + float((idx * 29) % 38)
		var by := 160.0 - bh
		var wall_col: Color
		if night_theme:
			wall_col = Palette.SKY_NIGHT_MID.darkened(0.22) if idx % 2 == 0 else Palette.C_SLATE.darkened(0.55)
		else:
			var base_c := Palette.C_SAND if (idx % 3 == 0) else (Palette.C_BRICK if (idx % 3 == 1) else Palette.C_WOOD)
			wall_col = base_c.darkened(0.45)

		draw_rect(Rect2(b_x, by, bw, bh), wall_col)
		draw_rect(Rect2(b_x - 1, by, bw + 2, 5), Palette.C_BLACK)
		draw_rect(Rect2(b_x, by + 5, bw, 2), Palette.C_SAND.darkened(0.3))

		var wy := by + 13.0
		while wy < 142.0:
			var wx := b_x + 7.0
			while wx < b_x + bw - 12.0:
				var lit := ((idx + int(wx + wy)) % 3 != 0)
				draw_rect(Rect2(wx, wy, 8, 12), Palette.C_DARK_GREEN.darkened(0.2))
				draw_rect(Rect2(wx + 1, wy + 1, 6, 9), Palette.C_GOLD.darkened(0.1) if lit else Palette.C_BLACK)
				wx += 15.0
			wy += 22.0

		if idx % 2 == 0:
			var lx := b_x + bw + 3.0
			draw_line(Vector2(b_x + bw, by + 20), Vector2(b_x + bw + 14, by + 26), Palette.C_BLACK, 1.0)
			draw_rect(Rect2(lx, by + 24, 5, 7), Palette.C_GOLD)
			draw_rect(Rect2(lx + 1, by + 25, 3, 5), Palette.C_WHITE)

		b_x += bw + 8.0
		idx += 1


func _setup_tilesets() -> void:
	var atlas_img := Image.create(64, 16, false, Image.FORMAT_RGBA8)

	# 0: أرضية الحارة
	_blit_tile(atlas_img, 0, PackedStringArray([
		"5555555555555555",
		"4444441444444414",
		"4454441445444414",
		"4444441444444414",
		"1111111111111111",
		"4414444444144444",
		"4414454444144544",
		"4414444444144444",
		"1111111111111111",
		"2222221222222212",
		"2222221222222212",
		"1111111111111111",
		"1111111111111111",
		"1111111111111111",
		"0000000000000000",
		"0000000000000000",
	]))

	# 1: جدار طوبي
	_blit_tile(atlas_img, 16, PackedStringArray([
		"1111111111111111",
		"3333333133333331",
		"3433333134333331",
		"3333333133333331",
		"1111111111111111",
		"3331333333313333",
		"3431343333313433",
		"3331333333313333",
		"1111111111111111",
		"3333333133333331",
		"3433333134333331",
		"3333333133333331",
		"1111111111111111",
		"3331333333313333",
		"3331333333313333",
		"1111111111111111",
	]))

	# 2: صندوق خشبي
	_blit_tile(atlas_img, 32, PackedStringArray([
		"0000000000000000",
		"0622222222222260",
		"0211111111111120",
		"0214222222221120",
		"0212422222212120",
		"0212242222122120",
		"0212224221222120",
		"0212222412222120",
		"0212222142222120",
		"0212221224222120",
		"0212212222422120",
		"0212122222242120",
		"0211222222224120",
		"0211111111111120",
		"0622222222222260",
		"0000000000000000",
	]))

	# 3: مظلة كشك / سطح أخضر
	_blit_tile(atlas_img, 48, PackedStringArray([
		"0000000000000000",
		"0888558888558880",
		"0888558888558880",
		"0777447777447770",
		"0777447777447770",
		"0000000000000000",
		".010........010.",
		".020........020.",
		".020........020.",
		".020........020.",
		".020........020.",
		".020........020.",
		".020........020.",
		".020........020.",
		".010........010.",
		".000........000.",
	]))

	var atlas_tex := ImageTexture.create_from_image(atlas_img)
	solid_tiles.tile_set = _create_visual_tileset(atlas_tex)
	platform_tiles.tile_set = _create_visual_tileset(atlas_tex)


func _create_visual_tileset(atlas_tex: Texture2D) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.add_source(source, 0)
	for i in range(4):
		source.create_tile(Vector2i(i, 0))
	return ts


func _blit_tile(dst: Image, offset_x: int, rows: PackedStringArray) -> void:
	var cmap := Palette.get_color_map()
	for y in range(16):
		var row := rows[y]
		for x in range(16):
			dst.set_pixel(offset_x + x, y, cmap.get(row[x], Color(0, 0, 0, 0)))


func _build_alley_layout() -> void:
	# 1. أرضية الشارع الطويلة (280 بلاطة = 4480px) مع 7 فجوات قفز موزعة
	for x in range(LEVEL_TILES_W):
		if x in [32, 33, 62, 63, 94, 95, 128, 129, 160, 161, 196, 197, 232, 233]:
			continue
		solid_tiles.set_cell(Vector2i(x, GROUND_ROW), 0, Vector2i(0, 0))
		solid_tiles.set_cell(Vector2i(x, GROUND_ROW + 1), 0, Vector2i(1, 0))

	for y in range(0, GROUND_ROW):
		solid_tiles.set_cell(Vector2i(-1, y), 0, Vector2i(1, 0))

	for span in _get_platform_spans():
		var tile_id: int = span[3]
		for x in range(span[0], span[1]):
			platform_tiles.set_cell(Vector2i(x, span[2]), 0, Vector2i(tile_id, 0))


func _get_platform_spans() -> Array:
	return [
		# منطقة البداية الآمنة (0..22)
		[8, 10, 9, 2],
		[12, 16, 7, 3],
		# المنطقة 1 (350..1200px)
		[22, 28, 6, 3],
		[29, 36, 7, 3],
		[40, 46, 6, 3],
		[48, 50, 9, 2],
		[52, 58, 7, 3],
		# المنطقة 2 (1200..2100px)
		[60, 67, 6, 3],
		[71, 73, 9, 2],
		[75, 82, 7, 3],
		[84, 90, 5, 3],
		[92, 99, 7, 3],
		# المنطقة 3 (2100..3100px)
		[104, 111, 6, 3],
		[114, 116, 9, 2],
		[118, 125, 7, 3],
		[126, 133, 6, 3],
		[138, 145, 7, 3],
		[148, 154, 5, 3],
		[157, 165, 7, 3],
		[169, 175, 6, 3],
		# المنطقة 4 المكثفة (3100..4100px)
		[182, 189, 7, 3],
		[192, 200, 6, 3],
		[204, 210, 5, 3],
		[214, 217, 9, 2],
		[220, 227, 7, 3],
		[230, 237, 6, 3],
		[242, 249, 7, 3],
		# ساحة الزعيم (4120..4480px)
		[261, 265, 7, 2],
		[267, 271, 5, 3],
	]


func _build_physics_colliders() -> void:
	var ground_body := StaticBody2D.new()
	ground_body.name = "GroundColliders"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	add_child(ground_body)

	var ground_segments := [
		[0, 32],
		[34, 62],
		[64, 94],
		[96, 128],
		[130, 160],
		[162, 196],
		[198, 232],
		[234, 280],
	]
	for seg in ground_segments:
		var x1 := float(seg[0] * TILE_SIZE)
		var x2 := float(seg[1] * TILE_SIZE)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(x2 - x1, 32.0)
		cs.shape = rect
		cs.position = Vector2((x1 + x2) * 0.5, float(GROUND_ROW * TILE_SIZE) + 16.0)
		ground_body.add_child(cs)

	var wall_cs := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(16.0, 200.0)
	wall_cs.shape = wall_rect
	wall_cs.position = Vector2(-8.0, 80.0)
	ground_body.add_child(wall_cs)

	var plat_body := StaticBody2D.new()
	plat_body.name = "PlatformColliders"
	plat_body.collision_layer = 32
	plat_body.collision_mask = 0
	add_child(plat_body)

	for span in _get_platform_spans():
		var x1 := float(span[0] * TILE_SIZE)
		var x2 := float(span[1] * TILE_SIZE)
		var y_top := float(span[2] * TILE_SIZE)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(x2 - x1, 6.0)
		cs.shape = rect
		cs.position = Vector2((x1 + x2) * 0.5, y_top + 3.0)
		cs.one_way_collision = true
		plat_body.add_child(cs)


## تشكيلة أعداء متنوعة من 5 أنواع: 0=يمشي، 1=يطلق نار، 2=يقفز، 3=درون طائر، 4=مدرّع ثقيل
func _spawn_enemies() -> void:
	var spawns := [
		[0, 410.0, 94.0],
		[2, 470.0, 158.0],
		[3, 560.0, 56.0],   # درون طائر
		[1, 660.0, 94.0],
		[4, 790.0, 158.0],  # مدرّع ثقيل
		[0, 900.0, 110.0],
		[3, 1040.0, 52.0],  # درون طائر
		[2, 1130.0, 158.0],
		[1, 1260.0, 110.0],
		[4, 1420.0, 158.0], # مدرّع ثقيل
		[3, 1540.0, 58.0],  # درون طائر
		[0, 1710.0, 94.0],
		[2, 1820.0, 158.0],
		[1, 1960.0, 110.0],
		[3, 2100.0, 54.0],  # درون طائر
		[4, 2260.0, 158.0], # مدرّع ثقيل
		[1, 2410.0, 78.0],
		[0, 2600.0, 110.0],
		[3, 2750.0, 52.0],  # درون طائر
		[2, 2940.0, 158.0],
		[4, 3120.0, 158.0], # مدرّع ثقيل
		[1, 3300.0, 78.0],
		[3, 3480.0, 54.0],  # درون طائر
		[2, 3620.0, 158.0],
		[4, 3820.0, 158.0], # مدرّع ثقيل
		[1, 3940.0, 110.0],
		[3, 4020.0, 58.0],  # درون طائر قبل الساحة
	]

	for entry in spawns:
		var enemy := ENEMY_SCENE.instantiate()
		enemy.enemy_type = entry[0]
		if stage_number >= 2:
			enemy.max_hp = 3
		enemy.position = Vector2(entry[1], entry[2])
		enemies_root.add_child(enemy)


func _spawn_supply_crates() -> void:
	var crates := [
		[0, 210.0, 160.0],  # السلاح المتفرق (Spread)
		[3, 620.0, 160.0],  # الليزر المتموج (Wave)
		[2, 960.0, 112.0],  # قلب صحة
		[4, 1340.0, 112.0], # قاذف الشرار الناري (Flame)
		[2, 1740.0, 96.0],  # قلب صحة
		[1, 2320.0, 112.0], # الشعاع الثقيل (Heavy)
		[2, 2860.0, 160.0], # قلب صحة
		[4, 3380.0, 160.0], # قاذف الشرار الناري
		[2, 3760.0, 96.0],  # قلب صحة
		[1, 4070.0, 160.0], # الشعاع الثقيل قبل ساحة الزعيم
	]
	for entry in crates:
		var crate := CRATE_SCENE.instantiate()
		crate.reward_type = entry[0]
		crate.position = Vector2(entry[1], entry[2])
		add_child(crate)
