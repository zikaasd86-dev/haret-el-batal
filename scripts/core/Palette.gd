class_name Palette
extends RefCounted
## لوحة ألوان أصلية من 16 لوناً دافئاً مستوحاة من الحارة الشعبية المصرية
## Original 16-color warm Egyptian alley palette

const C_BLACK      := Color("#1a1310") # 0: ظل عميق وحدود البكسل
const C_DARK_BROWN := Color("#3b261b") # 1: خشب داكن / أزقة مظلمة
const C_WOOD       := Color("#6e442c") # 2: صناديق وأبواب خشبية
const C_BRICK      := Color("#9e4f32") # 3: طوب أحمر / واجهات حارة
const C_SAND       := Color("#c9975b") # 4: حجر رملي / جدران دافئة
const C_CREAM      := Color("#ebd099") # 5: إضاءة دافئة / شمس الحارة
const C_GOLD       := Color("#f5b82e") # 6: فوانيس / وميض رصاص / ذهب
const C_DARK_GREEN := Color("#1f3d2b") # 7: شرفات وأخشاب خضراء داكنة
const C_GREEN      := Color("#396e4b") # 8: ملابس البطل / مظلات الأكشاك
const C_SKIN       := Color("#d99a6c") # 9: بشرة البطل
const C_TEAL       := Color("#3d7078") # 10: سماء الغسق / زجاج
const C_SLATE      := Color("#5c636b") # 11: معدن الأسلحة والزعيم
const C_LIGHT_GRAY := Color("#a8b0b8") # 12: لمعان معدني
const C_DARK_RED   := Color("#7a1c1c") # 13: دروع الأعداء / ظل النواة
const C_RED_CORE   := Color("#e03131") # 14: النواة الحمراء للزعيم / طلقات الأعداء
const C_WHITE      := Color("#fff8e7") # 15: وميض أبيض دافئ / واجهة

## خريطة حروف لتسهيل رسم البكسل آرت بالكود (ASCII -> Color)
static func get_color_map() -> Dictionary:
	return {
		".": Color(0, 0, 0, 0), # شفاف
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
