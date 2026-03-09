extends "res://src/Enemies/BossBase.gd"
# ============================================================
# BOSS CASTER — Ranged Summoner (25 HP, 3 phases)
# ============================================================

export (PackedScene) var projectile_scene
export (PackedScene) var enemy_scene

func _ready():
	max_health = 25
	boss_name = "The Caster"
	contact_damage = 1
	intro_timeline = "caster_intro"
	phase2_timeline = "caster_phase2"
	defeat_timeline = "caster_defeat"
	attack_cooldown = 2.5
	speed = Vector2(60, 0)
	._ready()

var is_teleporting = false
var teleport_positions = [
	Vector2(60, 140),
	Vector2(160, 80),
	Vector2(260, 140),
	Vector2(160, 50),
]

# ============================================================
# BOSS AI
# ============================================================
func boss_ai(d):
	face_player()
	
	if is_attacking or is_teleporting:
		return
	
	if attack_cooldown_timer >= (attack_cooldown / attack_speed_mult):
		attack_cooldown_timer = 0.0
		choose_attack()

func choose_attack():
	var attacks = []
	
	match current_phase:
		1:
			attacks = ["volley", "teleport", "volley", "aimed_shot"]
		2:
			attacks = ["volley", "teleport", "homing_orb", "summon", "aimed_shot"]
		3:
			attacks = ["rapid_volley", "homing_orb", "beam", "teleport", "summon"]
	
	var chosen = attacks[randi() % attacks.size()]
	
	match chosen:
		"volley":
			telegraph(0.7, "attack_volley")
		"aimed_shot":
			telegraph(0.5, "attack_aimed_shot")
		"teleport":
			attack_teleport()
		"homing_orb":
			telegraph(0.8, "attack_homing_orb")
		"summon":
			telegraph(1.0, "attack_summon")
		"rapid_volley":
			telegraph(0.3, "attack_rapid_volley")
		"beam":
			telegraph(1.2, "attack_beam")

# ============================================================
# ATTACKS
# ============================================================

# --- Volley: 3 projectiles spread horizontally ---
func attack_volley():
	is_attacking = true
	var dir = get_dir_to_player()
	
	for i in range(3):
		if !is_instance_valid(self) or is_dying:
			break
		var angle = (i - 1) * 0.3  # -0.3, 0, 0.3
		spawn_projectile(Vector2(dir, 0).rotated(angle), 200)
		yield(get_tree().create_timer(0.1), "timeout")
	
	if is_instance_valid(self):
		is_attacking = false

# --- Aimed Shot: Single precise shot at player ---
func attack_aimed_shot():
	is_attacking = true
	var player = get_player()
	if player:
		var dir = (player.get_global_position() - get_global_position()).normalized()
		spawn_projectile(dir, 250)
	
	yield(get_tree().create_timer(0.2), "timeout")
	if is_instance_valid(self):
		is_attacking = false

# --- Teleport: Flash and appear at random position ---
func attack_teleport():
	is_teleporting = true
	
	# Fade out
	for i in range(5):
		if is_instance_valid(self):
			$Sprite.modulate.a -= 0.2
		yield(get_tree().create_timer(0.05), "timeout")
	
	if !is_instance_valid(self):
		return
	
	# Move to random position
	var new_pos = teleport_positions[randi() % teleport_positions.size()]
	set_global_position(new_pos)
	
	# Fade in
	for i in range(5):
		if is_instance_valid(self):
			$Sprite.modulate.a += 0.2
		yield(get_tree().create_timer(0.05), "timeout")
	
	if is_instance_valid(self):
		$Sprite.modulate.a = 1.0
		is_teleporting = false

# --- Homing Orb (Phase 2+): Slow tracking projectile ---
func attack_homing_orb():
	is_attacking = true
	
	var player = get_player()
	if player:
		var dir = (player.get_global_position() - get_global_position()).normalized()
		var orb = spawn_projectile(dir, 100)
		if orb:
			orb.is_homing = true
			orb.homing_strength = 2.0
			orb.lifetime = 4.0
			orb.damage = 2
	
	yield(get_tree().create_timer(0.3), "timeout")
	if is_instance_valid(self):
		is_attacking = false

# --- Summon (Phase 2+): Spawn 2 regular enemies ---
func attack_summon():
	is_attacking = true
	
	# Visual effect — purple flash
	$Sprite.modulate = Color(0.7, 0.2, 1.0, 1)
	
	for i in range(2):
		if enemy_scene and is_instance_valid(self):
			var enemy = enemy_scene.instance()
			var offset = Vector2((i * 2 - 1) * 40, -10)
			# Use signal to let level handle spawning
			emit_signal("boss_summon_enemy", enemy, get_global_position() + offset)
	
	yield(get_tree().create_timer(0.5), "timeout")
	if is_instance_valid(self):
		$Sprite.modulate = Color(1, 1, 1, 1)
		is_attacking = false

# --- Rapid Volley (Phase 3): Burst of 6 fast projectiles ---
func attack_rapid_volley():
	is_attacking = true
	var dir = get_dir_to_player()
	
	for i in range(6):
		if !is_instance_valid(self) or is_dying or is_stunned:
			break
		var angle = rand_range(-0.4, 0.4)
		spawn_projectile(Vector2(dir, 0).rotated(angle), 280)
		yield(get_tree().create_timer(0.08), "timeout")
	
	if is_instance_valid(self):
		is_attacking = false

# --- Beam (Phase 3): Horizontal beam across screen ---
func attack_beam():
	is_attacking = true
	
	# Charge up visual
	$Sprite.modulate = Color(1, 0.5, 0, 1)
	
	if has_node("/root/effects"):
		get_node("/root/effects").screen_shake(3.0, 0.8)
	
	# Fire 10 projectiles in a line
	var dir = get_dir_to_player()
	for i in range(10):
		if !is_instance_valid(self) or is_dying:
			break
		spawn_projectile(Vector2(dir, 0), 350)
		yield(get_tree().create_timer(0.05), "timeout")
	
	if is_instance_valid(self):
		$Sprite.modulate = Color(1, 1, 1, 1)
		is_attacking = false

# ============================================================
# HELPERS
# ============================================================
signal boss_summon_enemy(enemy, pos)
signal boss_projectile_spawned(proj)

func spawn_projectile(dir, spd):
	if projectile_scene:
		var proj = projectile_scene.instance()
		get_parent().add_child(proj)
		proj.setup(get_global_position() + Vector2(0, -5), dir, spd)
		emit_signal("boss_projectile_spawned", proj)
		return proj
	return null

# ============================================================
# PHASE CHANGES
# ============================================================
func on_phase_changed(phase):
	match phase:
		2:
			attack_cooldown = 2.0
		3:
			attack_cooldown = 1.2
