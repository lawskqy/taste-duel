extends RefCounted

static func build(battle: Node) -> void:
	var page = MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		page.add_theme_constant_override("margin_" + edge, 24)
	battle.get_node("UI").add_child(page)
	battle.get_node("UI").move_child(page, 0)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	page.add_child(layout)
	battle._toolbar = HBoxContainer.new()
	battle._toolbar.custom_minimum_size.y = 48
	battle._toolbar.add_theme_constant_override("separation", 12)
	layout.add_child(battle._toolbar)
	battle.turn_label.reparent(battle._toolbar)
	battle.turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle.turn_label.clip_text = true
	battle.turn_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	for i in range(3):
		var panel = PanelContainer.new()
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(panel)
		var stack = VBoxContainer.new()
		stack.add_theme_constant_override("separation", 14)
		panel.add_child(stack)
		if i == 1:
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL, GameStyle.LINE, 10, 22))
			battle._table_stack = stack
			continue
		var index = 0 if i == 0 else 1
		var accent = GameStyle.CORAL if index == 0 else GameStyle.SKY
		panel.custom_minimum_size.x = 270
		panel.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL, accent.darkened(0.35), 10, 18))
		battle._player_stacks.append(stack)
		stack.add_child(label("PLAYER %02d" % (index + 1), 13, accent))
		var portrait = AvatarPortrait.new()
		portrait.custom_minimum_size = Vector2(150, 154)
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait.configure(GameManager.profiles[index].avatar, GameManager.COLORS[GameManager.profiles[index].color])
		stack.add_child(portrait)
		battle._portraits.append(portrait)
		var name_label = label(GameManager.player_name(index), 23, GameStyle.TEXT)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(name_label)
		var hp_text = battle._hp_labels[index]
		hp_text.reparent(stack)
		hp_text.add_theme_font_size_override("font_size", 15)
		hp_text.add_theme_color_override("font_color", GameStyle.MUTED)
		var hp_bar = battle.hp_bar_p1 if index == 0 else battle.hp_bar_p2
		hp_bar.reparent(stack)
		hp_bar.custom_minimum_size.y = 18
		stack.add_child(label("ACTIVE EFFECTS", 11, accent))
		var scroll = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		stack.add_child(scroll)
		var buffs = battle._buff_labels[index]
		buffs.reparent(scroll)
		buffs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buffs.add_theme_color_override("font_color", GameStyle.MUTED)
		buffs.add_theme_font_size_override("font_size", 14)

	battle._pool_label = label("", 12, GameStyle.LAVENDER)
	battle._pool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle._table_stack.add_child(battle._pool_label)
	battle._turn_notice = label("%s plays first." % battle._player_name(battle.get_current_player()), 16, GameStyle.INK)
	battle._turn_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle._turn_notice.max_lines_visible = 3
	battle._turn_notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	battle._table_stack.add_child(battle._turn_notice)
	battle._card_slot = Control.new()
	battle._card_slot.custom_minimum_size.y = 218
	battle._table_stack.add_child(battle._card_slot)
	var emblem = preload("res://scripts/ui/SupperEmblem.gd").new()
	emblem.name = "EmptyTable"
	emblem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle._card_slot.add_child(emblem)
	battle.played_cards.reparent(battle._card_slot)
	battle._card_slot.resized.connect(func(): battle.played_cards.position = (battle._card_slot.size - Vector2(210, 160)) / 2)
	var divider = HSeparator.new()
	battle._table_stack.add_child(divider)
	var messages = ScrollContainer.new()
	messages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	messages.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	battle._table_stack.add_child(messages)
	battle.effect_popup.reparent(messages)
	battle.effect_popup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle.effect_popup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	battle.effect_popup.add_theme_font_size_override("font_size", 16)
	battle.effect_popup.add_theme_color_override("font_color", GameStyle.TEXT)
	battle.effect_popup.text = "The table is set.\nOpen your card pool to choose the first serving."
	var footer = label("A little taste. A little guesswork.", 13, GameStyle.MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(footer)

static func label(text: String, font_size: int, color: Color) -> Label:
	var result = Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", GameStyle.readable(color))
	return result
