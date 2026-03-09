extends Node

# ============================================================
# SCREEN EFFECTS SINGLETON
# Screen shake, hit pause, flash overlay, particles
# ============================================================

var camera = null
var shake_intensity = 0.0
var shake_duration = 0.0
var shake_timer = 0.0
var original_offset = Vector2.ZERO

# Flash overlay
var flash_rect = null

func _ready():
	pause_mode = PAUSE_MODE_PROCESS  # Works even when paused

func _process(d):
	# Screen shake
	if shake_timer > 0:
		shake_timer -= d
		if camera != null:
			camera.offset = original_offset + Vector2(
				rand_range(-shake_intensity, shake_intensity),
				rand_range(-shake_intensity, shake_intensity)
			)
		if shake_timer <= 0:
			if camera != null:
				camera.offset = original_offset
			shake_intensity = 0.0

func set_camera(cam):
	camera = cam
	if camera != null:
		original_offset = camera.offset

func screen_shake(intensity, duration):
	if intensity > shake_intensity:
		shake_intensity = intensity
		shake_duration = duration
		shake_timer = duration

func hit_pause(duration):
	# Freeze the game briefly for impact feel
	get_tree().paused = true
	var timer = get_tree().create_timer(duration, true)
	yield(timer, "timeout")
	get_tree().paused = false

func flash_screen(color, duration):
	# Flash the screen with a color overlay
	if flash_rect != null and is_instance_valid(flash_rect):
		flash_rect.queue_free()
	
	flash_rect = ColorRect.new()
	flash_rect.rect_position = Vector2(0, 0)
	flash_rect.rect_size = Vector2(320, 180)
	flash_rect.color = color
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add to root viewport
	get_tree().root.add_child(flash_rect)
	
	# Fade out
	var steps = 8
	var step_time = duration / steps
	for i in range(steps):
		yield(get_tree().create_timer(step_time), "timeout")
		if is_instance_valid(flash_rect):
			flash_rect.color.a -= 1.0 / steps
	
	if is_instance_valid(flash_rect):
		flash_rect.queue_free()
		flash_rect = null

func parry_flash():
	flash_screen(Color(1, 1, 1, 0.6), 0.15)
	screen_shake(4.0, 0.15)
	hit_pause(0.06)

func big_hit_effect():
	flash_screen(Color(1, 0.2, 0.2, 0.4), 0.2)
	screen_shake(5.0, 0.2)
	hit_pause(0.04)

func boss_death_effect():
	flash_screen(Color(1, 1, 0.8, 0.8), 0.5)
	screen_shake(8.0, 0.6)
	hit_pause(0.1)
