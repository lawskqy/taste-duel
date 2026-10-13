extends Control

var phase: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if not GameManager.reduce_motion:
		phase += delta * 0.06
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GameStyle.BACKGROUND)
	# Quiet bubble rings around the edges leave the reading area calm.
	var bubbles = [Vector3(0.06, 0.23, 92), Vector3(0.15, 0.80, 54), Vector3(0.91, 0.18, 110), Vector3(0.97, 0.72, 74), Vector3(0.22, 0.09, 24), Vector3(0.78, 0.92, 33)]
	for i in range(bubbles.size()):
		var bubble = bubbles[i]
		var point = Vector2(size.x * bubble.x, size.y * bubble.y + sin(phase + i) * 5)
		var radius = bubble.z * minf(size.x / 1280, size.y / 720)
		draw_circle(point, radius, Color(GameStyle.SKY, 0.22))
		draw_arc(point, radius, 0, TAU, 80, Color(GameStyle.CREAM, 0.20), 1.5, true)
		draw_arc(point, radius - 7, PI * 1.12, PI * 1.52, 24, Color(GameStyle.CREAM, 0.30), 3, true)
	for i in range(12):
		var point = Vector2(fmod(i * 137.0 + 46, 1280) / 1280 * size.x, fmod(i * 211.0 + 59, 720) / 720 * size.y)
		draw_circle(point, 2.0, Color(GameStyle.CREAM, 0.25))
