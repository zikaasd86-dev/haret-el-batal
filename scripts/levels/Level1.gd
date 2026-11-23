extends Node2D
## المرحلة الأولى: "حارة البطل" (Level 1)
## حارة شعبية مصرية (أزقة، أسطح، أكشاك، صناديق خشبية) باستخدام TileMapLayer
## كاميرا جانبية تتبع البطل أفقياً وتثبت عند ساحة الزعيم

const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const CRATE_SCENE := preload("res://scenes/levels/PickupCrate.tscn")

const TILE_SIZE := 16
const LEVEL_TILES_W := 80 # 1280 بكسل عرض المرحلة
const GROUND_ROW := 10    # الصف 10 = y=160
const BOSS_TRIGGER_X := 980.0
const BOSS_CAM_X := 1120.0

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
	GameState.reset_run()
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
	camera.global_position = Vector2(160, 90)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	var half_w := get_viewport().get_visible_rect().size.x * 0.5
	var max_cam_x := float(LEVEL_TILES_W * TILE_SIZE) - half_w
	var boss_cam_x := max_cam_x

	# تثبيت الكاميرا عند دخول ساحة الزعيم
	if not _boss_locked and player.global_position.x >= BOSS_TRIGGER_X:
		_boss_locked = true
		if is_instance_valid(boss) and boss.has_method("activate"):
			boss.activate()

	var target_x: float
	if _boss_locked:
		target_x = boss_cam_x
		# منع البطل من الخروج يسار ساحة الزعيم
		player.global_position.x = maxf(player.global_position.x, boss_cam_x - half_w + 8.0)
	else:
		target_x = clampf(player.global_position.x + 28.0, half_w, boss_cam_x)

	camera.global_position.x = lerpf(camera.global_position.x, target_x, minf(1.0, delta * 8.0))
	camera.global_position.y = 90.0

	# اهتزاز الكاميرا عند الانفجارات
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


## رسم خلفية الحارة المصرية (سماء غسق دافئة، مباني، نوافذ مضيئة، فوانيس معلقة)
func _draw() -> void:
	var level_w := float(LEVEL_TILES_W * TILE_SIZE)
	# سماء الغسق الدافئة
	draw_rect(Rect2(0, 0, level_w, 180), Palette.C_TEAL)
	draw_rect(Rect2(0, 56, level_w, 60), Palette.C_SAND.lerp(Palette.C_TEAL, 0.45))
	draw_rect(Rect2(0, 108, level_w, 72), Palette.C_DARK_BROWN)

	# مباني الحارة الخلفية بألوان دافئة (بني، طوبي، رملي، أخضر داكن)
	var b_x := 8.0
	var idx := 0
	while b_x < level_w - 40.0:
		var bw := 44.0 + float((idx * 17) % 28)
		var bh := 72.0 + float((idx * 23) % 42)
		var by := 160.0 - bh
		var wall_col := Palette.C_SAND if (idx % 3 == 0) else (Palette.C_BRICK if (idx % 3 == 1) else Palette.C_WOOD)
		draw_rect(Rect2(b_x, by, bw, bh), wall_col.darkened(0.28))
		draw_rect(Rect2(b_x, by, bw, 4), Palette.C_DARK_BROWN)

		# نوافذ وشرفات خضراء داكنة مع إضاءة دافئة
		var wy := by + 12.0
		while wy < 142.0:
			var wx := b_x + 7.0
			while wx < b_x + bw - 12.0:
				var lit := ((idx + int(wx + wy)) % 2 == 0)
				draw_rect(Rect2(wx, wy, 7, 10), Palette.C_DARK_GREEN)
				draw_rect(Rect2(wx + 1, wy + 1, 5, 7), Palette.C_GOLD if lit else Palette.C_BLACK)
				wx += 14.0
			wy += 20.0

		# حبل زينة/فوانيس بين المباني
		if idx % 2 == 0:
			var lx := b_x + bw + 4.0
			draw_line(Vector2(b_x + bw, by + 16), Vector2(b_x + bw + 14, by + 22), Palette.C_DARK_BROWN, 1.0)
			draw_rect(Rect2(lx, by + 20, 4, 6), Palette.C_GOLD)
			draw_rect(Rect2(lx + 1, by + 21, 2, 4), Palette.C_CREAM)

		b_x += bw + 10.0
		idx += 1


## إنشاء TileSet برمجي من 4 بلاطات بكسل آرت أصلية (16×16 لكل بلاطة)
func _setup_tilesets() -> void:
	var atlas_img := Image.create(64, 16, false, Image.FORMAT_RGBA8)

	# 0: أرضية الحارة (حجر رملي مرصوف)
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

	# 1: جدار طوبي/منصة صلبة
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

	# 2: صندوق خشبي (منصة قابلة للقفز من أسفل)
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

	# 3: مظلة كشك / سطح أخضر داكن (منصة أحادية الاتجاه)
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

	# TileSet للأرضية والجدران الصلبة (Layer 1: World)
	solid_tiles.tile_set = _create_tileset(atlas_tex, 1, false)
	# TileSet للأكشاك والصناديق (Layer 6: OneWayPlatform)
	platform_tiles.tile_set = _create_tileset(atlas_tex, 32, true)


func _create_tileset(atlas_tex: Texture2D, col_layer: int, one_way: bool) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, col_layer)
	ts.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	# مهم جداً في Godot 4: يجب إضافة الـ Source للـ TileSet قبل إنشاء البلاطات ومضلعات التصادم
	ts.add_source(source, 0)

	for i in range(4):
		var coords := Vector2i(i, 0)
		source.create_tile(coords)
		var data := source.get_tile_data(coords, 0)
		if one_way:
			# تصادم في الثلث العلوي فقط كمنصة أحادية الاتجاه
			var poly := PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8),
				Vector2(8, -2), Vector2(-8, -2)
			])
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, poly)
			data.set_collision_polygon_one_way(0, 0, true)
		else:
			var poly := PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8),
				Vector2(8, 8), Vector2(-8, 8)
			])
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, poly)

	return ts


func _blit_tile(dst: Image, offset_x: int, rows: PackedStringArray) -> void:
	var cmap := Palette.get_color_map()
	for y in range(16):
		var row := rows[y]
		for x in range(16):
			var col: Color = cmap.get(row[x], Color(0, 0, 0, 0))
			dst.set_pixel(offset_x + x, y, col)


## بناء تخطيط المرحلة الأولى (حارة مصرية + صناديق + أكشاك + أسطح + ساحة الزعيم)
func _build_alley_layout() -> void:
	# 1. أرضية الشارع مع فجوة صغيرة للقفز في المنتصف
	for x in range(LEVEL_TILES_W):
		if x in [28, 29, 49, 50]:
			continue # فجوات بسيطة (مجاري/حفر في الزقاق)
		solid_tiles.set_cell(Vector2i(x, GROUND_ROW), 0, Vector2i(0, 0))
		solid_tiles.set_cell(Vector2i(x, GROUND_ROW + 1), 0, Vector2i(1, 0))

	# 2. جدار حدود يسار المرحلة
	for y in range(0, GROUND_ROW):
		solid_tiles.set_cell(Vector2i(-1, y), 0, Vector2i(1, 0))

	# 3. صناديق خشبية وأكشاك على طول الحارة (منصات أحادية الاتجاه)
	# بداية الحارة: صناديق وكشك شاي
	platform_tiles.set_cell(Vector2i(8, 9), 0, Vector2i(2, 0))
	platform_tiles.set_cell(Vector2i(9, 9), 0, Vector2i(2, 0))
	for x in range(12, 16):
		platform_tiles.set_cell(Vector2i(x, 7), 0, Vector2i(3, 0))

	# أسطح منازل منخفضة
	for x in range(20, 26):
		platform_tiles.set_cell(Vector2i(x, 6), 0, Vector2i(3, 0))
	platform_tiles.set_cell(Vector2i(24, 9), 0, Vector2i(2, 0))

	# بعد الفجوة الأولى: درج صناديق + سطح كشك
	platform_tiles.set_cell(Vector2i(32, 9), 0, Vector2i(2, 0))
	platform_tiles.set_cell(Vector2i(33, 8), 0, Vector2i(2, 0))
	for x in range(36, 43):
		platform_tiles.set_cell(Vector2i(x, 6), 0, Vector2i(3, 0))

	# قبل الفجوة الثانية وبعدها
	for x in range(46, 54):
		platform_tiles.set_cell(Vector2i(x, 7), 0, Vector2i(3, 0))
	platform_tiles.set_cell(Vector2i(56, 9), 0, Vector2i(2, 0))
	platform_tiles.set_cell(Vector2i(57, 9), 0, Vector2i(2, 0))

	# ساحة الزعيم (منصتان للتصويب على النواة الحمراء وتفادي الطلقات)
	for x in range(65, 69):
		platform_tiles.set_cell(Vector2i(x, 7), 0, Vector2i(2, 0))
	for x in range(70, 73):
		platform_tiles.set_cell(Vector2i(x, 5), 0, Vector2i(3, 0))


## إنشاء تصادمات فيزيائية صلبة (StaticBody2D) للأرضية والمنصات لضمان عدم السقوط أبداً
func _build_physics_colliders() -> void:
	# 1. الأرضية الصلبة (Layer 1: World) مقسّمة حول الفجوتين [28..29] و [49..50]
	var ground_body := StaticBody2D.new()
	ground_body.name = "GroundColliders"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	add_child(ground_body)

	var ground_segments := [
		[0, 28],    # من البداية حتى الفجوة الأولى
		[30, 49],   # بين الفجوتين
		[51, 80],   # حتى نهاية ساحة الزعيم
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

	# جدار يسار المرحلة
	var wall_cs := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(16.0, 200.0)
	wall_cs.shape = wall_rect
	wall_cs.position = Vector2(-8.0, 80.0)
	ground_body.add_child(wall_cs)

	# 2. المنصات أحادية الاتجاه (Layer 6: OneWayPlatform = 32)
	var plat_body := StaticBody2D.new()
	plat_body.name = "PlatformColliders"
	plat_body.collision_layer = 32
	plat_body.collision_mask = 0
	add_child(plat_body)

	var one_way_spans := [
		[8, 10, 9],   # صناديق بداية الحارة
		[12, 16, 7],  # كشك الشاي
		[20, 26, 6],  # أسطح منازل
		[24, 25, 9],  # صندوق
		[32, 33, 9],  # درج صناديق 1
		[33, 34, 8],  # درج صناديق 2
		[36, 43, 6],  # سطح كشك
		[46, 54, 7],  # جسر فوق الفجوة الثانية
		[56, 58, 9],  # صناديق
		[65, 69, 7],  # منصة ساحة الزعيم 1
		[70, 73, 5],  # منصة ساحة الزعيم 2
	]
	for span in one_way_spans:
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


## توزيع الأعداء الثلاثة (يمشي، يطلق النار، يقفز) على امتداد الحارة
func _spawn_enemies() -> void:
	var spawns := [
		# [نوع العدو (0=يمشي, 1=يطلق نار, 2=يقفز), X بالبكسل, Y بالبكسل]
		[0, 220.0, 158.0],
		[1, 224.0, 110.0],
		[0, 360.0, 94.0],
		[2, 415.0, 158.0],
		[1, 535.0, 126.0],
		[0, 625.0, 94.0],
		[2, 690.0, 158.0],
		[1, 795.0, 110.0],
		[0, 880.0, 158.0],
		[2, 935.0, 158.0],
	]

	for entry in spawns:
		var enemy := ENEMY_SCENE.instantiate()
		enemy.enemy_type = entry[0]
		enemy.position = Vector2(entry[1], entry[2])
		enemies_root.add_child(enemy)


## توزيع صناديق الإمداد (سلاح متفرق، قلب صحة، سلاح ثقيل قبل الزعيم)
func _spawn_supply_crates() -> void:
	var crates := [
		[0, 300.0, 160.0], # صندوق السلاح المتفرق
		[2, 650.0, 96.0],  # صندوق صحة على السطح
		[1, 955.0, 160.0], # صندوق السلاح الثقيل قبل ساحة الزعيم
	]
	for entry in crates:
		var crate := CRATE_SCENE.instantiate()
		crate.reward_type = entry[0]
		crate.position = Vector2(entry[1], entry[2])
		add_child(crate)
