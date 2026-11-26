class_name HUD
extends CanvasLayer

## Minimalist HUD overlay with animated shot counter, course/par label,
## Home Hub button, Victory Modal, and corner controls.

signal reset_requested()
signal retry_requested()
signal skip_requested()
signal sound_toggled()
signal home_requested()
signal next_course_requested()
signal level_selected(course_index: int)

@onready var shot_counter_lbl: Label = %ShotCounter
@onready var course_label_lbl: Label = %CourseLabel
@onready var controls_hint: PanelContainer = %ControlsHint
@onready var clear_banner: Control = %ClearBanner
@onready var clear_title: Label = %ClearTitle
@onready var clear_sub: Label = %ClearSub

# Corner buttons
@onready var home_btn: Button = %HomeButton
@onready var reset_btn: Button = %ResetButton

# Modals
@onready var retry_modal: Control = %RetryModal
@onready var retry_modal_btn: Button = %RetryModalButton
@onready var retry_title: Label = %RetryTitle
@onready var retry_sub: Label = %RetrySub

@onready var victory_modal: VictoryModal = $VictoryModal
@onready var home_hub_modal: HomeHubModal = $HomeHubModal

var has_shot_once: bool = false
var is_retry_visible: bool = false

func _ready() -> void:
	clear_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	clear_banner.scale = Vector2(0.92, 0.92)

	if is_instance_valid(retry_modal):
		retry_modal.visible = false
		retry_modal.modulate = Color(1.0, 1.0, 1.0, 0.0)
		retry_modal.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				SoundManager.play_ui_click()
				hide_out_of_bounds()
				retry_requested.emit()
		)

	if is_instance_valid(retry_modal_btn):
		retry_modal_btn.pressed.connect(func():
			SoundManager.play_ui_click()
			hide_out_of_bounds()
			retry_requested.emit()
		)
		retry_modal_btn.mouse_entered.connect(func(): SoundManager.play_ui_hover())

	if is_instance_valid(home_btn):
		home_btn.pressed.connect(func():
			SoundManager.play_ui_click()
			open_home_hub("SHOP")
			home_requested.emit()
		)
		home_btn.mouse_entered.connect(func(): SoundManager.play_ui_hover())

	if is_instance_valid(reset_btn):
		reset_btn.pressed.connect(func():
			SoundManager.play_ui_click()
			reset_requested.emit()
		)
		reset_btn.mouse_entered.connect(func(): SoundManager.play_ui_hover())

	# Connect modals
	if is_instance_valid(victory_modal):
		victory_modal.next_course_requested.connect(func(): next_course_requested.emit())
		victory_modal.replay_requested.connect(func(): reset_requested.emit())
		victory_modal.shop_requested.connect(func(): open_home_hub("SHOP"))
		victory_modal.home_requested.connect(func(): open_home_hub("LEVELS"))

	if is_instance_valid(home_hub_modal):
		home_hub_modal.level_selected.connect(func(idx): level_selected.emit(idx))

func open_home_hub(initial_tab: String = "SHOP") -> void:
	if is_instance_valid(home_hub_modal):
		home_hub_modal.open(initial_tab)

func show_victory_modal(course_num: int, course_name: String, shots: int, par: int, diamonds_collected: int, total_diamonds: int) -> void:
	if is_instance_valid(victory_modal):
		victory_modal.open(course_num, course_name, shots, par, diamonds_collected, total_diamonds)

func show_out_of_bounds(reason: String = "The ball fell into the void") -> void:
	if not is_instance_valid(retry_modal):
		return
	is_retry_visible = true
	if is_instance_valid(retry_sub):
		retry_sub.text = reason

	var card: Control = retry_modal.get_node_or_null("Card")
	if is_instance_valid(card):
		card.scale = Vector2(0.85, 0.85)

	retry_modal.visible = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(retry_modal, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(card):
		tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_out_of_bounds() -> void:
	if not is_instance_valid(retry_modal) or not is_retry_visible:
		return
	is_retry_visible = false
	var tw := create_tween()
	tw.tween_property(retry_modal, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(func():
		if is_instance_valid(retry_modal):
			retry_modal.visible = false
	)

func update_course_info(course_num: int, shots: int, animate_pop: bool = false, custom_name: String = "", par: int = 2) -> void:
	if not custom_name.is_empty():
		course_label_lbl.text = "COURSE %d | %s | PAR %d" % [course_num, custom_name.to_upper(), par]
	else:
		course_label_lbl.text = "COURSE %d | PAR %d" % [course_num, par]
	shot_counter_lbl.text = str(shots)

	if animate_pop:
		_animate_counter_pop()

func _animate_counter_pop() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	shot_counter_lbl.pivot_offset = shot_counter_lbl.size * 0.5
	tw.tween_property(shot_counter_lbl, "scale", Vector2(1.22, 1.22), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(shot_counter_lbl, "modulate", Color("#fae366"), 0.08)
	tw.chain().tween_property(shot_counter_lbl, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(shot_counter_lbl, "modulate", Color("#f4f7f5"), 0.14)

func on_first_shot() -> void:
	if not has_shot_once:
		has_shot_once = true
		get_tree().create_timer(1.6).timeout.connect(func():
			var tw := create_tween()
			tw.tween_property(controls_hint, "modulate:a", 0.0, 0.8)
			tw.parallel().tween_property(controls_hint, "position:y", controls_hint.position.y + 10.0, 0.8)
		)

func show_course_clear(shots: int, diamonds_collected: int) -> void:
	var shot_text: String = "HOLE IN ONE!" if shots == 1 else "%d SHOTS" % shots
	var diamond_text: String = "  |  %d STARS" % diamonds_collected if diamonds_collected > 0 else ""
	clear_sub.text = shot_text + diamond_text

	clear_banner.visible = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(clear_banner, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE)
	tw.tween_property(clear_banner, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_course_clear() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(clear_banner, "modulate:a", 0.0, 0.2)
	tw.tween_property(clear_banner, "scale", Vector2(0.92, 0.92), 0.2)
