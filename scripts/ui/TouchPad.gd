extends Control
## لوحة لمس مدمجة وأنيقة (تأخذ أقل مساحة ممكنة مع استجابة لمس دقيقة متعددة الأصابع)

const JOY_OUTER_R := 18.0
const JOY_KNOB_R := 7.5
const JOY_DEADZONE := 0.22
const BTN_R := 12.0
const WPN_R := 8.0

var _joy_center := Vector2(26.0, 154.0)
var _joy_knob := Vector2.ZERO
var _joy_touch_id: int = -1

var _fire_center := Vector2(276.0, 158.0)
var _jump_center := Vector2(302.0, 144.0)
var _wpn_center := Vector2(302.0, 118.0)

var _fire_touch_id: int = -1
var _jump_touch_id: int = -1
var _wpn_touch_id: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_layout()
	get_viewport().size_changed.connect(_update_layout)


func _update_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_joy_center = Vector2(26.0, vp.y - 24.0)
	_jump_center = Vector2(vp.x - 18.0, vp.y - 30.0)
	_fire_center = Vector2(vp.x - 44.0, vp.y - 18.0)
	_wpn_center = Vector2(vp.x - 18.0, vp.y - 54.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if get_tree().paused or GameState.is_game_over or GameState.is_level_cleared:
		_release_all()
		return

	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		var idx: int = event.index
		if event.pressed:
			# منطقة لمس مريحة (+6px) رغم صغر حجم الزر البصري
			if _fire_touch_id == -1 and pos.distance_to(_fire_center) <= BTN_R + 6.0:
				_fire_touch_id = idx
				Input.action_press("fire")
				queue_redraw()
			elif _jump_touch_id == -1 and pos.distance_to(_jump_center) <= BTN_R + 6.0:
				_jump_touch_id = idx
				Input.action_press("jump")
				queue_redraw()
			elif _wpn_touch_id == -1 and pos.distance_to(_wpn_center) <= WPN_R + 5.0:
				_wpn_touch_id = idx
				Input.action_press("switch_weapon")
				queue_redraw()
			elif _joy_touch_id == -1 and pos.x < get_viewport().get_visible_rect().size.x * 0.42 and pos.y > 44.0:
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
	# 1. جويستك شفاف صغير وأنيق
	draw_circle(_joy_center, JOY_OUTER_R, Color(0.08, 0.06, 0.10, 0.16))
	draw_arc(_joy_center, JOY_OUTER_R, 0.0, TAU, 32, Color(1.0, 0.96, 0.90, 0.34), 1.0, true)
	var knob_pos := _joy_center + _joy_knob
	var knob_col := Color(1.0, 0.76, 0.22, 0.65) if _joy_touch_id != -1 else Color(1.0, 0.96, 0.90, 0.38)
	draw_circle(knob_pos, JOY_KNOB_R, knob_col)
	draw_arc(knob_pos, JOY_KNOB_R, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.65), 1.0, true)

	# 2. زر إطلاق النار (دائرة زجاجية مدمجة وأنيقة برمز رصاصة/هدف)
	var fire_fill := Color(0.95, 0.25, 0.22, 0.58) if _fire_touch_id != -1 else Color(0.88, 0.20, 0.18, 0.22)
	draw_circle(_fire_center, BTN_R, fire_fill)
	draw_arc(_fire_center, BTN_R, 0.0, TAU, 28, Color(1.0, 0.72, 0.65, 0.62), 1.1, true)
	draw_circle(_fire_center, 3.2, Color(1.0, 0.95, 0.85, 0.88))
	draw_arc(_fire_center, 6.2, 0.0, TAU, 20, Color(1.0, 0.95, 0.85, 0.65), 1.0, true)

	# 3. زر القفز (دائرة زجاجية مدمجة بسهم نظيف)
	var jump_fill := Color(0.24, 0.70, 0.44, 0.58) if _jump_touch_id != -1 else Color(0.18, 0.52, 0.34, 0.22)
	draw_circle(_jump_center, BTN_R, jump_fill)
	draw_arc(_jump_center, BTN_R, 0.0, TAU, 28, Color(0.75, 1.0, 0.82, 0.62), 1.1, true)
	draw_polyline(PackedVector2Array([
		_jump_center + Vector2(-4.2, 1.5),
		_jump_center + Vector2(0.0, -3.8),
		_jump_center + Vector2(4.2, 1.5)
	]), Color(1, 1, 1, 0.88), 1.5, true)

	# 4. زر تبديل السلاح الصغير (دائرة ذهبية رقيقة)
	var wpn_fill := Color(1.0, 0.74, 0.20, 0.62) if _wpn_touch_id != -1 else Color(0.85, 0.60, 0.16, 0.22)
	draw_circle(_wpn_center, WPN_R, wpn_fill)
	draw_arc(_wpn_center, WPN_R, 0.0, TAU, 20, Color(1.0, 0.90, 0.62, 0.65), 1.0, true)
	draw_line(_wpn_center + Vector2(-3.2, 0), _wpn_center + Vector2(3.2, 0), Color(1, 1, 1, 0.88), 1.5)
	draw_line(_wpn_center + Vector2(0.8, -2.2), _wpn_center + Vector2(3.2, 0), Color(1, 1, 1, 0.88), 1.1)
	draw_line(_wpn_center + Vector2(0.8, 2.2), _wpn_center + Vector2(3.2, 0), Color(1, 1, 1, 0.88), 1.1)
