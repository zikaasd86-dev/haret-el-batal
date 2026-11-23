class_name Palette
extends RefCounted
## لوحة ألوان أصلية محسّنة بأسلوب 16-bit دافئ وعالي التباين للحارة المصرية
## Vibrant 16-bit warm sunset & night contrast palette

const C_BLACK      := Color("#120d16") # 0: حدود داكنة عميقة
const C_DARK_BROWN := Color("#2f1d1b") # 1: خشب وأسقف داكنة
const C_WOOD       := Color("#7a4a2b") # 2: صناديق وأخشاب دافئة
const C_BRICK      := Color("#b85334") # 3: طوب أحمر غني
const C_SAND       := Color("#d9a25f") # 4: حجر رملي دافئ
const C_CREAM      := Color("#ffe7b3") # 5: إضاءة شمس ذهبية ناعمة
const C_GOLD       := Color("#ffb82e") # 6: فوانيس ووميض رصاص ساطع
const C_DARK_GREEN := Color("#1c4a36") # 7: شرفات خضراء عميقة
const C_GREEN      := Color("#2eb86b") # 8: سترة البطل الساطعة (تباين عالٍ)
const C_SKIN       := Color("#f0ad7e") # 9: بشرة البطل واضحة
const C_TEAL       := Color("#263b5e") # 10: سماء الغسق العميقة
const C_SLATE      := Color("#627082") # 11: معدن الأسلحة والزعيم
const C_LIGHT_GRAY := Color("#cfd8e3") # 12: لمعان معدني ساطع
const C_DARK_RED   := Color("#8c1d2c") # 13: دروع الأعداء
const C_RED_CORE   := Color("#ff3b3b") # 14: النواة الحمراء الساطعة / طلقات الأعداء
const C_WHITE      := Color("#fffdf5") # 15: أبيض ناصع

# ألوان إضافية لتدرج سماء الغسق والليل (Parallax)
const SKY_DUSK_TOP := Color("#1c2340")
const SKY_DUSK_MID := Color("#5c3152")
const SKY_DUSK_LOW := Color("#d96b38")
const SKY_NIGHT_TOP := Color("#0c1026")
const SKY_NIGHT_MID := Color("#1a2448")
const SKY_NIGHT_LOW := Color("#2e3b66")

static func get_color_map() -> Dictionary:
	return {
		".": Color(0, 0, 0, 0),
		"0": C_BLACK,
		"1": C_DARK_BROWN,
		"2": C_WOOD,
		"3": C_BRICK,
		"4": C_SAND,
		"5": C_CREAM,
		"6": C_GOLD,
		"7": C_DARK_GREEN,
		"8": C_GREEN,
		"9": C_SKIN,
		"a": C_TEAL,
		"b": C_SLATE,
		"c": C_LIGHT_GRAY,
		"d": C_DARK_RED,
		"e": C_RED_CORE,
		"f": C_WHITE,
	}
