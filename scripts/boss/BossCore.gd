extends Area2D
## نقطة الضعف الوحيدة للزعيم (النواة الحمراء)
## تستقبل طلقات البطل وتحول الضرر إلى سكربت الزعيم الرئيسي


func take_damage(amount: int = 1) -> void:
	var boss := get_parent()
	if boss and boss.has_method("take_core_damage"):
		boss.take_core_damage(amount)
