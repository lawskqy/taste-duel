class_name AvatarPortrait
extends Control

var avatar_index: int = 0
var accent: Color = GameStyle.CORAL
var active: bool = false
var _sprite: Sprite2D
var _time: float = 0.0
var _reaction: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite = Sprite2D.new()
	var material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/avatar_tint.gdshader")
	_sprite.material = material
	add_child(_sprite)
	configure(avatar_index, accent)
	resized.connect(_layout)
	_layout()

func configure(index: int, color: Color) -> void:
	avatar_index = clampi(index, 0, 3)
	accent = color
	if _sprite:
		_sprite.texture = load("res://assets/avatars/%d.svg" % avatar_index)
		_sprite.material.set_shader_parameter("accent", accent)
	queue_redraw()

func _layout() -> void:
	if _sprite == null:
		return
	_sprite.position = size / 2
	_sprite.scale = Vector2.ONE * minf(size.x / 170, size.y / 190)
	pivot_offset = size / 2
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if _sprite:
		_sprite.position.y = size.y / 2 + (0.0 if GameManager.reduce_motion else sin(_time * 2.5 + avatar_index) * 2.0)
	if active and not GameManager.reduce_motion:
		queue_redraw()

func _draw() -> void:
	var radius = minf(size.x, size.y) * 0.43
	draw_circle(size / 2 + Vector2(0, 3), radius, Color(GameStyle.NIGHT_SHADOW, 0.12))
	draw_circle(size / 2, radius, GameStyle.RAISED.lerp(accent, 0.24))
	draw_arc(size / 2, radius, 0, TAU, 64, Color(GameStyle.LINE, 0.8 if active else 0.3), 2.0, true)
	draw_arc(size / 2, radius - 5, PI * 1.12, PI * 1.55, 20, Color(GameStyle.CREAM, 0.55), 2.5, true)
	if active:
		var angle = 0.0 if GameManager.reduce_motion else _time * 0.7
		draw_circle(size / 2 + Vector2.from_angle(angle) * radius, 5, GameStyle.PAPER)
		draw_circle(size / 2 + Vector2.from_angle(angle) * radius, 3, GameStyle.LINE)

func react(kind: String) -> void:
	GameManager.play_sound(kind)
	if _reaction:
		_reaction.kill()
	scale = Vector2.ONE
	modulate = Color.WHITE
	if GameManager.reduce_motion:
		return
	_reaction = create_tween()
	modulate = GameStyle.CORAL if kind == "hit" else Color(1.2, 1.2, 1.2)
	_reaction.tween_property(self, "scale", Vector2(1.08, 0.94), 0.09)
	_reaction.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reaction.parallel().tween_property(self, "modulate", Color.WHITE, 0.22)
