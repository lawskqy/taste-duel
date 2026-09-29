class_name GameStyle
extends RefCounted

const INK = Color("101b24")
const PANEL = Color("1c2c37")
const LINE = Color("354b59")
const CREAM = Color("f4ead6")
const MUTED = Color("a8bbc5")
const CORAL = Color("ff8c7d")
const MINT = Color("83dfbb")
const GOLD = Color("edc77f")
static var shared: Theme
static var art: ShaderMaterial

static func art_material() -> ShaderMaterial:
	if art == null:
		art = ShaderMaterial.new()
		art.shader = preload("res://assets/card_art.gdshader")
	return art

static func box(color: Color, border: Color = LINE, radius: int = 10, padding: int = 10) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func theme() -> Theme:
	if shared != null:
		return shared
	shared = Theme.new()
	shared.default_font_size = 16
	for type in ["Label", "Button", "CheckButton"]:
		shared.set_color("font_color", type, CREAM)
	shared.set_color("font_disabled_color", "Button", MUTED.darkened(0.25))
	shared.set_color("font_hover_color", "Button", GOLD)
	shared.set_color("font_color", "LineEdit", CREAM)
	shared.set_stylebox("normal", "LineEdit", box(INK))
	shared.set_stylebox("focus", "LineEdit", box(INK, GOLD))
	shared.set_stylebox("panel", "PanelContainer", box(PANEL))
	shared.set_stylebox("normal", "Button", box(PANEL))
	shared.set_stylebox("hover", "Button", box(Color("2b414e"), GOLD))
	shared.set_stylebox("pressed", "Button", box(Color("384d55"), MINT))
	shared.set_stylebox("disabled", "Button", box(INK, Color("243642")))
	shared.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 10, 0))
	shared.set_stylebox("background", "ProgressBar", box(INK, LINE, 8, 0))
	shared.set_stylebox("fill", "ProgressBar", box(MINT, MINT, 8, 0))
	shared.set_stylebox("panel", "TooltipPanel", box(PANEL, GOLD))
	shared.set_color("font_color", "TooltipLabel", CREAM)
	shared.set_constant("separation", "VBoxContainer", 8)
	shared.set_constant("separation", "HBoxContainer", 8)
	return shared

static func apply(node: Node) -> void:
	if node is Control:
		node.theme = theme()
	for child in node.get_children():
		apply(child)

static func motion_button(parent: Node, at: Vector2 = Vector2.ZERO) -> CheckButton:
	var button = CheckButton.new()
	button.text = "Reduced motion"
	button.theme = theme()
	button.position = at
	button.button_pressed = parent.get_node("/root/GameManager").reduce_motion
	button.toggled.connect(func(value): parent.get_node("/root/GameManager").reduce_motion = value)
	parent.add_child(button)
	return button
