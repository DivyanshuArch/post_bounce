class_name HUD
extends CanvasLayer

## Minimalist HUD overlay with animated shot counter, course label,
## auto-fading controls hint, course clear banner, and corner controls.

signal reset_requested()
signal skip_requested()
signal sound_toggled()

@onready var shot_counter_lbl: Label = %ShotCounter
@onready var course_label_lbl: Label = %CourseLabel
@onready var controls_hint: PanelContainer = %ControlsHint
@onready var clear_banner: Control = %ClearBanner
@onready var clear_title: Label = %ClearTitle
@onready var clear_sub: Label = %ClearSub

@onready var reset_btn: Button = %ResetButton
@onready var skip_btn: Button = %SkipButton
@onready var sound_btn: Button = %SoundButton

var has_shot_once: bool = false

func _ready() -> void:
	clear_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	clear_banner.scale = Vector2(0.92, 0.92)

	reset_btn.pressed.connect(func(): reset_requested.emit())
	skip_btn.pressed.connect(func(): skip_requested.emit())
	sound_btn.pressed.connect(func(): sound_toggled.emit())

func update_course_info(course_num: int, shots: int, animate_pop: bool = false) -> void:
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
	var diamond_text: String = "  •  %d ★" % diamonds_collected if diamonds_collected > 0 else ""
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
	sound_btn.text = "🔇" if muted else "🔊"
