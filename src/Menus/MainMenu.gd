extends Control
# ============================================================
# MAIN MENU — Shattered Depths
# ============================================================

var title_bob_time = 0.0
var particles = []
var button_focus_index = 0

func _ready():
	# Initial button focus
	$Buttons/PlayButton.grab_focus()
	
	# Spawn floating particles
	_create_particles()

func _process(d):
	# Title gentle bob
	title_bob_time += d
	if has_node("Title"):
		$Title.rect_position.y = 12 + sin(title_bob_time * 1.5) * 2.0
	
	# Animate particles
	for p in particles:
		if is_instance_valid(p):
			p.rect_position.y -= p.get_meta("speed") * d
			p.modulate.a = 0.3 + sin(title_bob_time * p.get_meta("speed")) * 0.2
			if p.rect_position.y < -10:
				p.rect_position.y = 190
				p.rect_position.x = randi() % 320

func _create_particles():
	for i in range(15):
		var p = ColorRect.new()
		p.rect_size = Vector2(1, 1)
		p.rect_position = Vector2(randi() % 320, randi() % 180)
		p.color = Color(0.6, 0.4, 0.9, 0.3)
		p.set_meta("speed", 5 + randi() % 15)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		move_child(p, 1)  # Behind UI but above background
		particles.append(p)

func _on_PlayButton_pressed():
	$select_stream.play()
	# Brief delay for sound
	yield(get_tree().create_timer(0.15), "timeout")
	score.reset_run()
	get_tree().change_scene("res://src/Levels/ProceduralLevel.tscn")

func _on_QuitButton_pressed():
	$select_stream.play()
	yield(get_tree().create_timer(0.15), "timeout")
	get_tree().quit()

func _on_music_stream_finished():
	$music_stream.play()

func _on_button_hover():
	$move_stream.play()
