class_name HUD
extends CanvasLayer

## Minimalist HUD overlay with animated shot counter, course label,
## auto-fading controls hint, course clear banner, and corner controls.

signal reset_requested()
signal skip_requested()
signal sound_toggled()
signal retry_requested()

@onready var shot_counter_lbl: Label = %ShotCounter
@onready var course_label_lbl: Label = %CourseLabel
@onready var controls_hint: PanelContainer = %ControlsHint
@onready var clear_banner: Control = %ClearBanner
@onready var clear_title: Label = %ClearTitle
@onready var clear_sub: Label = %ClearSub

@onready var reset_btn: Button = %ResetButton
@onready var skip_btn: Button = %SkipButton
@onready var sound_btn: Button = %SoundButton

@onready var retry_modal: Control = %RetryModal
@onready var retry_modal_btn: Button = %RetryModalButton
@onready var retry_title: Label = %RetryTitle
@onready var retry_sub: Label = %RetrySub

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

	reset_btn.pressed.connect(func():
		SoundManager.play_ui_click()
		reset_requested.emit()
	)
	skip_btn.pressed.connect(func():
		SoundManager.play_ui_click()
		skip_requested.emit()
	)
	sound_btn.pressed.connect(func():
		SoundManager.play_ui_click()
		sound_toggled.emit()
	)

	for btn in [reset_btn, skip_btn, sound_btn]:
		btn.mouse_entered.connect(func(): SoundManager.play_ui_hover())

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


const ICON_SOUND_ON = preload("res://assets/icons/icon_sound_on.svg")
const ICON_SOUND_OFF = preload("res://assets/icons/icon_sound_off.svg")

func update_course_info(course_num: int, shots: int, animate_pop: bool = false, custom_name: String = "") -> void:
	if not custom_name.is_empty():
		course_label_lbl.text = "COURSE %d | %s" % [course_num, custom_name.to_upper()]
	else:
		course_label_lbl.text = "COURSE %d" % course_num
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

func update_sound_icon(muted: bool) -> void:
	if is_instance_valid(sound_btn):
		sound_btn.icon = ICON_SOUND_OFF if muted else ICON_SOUND_ON
		sound_btn.text = ""

