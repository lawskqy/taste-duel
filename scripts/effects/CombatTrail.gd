extends Node2D

var destination: Vector2
var tint: Color = GameStyle.GOLD
var progress: float = 0.0

func _process(delta: float) -> void:
	progress += delta / 0.3
	if progress >= 1:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	for i in range(12):
		var t = clampf(progress - i * 0.018, 0, 1)
		var point = destination * t + Vector2(sin(t * PI) * 60, 0)
		draw_circle(point, 6.0 * (1.0 - i / 12.0), Color(tint, (1.0 - i / 12.0) * 0.85))
