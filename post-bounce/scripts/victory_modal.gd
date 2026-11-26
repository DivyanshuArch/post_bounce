class_name VictoryModal
extends Control

## Celebratory victory modal shown upon completing a course.
## Displays par rating, 3 animated star rewards, gem tally, and action buttons.

signal next_course_requested()
signal replay_requested()
signal home_requested()
signal shop_requested()

@onready var panel_card: PanelContainer = $CenterContainer/PanelCard
@onready var title_label: Label = %TitleLabel
@onready var course_label: Label = %CourseLabel
@onready var shots_label: Label = %ShotsLabel
@onready var rating_badge: Label = %RatingBadge

@onready var star_1: TextureRect = %Star1
@onready var star_2: TextureRect = %Star2
@onready var star_3: TextureRect = %Star3

@onready var star_1_sub: Label = %Star1Sub
@onready var star_2_sub: Label = %Star2Sub
@onready var star_3_sub: Label = %Star3Sub

@onready var gems_reward_label: Label = %GemsRewardLabel

@onready var next_btn: Button = %NextButton
@onready var replay_btn: Button = %ReplayButton
@onready var shop_btn: Button = %ShopButton
@onready var home_btn: Button = %HomeButton

var is_active: bool = false

func _ready() -> void:
	visible = false
	modulate.a = 0.0

	next_btn.pressed.connect(func():
		if SoundManager:
			SoundManager.play_ui_click()
		close()
		next_course_requested.emit()
	)

	replay_btn.pressed.connect(func():
		if SoundManager:
			SoundManager.play_ui_click()
		close()
		replay_requested.emit()
	)

	shop_btn.pressed.connect(func():
		if SoundManager:
			SoundManager.play_ui_click()
		close()
		shop_requested.emit()
	)

	home_btn.pressed.connect(func():
		if SoundManager:
			SoundManager.play_ui_click()
		close()
		home_requested.emit()
	)

	for btn in [next_btn, replay_btn, shop_btn, home_btn]:
		btn.mouse_entered.connect(func():
			if SoundManager:
				SoundManager.play_ui_hover()
		)

func open(course_num: int, course_name: String, shots: int, par: int, diamonds_collected: int, total_diamonds: int) -> void:
	visible = true
	is_active = true
	panel_card.scale = Vector2(0.88, 0.88)
	panel_card.pivot_offset = panel_card.size * 0.5

	# Calculate stars
	var star_count: int = 1 # 1 star for clearing
	if shots <= par:
		star_count += 1
	if total_diamonds > 0 and diamonds_collected >= total_diamonds:
		star_count += 1
	elif total_diamonds == 0 and shots <= par:
		star_count = 3

	# Title & subtitle
	if shots == 1:
		title_label.text = "HOLE IN ONE!"
		title_label.modulate = Color("#fbbf24")
		rating_badge.text = "PERFECT SHOT!"
	elif shots <= par:
		title_label.text = "COURSE CLEAR!"
		title_label.modulate = Color("#4ade80")
		rating_badge.text = "UNDER PAR!"
	else:
		title_label.text = "COURSE CLEAR!"
		title_label.modulate = Color("#f4f2ec")
		rating_badge.text = "COMPLETED"

	course_label.text = "COURSE %d | %s" % [course_num, course_name.to_upper()]
	shots_label.text = "%d SHOTS  (PAR %d)" % [shots, par]

	# Calculate Gem reward
	var gems_earned: int = 15 # base
	if shots == 1:
		gems_earned += 30
	elif shots <= par:
		gems_earned += 15
	if total_diamonds > 0 and diamonds_collected >= total_diamonds:
		gems_earned += 20
	gems_reward_label.text = "+%d GEMS" % gems_earned

	# Reset star visuals
	var stars: Array[TextureRect] = [star_1, star_2, star_3]
	for s in stars:
		s.modulate = Color(0.3, 0.35, 0.32, 0.4)
		s.scale = Vector2(0.8, 0.8)

	star_1_sub.modulate = Color(0.6, 0.7, 0.65, 0.7)
	star_2_sub.modulate = Color(0.6, 0.7, 0.65, 0.7)
	star_3_sub.modulate = Color(0.6, 0.7, 0.65, 0.7)

	# Fade in modal
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Sequentially pop stars
	for i in range(star_count):
		var star_node := stars[i]
		var delay: float = 0.3 + float(i) * 0.18
		var tw_star := create_tween()
		tw_star.tween_interval(delay)
		tw_star.tween_callback(func():
			if SoundManager:
				SoundManager.play_diamond_chime()
			star_node.modulate = Color("#fbbf24")
			var tw_pop := create_tween()
			tw_pop.tween_property(star_node, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_pop.tween_property(star_node, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)
		)

	# Highlighting star requirement labels
	if star_count >= 1: star_1_sub.modulate = Color("#f4f2ec")
	if star_count >= 2: star_2_sub.modulate = Color("#f4f2ec")
	if star_count >= 3: star_3_sub.modulate = Color("#f4f2ec")

func close() -> void:
	if not is_active:
		return
	is_active = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_property(panel_card, "scale", Vector2(0.88, 0.88), 0.2)
	await tw.finished
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventKey and event.pressed:
		var k: InputEventKey = event
		if k.keycode in [KEY_SPACE, KEY_ENTER]:
			get_viewport().set_input_as_handled()
			next_btn.emit_signal("pressed")
		elif k.keycode == KEY_R:
			get_viewport().set_input_as_handled()
			replay_btn.emit_signal("pressed")
		elif k.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
			home_requested.emit()
