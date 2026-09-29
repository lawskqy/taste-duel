extends Control

@onready var player_label = $Layout/Header/PlayerLabel
@onready var timer_label = $Layout/Header/TimerLabel
@onready var randomize_btn = $Layout/Header/Buttons/RandomizeButton
@onready var confirm_btn = $Layout/Header/Buttons/ConfirmButton
@onready var pool_grid = $Layout/Pool/Scroll/PoolGrid
@onready var dislike_list = $Layout/Columns/DislikeColumn/Scroll/DislikeList
@onready var neutral_list = $Layout/Columns/NeutralColumn/Scroll/NeutralList
@onready var like_list = $Layout/Columns/LikeColumn/Scroll/LikeList

const DISH_CARD = preload("res://DishCard.tscn")
const TIME_LIMIT = 120  
const GROUP_SIZE = 7

var dishes: Array = []
var current_player: int = 1
var time_remaining: float = TIME_LIMIT
var timer_running: bool = false
var dragging_card = null
var drag_offset: Vector2 = Vector2.ZERO
var drag_ghost = null  

var all_lists: Array = []  
var submitted: bool = false

signal form_submitted(player_idx: int, preferences: Dictionary)

func _ready() -> void:
	GameStyle.apply(self)
	$Background.color = GameStyle.INK
	GameStyle.motion_button($Layout/Header/Buttons)
	confirm_btn.add_theme_color_override("font_color", GameStyle.MINT)
	for entry in [[dislike_list, GameStyle.CORAL], [neutral_list, GameStyle.GOLD], [like_list, GameStyle.MINT]]:
		entry[0].get_parent().add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL.darkened(0.3), entry[1].darkened(0.5), 12, 8))
		entry[0].get_parent().get_parent().get_child(0).modulate = entry[1]
	all_lists = [pool_grid, dislike_list, neutral_list, like_list]
	randomize_btn.pressed.connect(_on_randomize)
	confirm_btn.pressed.connect(_on_confirm)
	confirm_btn.disabled = true

func setup(player_idx: int, items: Array) -> void:
	_cancel_drag()
	submitted = false
	randomize_btn.disabled = false
	time_remaining = TIME_LIMIT
	current_player = player_idx
	var theme_info: Dictionary = GameManager.get_theme_info()
	player_label.text = "%s  /  %s" % [theme_info.get("name", "Taste Duel").to_upper(), GameManager.player_name(player_idx - 1)]
	dishes = items
	_populate_pool()
	timer_running = true
	_check_confirm_valid()

func _populate_pool() -> void:
	for list in all_lists:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	for item in dishes:
		var card = DISH_CARD.instantiate()
		pool_grid.add_child(card)
		card.setup(item.id, item.name, GameManager.get_texture(item.id), item.icon)
		card.tooltip_text = "%s\n%s" % [item.name, item.description]
		card.current_container = pool_grid

func _process(delta: float) -> void:
	if timer_running:
		time_remaining -= delta
		if time_remaining <= 0:
			time_remaining = 0
			timer_running = false
			_fill_remaining()
		var mins = int(time_remaining) / 60
		var secs = int(time_remaining) % 60
		timer_label.text = "%d:%02d" % [mins, secs]

	if drag_ghost:
		drag_ghost.global_position = get_global_mouse_position() + drag_offset
		
var drag_start_pos: Vector2 = Vector2.ZERO
var mouse_held: bool = false
var drag_threshold: float = 5.0

func _input(event: InputEvent) -> void:
	if submitted:
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel_drag()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_start_pos = event.position
				mouse_held = true
			else:
				mouse_held = false
				_end_drag(event.position)
	elif event is InputEventMouseMotion:
		if mouse_held and not dragging_card:
			if event.position.distance_to(drag_start_pos) > drag_threshold:
				_try_start_drag(drag_start_pos)
				
func _try_start_drag(mouse_pos: Vector2) -> void:
	for list in all_lists:
		if not list.get_parent().get_global_rect().has_point(mouse_pos):
			continue
		for card in list.get_children():
			if card is DishCard and card.get_global_rect().has_point(mouse_pos):
				_start_drag(card, mouse_pos)
				return

func _start_drag(card: DishCard, mouse_pos: Vector2) -> void:
	dragging_card = card
	drag_offset = card.global_position - mouse_pos

	drag_ghost = card.duplicate()
	drag_ghost.modulate.a = 0.7
	drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drag_ghost)
	drag_ghost.size = card.size
	drag_ghost.global_position = card.global_position

	card.modulate.a = 0.3

func _end_drag(mouse_pos: Vector2) -> void:
	if not dragging_card:
		return

	var target_list = _get_list_under_mouse(mouse_pos)
	if target_list:
		_drop_card_into(dragging_card, target_list, mouse_pos)
	else:
		dragging_card.modulate.a = 1.0

	if drag_ghost:
		drag_ghost.queue_free()
		drag_ghost = null
	dragging_card = null

	_update_all_ranks()
	_check_confirm_valid()

func _get_list_under_mouse(mouse_pos: Vector2) -> Control:
	for list in all_lists:
		if list.get_parent().get_global_rect().has_point(mouse_pos):
			return list
	return null

func _drop_card_into(card: DishCard, target: Control, mouse_pos: Vector2) -> void:
	var origin = card.get_parent()
	var origin_index = card.get_index()
	# Full categories exchange cards, so a valid ranking can still be edited.
	if target != pool_grid and target != origin and target.get_child_count() >= GROUP_SIZE:
		var swapped = target.get_child(target.get_child_count() - 1)
		for child in target.get_children():
			if child.get_global_rect().has_point(mouse_pos):
				swapped = child
				break
		var target_index = swapped.get_index()
		swapped.reparent(origin)
		origin.move_child(swapped, origin_index)
		swapped.current_container = origin
		card.reparent(target)
		target.move_child(card, target_index)
		card.current_container = target
		card.modulate.a = 1.0
		return
	origin.remove_child(card)
	card.modulate.a = 1.0

	if target == pool_grid:
		target.add_child(card)
		card.current_container = target
		card.hide_rank()
		return

	var insert_idx = target.get_child_count()
	for i in range(target.get_child_count()):
		var child = target.get_child(i)
		if mouse_pos.y < child.global_position.y + child.size.y / 2:
			insert_idx = i
			break

	target.add_child(card)
	target.move_child(card, insert_idx)
	card.current_container = target

func _update_all_ranks() -> void:
	for list in [dislike_list, neutral_list, like_list]:
		var rank = 1
		for card in list.get_children():
			if card is DishCard:
				card.show_rank(rank, "disliked" if list == dislike_list else ("liked" if list == like_list else "neutral"))
				rank += 1
	for card in pool_grid.get_children():
		if card is DishCard:
			card.hide_rank()
			
func _on_randomize() -> void:
	if submitted:
		return
	_cancel_drag()
	for list in [dislike_list, neutral_list, like_list]:
		for card in list.get_children():
			if card is DishCard:
				list.remove_child(card)
				pool_grid.add_child(card)
				card.hide_rank()

	var cards = pool_grid.get_children().filter(func(c): return c is DishCard)
	cards.shuffle()

	var targets = []
	for i in range(GROUP_SIZE): targets.append(dislike_list)
	for i in range(GROUP_SIZE): targets.append(neutral_list)
	for i in range(GROUP_SIZE): targets.append(like_list)

	for i in range(mini(cards.size(), targets.size())):
		var card = cards[i]
		var target = targets[i]
		pool_grid.remove_child(card)
		target.add_child(card)
		card.current_container = target

	_update_all_ranks()
	_check_confirm_valid()

func _check_confirm_valid() -> void:
	var dislike_count = dislike_list.get_child_count()
	var neutral_count = neutral_list.get_child_count()
	var like_count = like_list.get_child_count()
	confirm_btn.disabled = submitted or not (dislike_count == GROUP_SIZE and neutral_count == GROUP_SIZE and like_count == GROUP_SIZE and pool_grid.get_child_count() == 0)
	$Layout/Columns/DislikeColumn/DislikeHeader.text = "Dislike (%d/%d) — strongest first" % [dislike_count, GROUP_SIZE]
	$Layout/Columns/NeutralColumn/NeutralHeader.text = "Neutral (%d/%d)" % [neutral_count, GROUP_SIZE]
	$Layout/Columns/LikeColumn/LikeHeader.text = "Like (%d/%d) — strongest first" % [like_count, GROUP_SIZE]
	$Layout/Pool/PoolHeader.text = "Unsorted cards: %d — scroll to see more" % pool_grid.get_child_count()
	$Layout/Pool/Scroll.custom_minimum_size.y = 64 if pool_grid.get_child_count() == 0 else 210
	if pool_grid.get_child_count() == 0:
		$Layout/Pool/PoolHeader.text = "All cards ranked — drag here to unsort a card"

func _on_confirm() -> void:
	_check_confirm_valid()
	if confirm_btn.disabled:
		return
	_cancel_drag()
	submitted = true
	timer_running = false
	confirm_btn.disabled = true
	randomize_btn.disabled = true
	var prefs = _build_preferences()
	emit_signal("form_submitted", current_player, prefs)

func _cancel_drag() -> void:
	mouse_held = false
	if is_instance_valid(dragging_card):
		dragging_card.modulate.a = 1.0
	if is_instance_valid(drag_ghost):
		drag_ghost.queue_free()
	dragging_card = null
	drag_ghost = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_drag()

func _fill_remaining() -> void:
	# Timeout preserves the player's choices and only fills empty slots.
	_cancel_drag()
	var remaining = pool_grid.get_children()
	remaining.shuffle()
	for list in [dislike_list, neutral_list, like_list]:
		while list.get_child_count() < GROUP_SIZE and not remaining.is_empty():
			var card = remaining.pop_back()
			card.reparent(list)
			card.current_container = list
	_update_all_ranks()
	_check_confirm_valid()

func _build_preferences() -> Dictionary:
	var prefs = {}
	var category_map = {
		dislike_list: "disliked",
		neutral_list: "neutral",
		like_list: "liked",
	}
	for list in [dislike_list, neutral_list, like_list]:
		var rank = 1
		for card in list.get_children():
			if card is DishCard:
				prefs[card.item_id] = {
					"category": category_map[list],
					"rank": rank
				}
				rank += 1
	return prefs
