class_name UITheme
extends RefCounted
## تنسيق واجهة أركيد مصقولة وجذابة (بدل أزرار Godot الرمادية الافتراضية)
## Polished mobile arcade UI styling for Google Play readiness

static func style_button(btn: Button, bg: Color, border: Color, text_col: Color = Color("#fffdf5")) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(0, 2)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.14)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.16)
	pressed.shadow_size = 0
	pressed.shadow_offset = Vector2.ZERO

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", Palette.C_GOLD)


static func style_panel(panel: PanelContainer) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.06, 0.11, 0.90)
	box.border_color = Palette.C_GOLD
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)


static func style_progress_bar(bar: ProgressBar, fill_col: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.08, 0.12, 0.85)
	bg.border_color = Palette.C_CREAM
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	fill.set_corner_radius_all(3)

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
