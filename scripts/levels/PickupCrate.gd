extends Area2D
## صندوق إمداد قابل للتدمير بالرصاص — يُسقط سلاحاً أو قلب صحة للبطل
## Shootable supply crate that drops a weapon or health pickup

enum RewardType {
	SPREAD_WEAPON,
	HEAVY_WEAPON,
	HEALTH,
}

const EXPLOSION_SCENE := preload("res://scenes/effects/Explosion.tscn")

@export var reward_type: RewardType = RewardType.SPREAD_WEAPON
@export var crate_hp: int = 2

var _is_opened: bool = false
var _bob_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# يبدأ كهدف لرصاص البطل (Layer 3)
	collision_layer = 4
	collision_mask = 8
	_set_crate_sprite()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _is_opened:
		_bob_time += delta * 5.0
		sprite.position.y = -8.0 + sin(_bob_time) * 2.0


func take_damage(amount: int = 1) -> void:
	if _is_opened:
		return
	crate_hp -= amount
	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	await get_tree().create_timer(0.06).timeout
	if is_instance_valid(self):
		sprite.modulate = Color.WHITE
	if crate_hp <= 0:
		_open_crate()


func _open_crate() -> void:
	_is_opened = true
	# يتحول لرمز إمداد يلتقطه البطل (Mask = Layer 2 Player)
	collision_layer = 0
	collision_mask = 2

	var exp_fx := EXPLOSION_SCENE.instantiate()
	exp_fx.global_position = global_position + Vector2(0, -8)
	get_tree().current_scene.add_child(exp_fx)
	GameState.request_shake(2.0, 0.12)
	_play_sfx("explode")
	_set_pickup_sprite()


func _on_body_entered(body: Node2D) -> void:
	if not _is_opened or not body.is_in_group("player"):
		return

	match reward_type:
		RewardType.SPREAD_WEAPON:
			if body.has_method("set_weapon"):
				body.set_weapon(1)
		RewardType.HEAVY_WEAPON:
			if body.has_method("set_weapon"):
				body.set_weapon(2)
		RewardType.HEALTH:
			if body.has_method("heal"):
				body.heal(1)

	GameState.add_score(150)
	_play_sfx("jump")
	queue_free()


func _play_sfx(sfx_name: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sfx_name)


func _set_crate_sprite() -> void:
	sprite.texture = ProceduralArt.create_texture("supply_crate", PackedStringArray([
		"0000000000000000",
		"0662222222222660",
		"0621111111111260",
		"0212226666222120",
		"021226ffff622120",
		"021226f66f622120",
		"021226ffff622120",
		"0212226666222120",
		"0212222222222120",
		"0211111111111120",
		"0622222222222260",
		"0662222222222660",
		"0000000000000000",
	]))
	sprite.position = Vector2(0, -7)


func _set_pickup_sprite() -> void:
	match reward_type:
		RewardType.SPREAD_WEAPON:
			sprite.texture = ProceduralArt.create_texture("pickup_spread", PackedStringArray([
				"..00000000..",
				".0666666660.",
				"0633ffff3360",
				"063f33333360",
				"0633ffff3360",
				"06333333f360",
				"0633ffff3360",
				".0666666660.",
				"..00000000..",
			]))
		RewardType.HEAVY_WEAPON:
			sprite.texture = ProceduralArt.create_texture("pickup_heavy", PackedStringArray([
				"..00000000..",
				".0aaaaaaaa0.",
				"0aafaaaaafa0",
				"0aafaaaaafa0",
				"0aafffffffa0",
				"0aafaaaaafa0",
				"0aafaaaaafa0",
				".0aaaaaaaa0.",
				"..00000000..",
			]))
		RewardType.HEALTH:
			sprite.texture = ProceduralArt.create_texture("pickup_health", PackedStringArray([
				"..00000000..",
				".0eeeeeeee0.",
				"0eeeffffeee0",
				"0eeeffffeee0",
				"0effffffffe0",
				"0eeeffffeee0",
				"0eeeffffeee0",
				".0eeeeeeee0.",
				"..00000000..",
			]))
