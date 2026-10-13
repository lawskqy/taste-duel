class_name GameStyle
extends RefCounted

const INK = Color("304b63")
const TEXT = INK
const BACKGROUND = Color("91aabd") # Dusty blue, kept below white-paper brightness
const PANEL = Color("c0d2df")
const RAISED = Color("d1dfe8")
const LINE = Color("7895ac")
const CREAM = Color("f5eee3")
const PAPER = Color("e3e6df")
const PAPER_INK = INK
const MUTED = Color("4d667b")
const CORAL = Color("e4b49f") # Peach: warm player / damage
const MINT = Color("accdbd") # Mint: healing / confirmation
const GOLD = Color("dfcd98") # Butter: primary action / wins
const SKY = Color("9fbfdc")
const LAVENDER = Color("c3afd7")
const NIGHT_SHADOW = Color("405c76")
static var shared: Theme
static var art: ShaderMaterial

static func art_material() -> ShaderMaterial:
	if art == null:
		art = ShaderMaterial.new()
		art.shader = preload("res://assets/shaders/card_art.gdshader")
	return art

static func box(color: Color, border: Color = LINE, radius: int = 6, padding: int = 10) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius * 3 if radius <= 10 else radius)
	style.shadow_color = Color(NIGHT_SHADOW, 0.16)
	style.shadow_size = 4 if padding >= 8 else 0
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func button_box(color: Color, border: Color = LINE, radius: int = 5, padding: int = 8) -> StyleBoxFlat:
	var style = box(color, border, radius, padding)
	style.set_border_width_all(2)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 3)
	return style

static func theme() -> Theme:
	if shared != null:
		return shared
	shared = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Bricolage Grotesque", "Trebuchet MS", "sans-serif"])
	shared.default_font = font
	shared.default_font_size = 16
	for type in ["Label", "Button", "CheckButton"]:
		shared.set_color("font_color", type, TEXT)
	shared.set_color("font_disabled_color", "Button", MUTED)
	shared.set_color("font_hover_color", "Button", TEXT)
	shared.set_color("font_pressed_color", "Button", TEXT)
	shared.set_color("font_focus_color", "Button", TEXT)
	shared.set_color("font_color", "LineEdit", TEXT)
	shared.set_color("caret_color", "LineEdit", TEXT)
	shared.set_color("selection_color", "LineEdit", SKY)
	shared.set_stylebox("normal", "LineEdit", box(RAISED, LINE))
	shared.set_stylebox("focus", "LineEdit", box(RAISED, INK))
	shared.set_stylebox("panel", "PanelContainer", box(PANEL))
	shared.set_stylebox("normal", "Button", button_box(RAISED))
	shared.set_stylebox("hover", "Button", button_box(RAISED.lightened(0.06), INK))
	var pressed = button_box(SKY, INK)
	pressed.shadow_size = 0
	shared.set_stylebox("pressed", "Button", pressed)
	var disabled = button_box(PANEL.darkened(0.06), LINE)
	disabled.shadow_size = 0
	shared.set_stylebox("disabled", "Button", disabled)
	var focused = button_box(Color(0, 0, 0, 0), INK, 5, 0)
	focused.shadow_size = 0
	shared.set_stylebox("focus", "Button", focused)
	shared.set_stylebox("background", "ProgressBar", box(RAISED, LINE, 6, 0))
	shared.set_stylebox("fill", "ProgressBar", box(MINT, MINT.darkened(0.2), 6, 0))
	shared.set_stylebox("panel", "TooltipPanel", box(PANEL, GOLD))
	shared.set_color("font_color", "TooltipLabel", TEXT)
	shared.set_constant("separation", "VBoxContainer", 8)
	shared.set_constant("separation", "HBoxContainer", 8)
	shared.set_stylebox("panel", "PopupMenu", box(PANEL, LINE, 6, 12))
	shared.set_stylebox("hover", "PopupMenu", box(RAISED, LAVENDER, 4, 6))
	shared.set_color("font_color", "PopupMenu", TEXT)
	shared.set_color("font_hover_color", "PopupMenu", TEXT)
	shared.set_constant("v_separation", "PopupMenu", 12)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		shared.set_stylebox(state, "OptionButton", shared.get_stylebox(state, "Button"))
	shared.set_color("font_color", "OptionButton", TEXT)
	shared.set_color("font_hover_color", "OptionButton", TEXT)
	shared.set_stylebox("scroll", "VScrollBar", box(RAISED, RAISED, 3, 3))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		shared.set_stylebox(state, "VScrollBar", box(LINE, LINE, 3, 4))
	return shared

static func primary(button: Button, tint: Color = SKY) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_stylebox_override("normal", button_box(tint, LINE, 6, 10))
	button.add_theme_stylebox_override("hover", button_box(tint.lightened(0.06), INK, 6, 10))
	var pressed = button_box(tint.darkened(0.08), INK, 6, 10)
	pressed.shadow_size = 0
	button.add_theme_stylebox_override("pressed", pressed)

static func readable(color: Color) -> Color:
	return color.lerp(INK, 0.78) if color.get_luminance() > 0.4 else color

# Set offsets explicitly after parenting; content growth stays centered too.
static func center_panel(panel: Control, dimensions: Vector2) -> void:
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -dimensions.x / 2
	panel.offset_right = dimensions.x / 2
	panel.offset_top = -dimensions.y / 2
	panel.offset_bottom = dimensions.y / 2
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

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
