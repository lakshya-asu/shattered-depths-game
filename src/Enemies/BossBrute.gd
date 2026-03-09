extends "res://src/Enemies/BossBase.gd"
# ============================================================
# BOSS BRUTE — Melee Tank (30 HP, 3 phases)
# ============================================================

func _ready():
	max_health = 30
	boss_name = "The Brute"
	contact_damage = 2
	intro_timeline = "brute_intro"
	phase2_timeline = "brute_phase2"
	defeat_timeline = "brute_defeat"
	attack_cooldown = 2.0
	._ready()  # call parent

# Attack state
var current_attack = ""
var charge_dir = 0
var charge_timer = 0.0
var slam_active = false
var stomp_active = false

# ============================================================
# BOSS AI
# ============================================================
func boss_ai(d):
	face_player()
	
	if is_attacking:
		return
	
	if attack_cooldown_timer >= (attack_cooldown / attack_speed_mult):
		attack_cooldown_timer = 0.0
		choose_attack()

func choose_attack():
	var attacks = []
	
	match current_phase:
		1:
			attacks = ["stomp", "charge", "overhead_slam"]
		2:
			attacks = ["stomp", "charge", "overhead_slam", "ground_pound", "charge"]
		3:
			attacks = ["leap_slam", "rapid_combo", "ground_pound", "charge", "charge"]
	
	var chosen = attacks[randi() % attacks.size()]
	
	match chosen:
		"stomp":
			telegraph(0.6, "attack_stomp")
		"charge":
			telegraph(0.8, "attack_charge")
		"overhead_slam":
			telegraph(1.0, "attack_overhead_slam")
		"ground_pound":
			telegraph(0.7, "attack_ground_pound")
		"leap_slam":
			telegraph(0.5, "attack_leap_slam")
		"rapid_combo":
			telegraph(0.4, "attack_rapid_combo")

# ============================================================
# ATTACKS
# ============================================================

# --- Stomp: AOE around boss, 1 damage ---
func attack_stomp():
	is_attacking = true
	
	# Screen shake
	if has_node("/root/effects"):
		get_node("/root/effects").screen_shake(3.0, 0.15)
	
	# Damage nearby player
	var player = get_player()
	if player and get_global_position().distance_to(player.get_global_position()) < 40:
		if player.has_method("get_hurt_amount"):
			player.get_hurt_amount(1)
	
	yield(get_tree().create_timer(0.3), "timeout")
	if is_instance_valid(self):
		is_attacking = false

# --- Charge: Rush toward player, 2 damage ---
func attack_charge():
	is_attacking = true
	charge_dir = get_dir_to_player()
	change_facing("right" if charge_dir > 0 else "left")
	
	var charge_speed_val = 250 * attack_speed_mult
	
	for i in range(20):
		if !is_instance_valid(self) or is_dying or is_stunned:
			break
		move_and_slide(Vector2(charge_dir * charge_speed_val, speed.y), Vector2(0, -1))
		
		# Check hit
		var player = get_player()
		if player and get_global_position().distance_to(player.get_global_position()) < 20:
			if player.has_method("get_hurt_amount"):
				player.get_hurt_amount(2)
			break
		
		# Hit wall
		if is_on_wall():
			if has_node("/root/effects"):
				get_node("/root/effects").screen_shake(4.0, 0.2)
			break
		
		yield(get_tree().create_timer(0.02), "timeout")
	
	if is_instance_valid(self):
		is_attacking = false

# --- Overhead Slam: Jump up, slam down, 2 damage ---
func attack_overhead_slam():
	is_attacking = true
	
	# Jump up
	speed.y = -200
	yield(get_tree().create_timer(0.4), "timeout")
	
	if !is_instance_valid(self) or is_dying:
		return
	
	# Slam down
	speed.y = 400
	yield(get_tree().create_timer(0.3), "timeout")
	
	if !is_instance_valid(self) or is_dying:
		return
	
	# Impact
	if has_node("/root/effects"):
		get_node("/root/effects").screen_shake(5.0, 0.2)
	
	var player = get_player()
	if player and get_global_position().distance_to(player.get_global_position()) < 50:
		if player.has_method("get_hurt_amount"):
			player.get_hurt_amount(2)
	
	speed.y = 0
	is_attacking = false

# --- Ground Pound: Shockwave, 2 damage, wider range ---
func attack_ground_pound():
	is_attacking = true
	
	# Jump up  
	speed.y = -150
	yield(get_tree().create_timer(0.3), "timeout")
	
	if !is_instance_valid(self) or is_dying:
		return
	
	# Slam
	speed.y = 500
	yield(get_tree().create_timer(0.25), "timeout")
	
	if !is_instance_valid(self) or is_dying:
		return
	
	# Shockwave - wide range
	if has_node("/root/effects"):
		get_node("/root/effects").screen_shake(6.0, 0.3)
	
	var player = get_player()
	if player and abs(player.get_global_position().y - get_global_position().y) < 30:
		if player.has_method("get_hurt_amount"):
			player.get_hurt_amount(2)
	
	speed.y = 0
	is_attacking = false

# --- Leap Slam (Phase 3): Fast leaping slam, 3 damage ---
func attack_leap_slam():
	is_attacking = true
	var player = get_player()
	
	if player:
		var dir = get_dir_to_player()
		speed.y = -250
		
		for i in range(15):
			if !is_instance_valid(self) or is_dying or is_stunned:
				break
			move_and_slide(Vector2(dir * 200, speed.y), Vector2(0, -1))
			speed.y += 25
			
			if is_on_floor() and i > 5:
				break
			yield(get_tree().create_timer(0.02), "timeout")
	
	if !is_instance_valid(self) or is_dying:
		return
	
	# Impact
	if has_node("/root/effects"):
		get_node("/root/effects").screen_shake(7.0, 0.3)
	
	if player and get_global_position().distance_to(player.get_global_position()) < 45:
		if player.has_method("get_hurt_amount"):
			player.get_hurt_amount(3)
	
	speed.y = 0
	is_attacking = false

# --- Rapid Combo (Phase 3): 3 quick hits, 1 damage each ---
func attack_rapid_combo():
	is_attacking = true
	
	for hit in range(3):
		if !is_instance_valid(self) or is_dying or is_stunned:
			break
		
		face_player()
		var dir = get_dir_to_player()
		move_and_slide(Vector2(dir * 150, speed.y), Vector2(0, -1))
		
		var player = get_player()
		if player and get_global_position().distance_to(player.get_global_position()) < 25:
			if player.has_method("get_hurt_amount"):
				player.get_hurt_amount(1)
		
		yield(get_tree().create_timer(0.15), "timeout")
	
	if is_instance_valid(self):
		is_attacking = false

# ============================================================
# PHASE CHANGES
# ============================================================
func on_phase_changed(phase):
	match phase:
		2:
			attack_cooldown = 1.5
		3:
			attack_cooldown = 1.0
			contact_damage = 3
