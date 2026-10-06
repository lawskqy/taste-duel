extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var radius = minf(size.y * 0.36, 42)
	var center = size / 2
	for i in range(2):
		var point = center + Vector2((-1 if i == 0 else 1) * radius * 0.85, (-1 if i == 0 else 1) * 4)
		var tint = GameStyle.CORAL if i == 0 else GameStyle.SKY
		draw_circle(point + Vector2(0, 3), radius, Color(GameStyle.NIGHT_SHADOW, 0.18))
		draw_circle(point, radius, tint)
		draw_arc(point, radius, 0, TAU, 64, GameStyle.LINE, 2, true)
		draw_arc(point, radius * 0.72, 0, TAU, 64, tint.darkened(0.22), 1.5, true)
		# A small sprig on each saucer.
		draw_line(point + Vector2(-8, 8), point + Vector2(8, -8), GameStyle.PAPER_INK, 2, true)
		draw_circle(point + Vector2(-4, -2), 4, GameStyle.PAPER_INK)
		draw_circle(point + Vector2(4, 2), 4, GameStyle.PAPER_INK)
	for side in [-1, 1]:
		var x = center.x + side * radius * 2.35
		draw_line(Vector2(x, center.y - radius * 0.5), Vector2(x, center.y + radius * 0.65), GameStyle.GOLD, 3, true)
		if side == -1:
			for offset in [-5, 0, 5]:
				draw_line(Vector2(x + offset, center.y - radius * 0.6), Vector2(x + offset, center.y - radius * 0.1), GameStyle.GOLD, 2, true)
			draw_line(Vector2(x - 5, center.y - radius * 0.1), Vector2(x + 5, center.y - radius * 0.1), GameStyle.GOLD, 2, true)
