extends Node2D

var tint: Color = Color.WHITE
var age: float = 0.0
var lifetime: float = 0.65

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress = age / lifetime
	var color = tint
	color.a = 1.0 - progress
	draw_arc(Vector2.ZERO, 12 + progress * 45, 0, TAU, 48, color, 2.0, true)
	for i in range(12):
		var direction = Vector2.from_angle(TAU * i / 12.0)
		var distance = 16 + progress * (48 + (i % 3) * 14)
		draw_circle(direction * distance, 3.0 * (1.0 - progress), color)
