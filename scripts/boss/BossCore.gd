extends Area2D
## نقطة ضعف للزعيم (تدعم مكانين: الرأس أو نواة الصدر)

@export var part_id: String = "core" # "head" أو "core"


func take_damage(amount: int = 1) -> void:
	var boss := get_parent()
	if boss and boss.has_method("take_weakpoint_damage"):
		boss.take_weakpoint_damage(amount, part_id)
