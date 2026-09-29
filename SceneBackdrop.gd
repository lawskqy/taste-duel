extends Control

var phase: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if not GameManager.reduce_motion:
		phase += delta * 0.15
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GameStyle.INK)
	for i in range(6):
		var center = Vector2(size.x * float(i) / 5, size.y * 0.5 + sin(phase + i) * 170)
		draw_circle(center, 130 + i * 12, Color(GameStyle.GOLD, 0.015))
	for x in range(24, int(size.x), 48):
		for y in range(24, int(size.y), 48):
			draw_circle(Vector2(x, y), 1, Color(GameStyle.MUTED, 0.09))
