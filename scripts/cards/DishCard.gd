class_name DishCard
extends PanelContainer

@onready var rank_badge = $HBox/RankBadge
@onready var rank_label = $HBox/RankBadge/RankLabel
@onready var dish_icon = $HBox/DishIcon
@onready var dish_name = $HBox/Body/DishName
@onready var power = $HBox/Body/Power
@onready var art_mark = $HBox/ArtMark

var item_id: String = ""
var current_container = null

func _ready() -> void:
	theme = GameStyle.theme()
	dish_icon.material = GameStyle.art_material()
	add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PAPER, GameStyle.PAPER.darkened(0.12), 5, 2))
	dish_name.add_theme_color_override("font_color", GameStyle.PAPER_INK)
	art_mark.add_theme_color_override("font_color", GameStyle.PAPER_INK.lightened(0.2))
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	mouse_entered.connect(func(): self_modulate = Color(1.06, 1.02, 0.96))
	mouse_exited.connect(func(): self_modulate = Color.WHITE)

func setup(id: String, display_name: String, texture: Texture2D = null, icon: String = "") -> void:
	item_id = id
	dish_name.text = display_name
	tooltip_text = display_name
	if texture:
		dish_icon.texture = texture
		dish_icon.visible = true
		art_mark.hide()
	else:
		dish_icon.visible = false
		art_mark.text = icon if not icon.is_empty() else "✦"
		art_mark.show()
	hide_rank()

func show_rank(rank: int, category: String = "neutral") -> void:
	rank_label.text = str(rank)
	rank_badge.visible = true
	var tint = GameStyle.CORAL if category == "disliked" else (GameStyle.MINT if category == "liked" else GameStyle.GOLD)
	rank_label.add_theme_color_override("font_color", GameStyle.PAPER_INK)
	rank_label.add_theme_font_size_override("font_size", 15)
	rank_badge.add_theme_stylebox_override("panel", GameStyle.box(tint, tint.darkened(0.25), 5, 2))
	var effect_count = CardBalance.effects(category, rank)
	power.text = "%d %s  ·  %d %s" % [CardBalance.hp(category, rank), "damage" if category == "disliked" else "healing", effect_count, "effect" if effect_count == 1 else "effects"] if category != "neutral" else "No HP change  ·  1 effect"
	power.add_theme_color_override("font_color", GameStyle.PAPER_INK.lightened(0.15))
	power.show()
	tooltip_text = "%s\nRank %d · %s\nWhen your opponent plays this card against you." % [dish_name.text, rank, CardBalance.summary(category, rank)]
	add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PAPER, tint.darkened(0.35), 5, 2))

func hide_rank() -> void:
	rank_badge.visible = false
	power.hide()
	add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PAPER, GameStyle.PAPER.darkened(0.12), 5, 2))
	tooltip_text = dish_name.text
