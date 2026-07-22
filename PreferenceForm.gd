extends Control

@onready var player_label = $Layout/Header/PlayerLabel
@onready var timer_label = $Layout/Header/TimerLabel
@onready var randomize_btn = $Layout/Header/Buttons/RandomizeButton
@onready var confirm_btn = $Layout/Header/Buttons/ConfirmButton
@onready var pool_grid = $Layout/Pool/PoolGrid
@onready var dislike_list = $Layout/Columns/DislikeColumn/DislikeList
@onready var neutral_list = $Layout/Columns/NeutralColumn/NeutralList
@onready var like_list = $Layout/Columns/LikeColumn/LikeList

const DISH_CARD = preload("res://DishCard.tscn")
const TIME_LIMIT = 120  

var dishes: Array = []
var current_player: int = 1
var time_remaining: float = TIME_LIMIT
var timer_running: bool = false
var dragging_card = null
var drag_offset: Vector2 = Vector2.ZERO
var drag_ghost = null  

var all_lists: Array = []  

signal form_submitted(player_idx: int, preferences: Dictionary)

func _ready() -> void:
	all_lists = [pool_grid, dislike_list, neutral_list, like_list]
	randomize_btn.pressed.connect(_on_randomize)
	confirm_btn.pressed.connect(_on_confirm)
	confirm_btn.disabled = true

func setup(player_idx: int, items: Array) -> void:
	current_player = player_idx
	player_label.text = "Player %d — Sort your dishes" % player_idx
	dishes = items
	_populate_pool()
	timer_running = true

func _populate_pool() -> void:
	for child in pool_grid.get_children():
		child.queue_free()
	for item in dishes:
		var card = DISH_CARD.instantiate()
		pool_grid.add_child(card)
		card.setup(item.id, item.name)
		card.current_container = pool_grid

func _process(delta: float) -> void:
	if timer_running:
		time_remaining -= delta
		if time_remaining <= 0:
			time_remaining = 0
			timer_running = false
			_on_randomize()
		var mins = int(time_remaining) / 60
		var secs = int(time_remaining) % 60
		timer_label.text = "%d:%02d" % [mins, secs]

	if drag_ghost:
		drag_ghost.global_position = get_global_mouse_position() + drag_offset
		
var drag_start_pos: Vector2 = Vector2.ZERO
var mouse_held: bool = false
var drag_threshold: float = 5.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_start_pos = event.global_position
				mouse_held = true
			else:
				mouse_held = false
				_end_drag(event.global_position)
	elif event is InputEventMouseMotion:
		if mouse_held and not dragging_card:
			if event.global_position.distance_to(drag_start_pos) > drag_threshold:
				_try_start_drag(drag_start_pos)
				
func _try_start_drag(mouse_pos: Vector2) -> void:
	for list in all_lists:
		for card in list.get_children():
			if card is DishCard and card.get_global_rect().has_point(mouse_pos):
				_start_drag(card, mouse_pos)
				return

func _start_drag(card: DishCard, mouse_pos: Vector2) -> void:
	dragging_card = card
	drag_offset = card.global_position - mouse_pos

	drag_ghost = card.duplicate()
	drag_ghost.modulate.a = 0.7
	add_child(drag_ghost)
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
		if list.get_global_rect().has_point(mouse_pos):
			return list
	return null

func _drop_card_into(card: DishCard, target: Control, mouse_pos: Vector2) -> void:
	card.get_parent().remove_child(card)
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
				card.show_rank(rank)
				rank += 1
	for card in pool_grid.get_children():
		if card is DishCard:
			card.hide_rank()
			
func _on_randomize() -> void:
	for list in [dislike_list, neutral_list, like_list]:
		for card in list.get_children():
			if card is DishCard:
				list.remove_child(card)
				pool_grid.add_child(card)
				card.hide_rank()

	var cards = pool_grid.get_children().filter(func(c): return c is DishCard)
	cards.shuffle()

	var targets = []
	for i in range(7): targets.append(dislike_list)
	for i in range(7): targets.append(neutral_list)
	for i in range(7): targets.append(like_list)

	for i in range(cards.size()):
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
	confirm_btn.disabled = not (dislike_count == 7 and neutral_count == 7 and like_count == 7)

func _on_confirm() -> void:
	timer_running = false
	var prefs = _build_preferences()
	emit_signal("form_submitted", current_player, prefs)

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
