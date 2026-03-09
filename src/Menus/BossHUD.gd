extends Control
# ============================================================
# BOSS HUD — Health bar at bottom of screen
# ============================================================

var max_hp = 30
var current_hp = 30
var target_hp = 30  # for smooth bar animation
var boss_name_text = "Boss"

func _ready():
	visible = false

func _process(d):
	# Smooth health bar animation
	if current_hp != target_hp:
		current_hp = lerp(current_hp, target_hp, 8.0 * d)
		if abs(current_hp - target_hp) < 0.5:
			current_hp = target_hp
		update_bar()

func show_boss(name, hp, max_hp_val):
	boss_name_text = name
	max_hp = max_hp_val
	current_hp = hp
	target_hp = hp
	visible = true
	
	$BossName.text = boss_name_text
	update_bar()
	
	# Fade in
	modulate.a = 0
	for i in range(10):
		modulate.a += 0.1
		yield(get_tree().create_timer(0.03), "timeout")

func update_health(hp, max_hp_val):
	max_hp = max_hp_val
	target_hp = hp

func update_bar():
	if max_hp > 0:
		var percent = float(current_hp) / float(max_hp)
		$HealthBar.rect_size.x = 200 * percent
		
		# Color changes by health %
		if percent > 0.6:
			$HealthBar.color = Color(0.8, 0.1, 0.1, 1)
		elif percent > 0.3:
			$HealthBar.color = Color(0.9, 0.5, 0.1, 1)
		else:
			$HealthBar.color = Color(1.0, 0.1, 0.3, 1)

func hide_boss():
	visible = false
