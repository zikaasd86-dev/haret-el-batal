class_name ProceduralArt
extends RefCounted
## مولّد رسومات بكسل آرت أصلية من مصفوفات نصية (ASCII Pixel Maps)
## يضمن أصالة 100% وحجماً صغيراً جداً للمشروع (< 50MB)

static var _cache: Dictionary = {}

## يحول مصفوفة أسطر نصية إلى ImageTexture بدقة بكسل حادة
static func create_texture(cache_key: String, rows: PackedStringArray) -> ImageTexture:
	if _cache.has(cache_key):
		return _cache[cache_key]

	var height := rows.size()
	var width := rows[0].length() if height > 0 else 1
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var cmap := Palette.get_color_map()

	for y in range(height):
		var row := rows[y]
		for x in range(min(width, row.length())):
			var ch := row[x]
			var col: Color = cmap.get(ch, Color(0, 0, 0, 0))
			img.set_pixel(x, y, col)

	var tex := ImageTexture.create_from_image(img)
	_cache[cache_key] = tex
	return tex


## ينشئ مستطيلاً بسيطاً بلون وإطار لاستخدامه في الأزرار أو العناصر السريعة
static func create_rect_texture(cache_key: String, w: int, h: int, fill: Color, border: Color = Color(0, 0, 0, 0)) -> ImageTexture:
	if _cache.has(cache_key):
		return _cache[cache_key]

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	if border.a > 0.0:
		for x in range(w):
			img.set_pixel(x, 0, border)
			img.set_pixel(x, h - 1, border)
		for y in range(h):
			img.set_pixel(0, y, border)
			img.set_pixel(w - 1, y, border)

	var tex := ImageTexture.create_from_image(img)
	_cache[cache_key] = tex
	return tex
