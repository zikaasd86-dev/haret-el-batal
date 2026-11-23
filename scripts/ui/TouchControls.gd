extends CanvasLayer
## واجهة التحكم اللمسي الاحترافية للموبايل - "حارة البطل"
## جويستك افتراضي شفاف أقصى اليسار (8 اتجاهات + انبطاح) + أزرار دائرية شفافة أقصى اليمين (نار، قفز، سلاح)

@onready var pad: Control = $TouchPad


func _ready() -> void:
	pad.queue_redraw()
