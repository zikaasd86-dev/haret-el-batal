extends Control
## لوحة لمس متعددة الأصابع: جويستك شفاف أقصى اليسار + أزرار دائرية أنيقة أقصى اليمين

const JOY_OUTER_R := 22.0
const JOY_KNOB_R := 9.0
const JOY_DEADZONE := 0.22
const BTN_R := 15.5
const WPN_R := 10.0

var _joy_center := Vector2(36.0, 144.0)
var _joy_knob := Vector2.ZERO
var _joy_touch_id: int = -1

var _fire_center := Vector2(268.0, 152.0)
var _jump_center := Vector2(300.0, 134.0)
var _wpn_center := Vector2(298.0, 102.0)

var _fire_touch_id: int = -1
var _jump_touch_id: int = -1
var _wpn_touch_id: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_layout()
	get_viewport().size_changed.connect(_update_layout)


func _update_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	# الجويستك في الزاوية السفلى اليسرى بعيداً عن البطل
	_joy_center = Vector2(34.0, vp.y - 32.0)
	# الأزرار الدائرية في الزاوية السفلى اليمنى بزاوية مريحة للإبهام
	_jump_center = Vector2(vp.x - 24.0, vp.y - 38.0)
	_fire_center = Vector2(vp.x - 56.0, vp.y - 24.0)
	_wpn_center = Vector2(vp.x - 24.0, vp.y - 72.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if get_tree().paused or GameState.is_game_over or GameState.is_level_cleared:
		_release_all()
		return

	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		var idx: int = event.index
		if event.pressed:
			# فحص الأزرار الدائرية أولاً
			if _fire_touch_id == -1 and pos.distance_to(_fire_center) <= BTN_R + 7.0:
				_fire_touch_id = idx
				Input.action_press("fire")
				queue_redraw()
			elif _jump_touch_id == -1 and pos.distance_to(_jump_center) <= BTN_R + 7.0:
				_jump_touch_id = idx
				Input.action_press("jump")
				queue_redraw()
			elif _wpn_touch_id == -1 and pos.distance_to(_wpn_center) <= WPN_R + 6.0:
				_wpn_touch_id = idx
				Input.action_press("switch_weapon")
				queue_redraw()
			# النصف الأيسر من الشاشة (أسفل) يفعّل الجويستك بسلاسة
			elif _joy_touch_id == -1 and pos.x < get_viewport().get_visible_rect().size.x * 0.45 and pos.y > 40.0:
				_joy_touch_id = idx
				_update_joystick(pos)
		else:
			if idx == _joy_touch_id:
				_joy_touch_id = -1
				_joy_knob = Vector2.ZERO
				_apply_joy_actions(Vector2.ZERO)
				queue_redraw()
			if idx == _fire_touch_id:
				_fire_touch_id = -1
				Input.action_release("fire")
				queue_redraw()
			if idx == _jump_touch_id:
				_jump_touch_id = -1
				Input.action_release("jump")
				queue_redraw()
			if idx == _wpn_touch_id:
				_wpn_touch_id = -1
				Input.action_release("switch_weapon")
				queue_redraw()

	elif event is InputEventScreenDrag:
		if event.index == _joy_touch_id:
			_update_joystick(event.position)


func _update_joystick(touch_pos: Vector2) -> void:
	var delta := touch_pos - _joy_center
	if delta.length() > JOY_OUTER_R:
		delta = delta.normalized() * JOY_OUTER_R
	_joy_knob = delta
	_apply_joy_actions(delta / JOY_OUTER_R)
	queue_redraw()


func _apply_joy_actions(vec: Vector2) -> void:
	_set_action("move_left", vec.x < -JOY_DEADZONE)
	_set_action("move_right", vec.x > JOY_DEADZONE)
	_set_action("aim_up", vec.y < -JOY_DEADZONE)
	_set_action("aim_down", vec.y > JOY_DEADZONE)


func _set_action(action_name: String, pressed: bool) -> void:
	if pressed and not Input.is_action_pressed(action_name):
		Input.action_press(action_name)
	elif not pressed and Input.is_action_pressed(action_name):
		Input.action_release(action_name)


func _release_all() -> void:
	if _joy_touch_id != -1 or _fire_touch_id != -1 or _jump_touch_id != -1 or _wpn_touch_id != -1:
		_joy_touch_id = -1
		_fire_touch_id = -1
		_jump_touch_id = -1
		_wpn_touch_id = -1
		_joy_knob = Vector2.ZERO
		for act in ["move_left", "move_right", "aim_up", "aim_down", "fire", "jump", "switch_weapon"]:
			if Input.is_action_pressed(act):
				Input.action_release(act)
		queue_redraw()


func _draw() -> void:
	# 1. الجويستك الافتراضي الشفاف (حلقة خارجية ناعمة + كرة داخلية)
	draw_circle(_joy_center, JOY_OUTER_R, Color(0.10, 0.08, 0.06, 0.24))
	draw_arc(_joy_center, JOY_OUTER_R, 0.0, TAU, 32, Color(1.0, 0.96, 0.90, 0.42), 1.4, true)
	# نقاط خفيفة للاتجاهات الأربعة داخل الجويستك
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_circle(_joy_center + d * (JOY_OUTER_R - 5.0), 1.2, Color(1.0, 0.96, 0.90, 0.35))

	var knob_pos := _joy_center + _joy_knob
	var knob_col := Color(0.96, 0.72, 0.18, 0.72) if _joy_touch_id != -1 else Color(1.0, 0.96, 0.90, 0.48)
	draw_circle(knob_pos, JOY_KNOB_R, knob_col)
	draw_arc(knob_pos, JOY_KNOB_R, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.75), 1.0, true)

	# 2. زر إطلاق النار الدائري الشفاف (مع رمز تصويب Crosshair)
	var fire_fill := Color(0.92, 0.22, 0.22, 0.65) if _fire_touch_id != -1 else Color(0.88, 0.19, 0.19, 0.34)
	draw_circle(_fire_center, BTN_R, fire_fill)
	draw_arc(_fire_center, BTN_R, 0.0, TAU, 32, Color(1.0, 0.85, 0.80, 0.72), 1.5, true)
	# رمز تصويب داخل زر النار
	draw_arc(_fire_center, 5.5, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 1.2, true)
	draw_line(_fire_center + Vector2(-8, 0), _fire_center + Vector2(-3, 0), Color(1, 1, 1, 0.9), 1.2)
	draw_line(_fire_center + Vector2(3, 0), _fire_center + Vector2(8, 0), Color(1, 1, 1, 0.9), 1.2)
	draw_line(_fire_center + Vector2(0, -8), _fire_center + Vector2(0, -3), Color(1, 1, 1, 0.9), 1.2)
	draw_line(_fire_center + Vector2(0, 3), _fire_center + Vector2(0, 8), Color(1, 1, 1, 0.9), 1.2)

	# 3. زر القفز الدائري الشفاف (مع سهم صاعد أنيق)
	var jump_fill := Color(0.28, 0.65, 0.42, 0.68) if _jump_touch_id != -1 else Color(0.22, 0.48, 0.32, 0.36)
	draw_circle(_jump_center, BTN_R, jump_fill)
	draw_arc(_jump_center, BTN_R, 0.0, TAU, 32, Color(0.85, 1.0, 0.88, 0.72), 1.5, true)
	# سهم قفز مزدوج أنيق داخل الزر
	draw_polyline(PackedVector2Array([
		_jump_center + Vector2(-5.5, 1.0),
		_jump_center + Vector2(0.0, -5.0),
		_jump_center + Vector2(5.5, 1.0)
	]), Color(1, 1, 1, 0.92), 1.8, true)
	draw_polyline(PackedVector2Array([
		_jump_center + Vector2(-4.0, 5.5),
		_jump_center + Vector2(0.0, 1.0),
		_jump_center + Vector2(4.0, 5.5)
	]), Color(1, 1, 1, 0.65), 1.4, true)

	# 4. زر تبديل السلاح الصغير (دائرة ذهبية شفافة)
	var wpn_fill := Color(0.96, 0.72, 0.18, 0.75) if _wpn_touch_id != -1 else Color(0.80, 0.55, 0.15, 0.34)
	draw_circle(_wpn_center, WPN_R, wpn_fill)
	draw_arc(_wpn_center, WPN_R, 0.0, TAU, 24, Color(1.0, 0.92, 0.70, 0.75), 1.2, true)
	draw_line(_wpn_center + Vector2(-4.5, 0), _wpn_center + Vector2(4.5, 0), Color(1, 1, 1, 0.9), 2.0)
	draw_line(_wpn_center + Vector2(1.5, -3), _wpn_center + Vector2(4.5, 0), Color(1, 1, 1, 0.9), 1.3)
	draw_line(_wpn_center + Vector2(1.5, 3), _wpn_center + Vector2(4.5, 0), Color(1, 1, 1, 0.9), 1.3)
