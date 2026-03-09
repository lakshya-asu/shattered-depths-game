extends KinematicBody2D
# ============================================================
# BOSS BASE CLASS — Souls-like multi-phase boss
# ============================================================

# --- Override in subclass ---
export (int) var max_health = 30
export (String) var boss_name = "Boss"
export (String) var intro_timeline = ""
export (String) var phase2_timeline = ""
export (String) var defeat_timeline = ""

# --- State ---
var health = 0
var current_phase = 1
var phase_thresholds = [1.0, 0.6, 0.3]  # phases trigger at these HP%
var is_dying = false
var is_stunned = false
var stun_timer = 0.0
var stun_duration = 0.0
var is_attacking = false
var is_telegraphing = false
var telegraph_timer = 0.0
var attack_speed_mult = 1.0  # enrage multiplier
var phase_timer = 0.0
var enrage_time = 45.0  # seconds before enrage per phase
var is_in_dialogue = false

# --- Physics ---
var speed = Vector2(80, 0)
var currentVelocity = Vector2(0, 1)
var currentFacing = "left"

# --- Combat ---
var contact_damage = 2
var attack_cooldown = 1.5
var attack_cooldown_timer = 0.0

# --- Signals ---
signal boss_phase_changed(phase)
signal boss_defeated()
signal boss_health_changed(hp, max_hp)
signal boss_dialogue_started()
signal boss_dialogue_ended()

func _ready():
	health = max_health
	add_to_group("enemy")
	add_to_group("boss")
	emit_signal("boss_health_changed", health, max_health)
	
	# Start with intro dialogue
	if intro_timeline != "":
		call_deferred("start_dialogue", intro_timeline)

func _physics_process(d):
	if is_dying or is_in_dialogue:
		return
	
	# --- Stun ---
	if is_stunned:
		stun_timer += d
		$Sprite.modulate = Color(1, 1, 0.3, 1) if fmod(stun_timer, 0.2) < 0.1 else Color(1, 1, 0.6, 1)
		if stun_timer >= stun_duration:
			is_stunned = false
			stun_timer = 0.0
			$Sprite.modulate = Color(1, 1, 1, 1)
		return
	
	# --- Enrage timer ---
	phase_timer += d
	if phase_timer >= enrage_time:
		attack_speed_mult = 1.5
	
	# --- Attack cooldown ---
	attack_cooldown_timer += d
	
	# --- Gravity ---
	if !is_on_floor():
		speed.y += 350 * d
	else:
		speed.y = 0
	
	# --- Telegraph ---
	if is_telegraphing:
		telegraph_timer += d
		$Sprite.modulate = Color(1, 0.2, 0.2, 1) if fmod(telegraph_timer, 0.12) < 0.06 else Color(1, 0.5, 0.5, 1)
		return
	
	# --- Boss AI (override in subclass) ---
	boss_ai(d)
	
	# --- Movement ---
	var movement = move_and_slide(speed * currentVelocity, Vector2(0, -1))

# --- Override in subclass ---
func boss_ai(d):
	pass

# ============================================================
# DAMAGE / PHASE
# ============================================================
func take_damage(amount):
	if is_dying or is_in_dialogue:
		return
	
	health -= amount
	emit_signal("boss_health_changed", health, max_health)
	
	# Flash on hit
	$Sprite.modulate = Color(1, 0.3, 0.3, 1)
	yield(get_tree().create_timer(0.1), "timeout")
	if is_instance_valid(self) and !is_dying:
		$Sprite.modulate = Color(1, 1, 1, 1)
	
	# Screen shake
	if has_node("/root/effects"):
		get_node("/root/effects").screen_shake(2.0, 0.1)
	
	# Check phase transitions
	var hp_percent = float(health) / float(max_health)
	
	if current_phase == 1 and hp_percent <= phase_thresholds[1]:
		enter_phase(2)
	elif current_phase == 2 and hp_percent <= phase_thresholds[2]:
		enter_phase(3)
	
	if health <= 0:
		die()

func enter_phase(phase):
	current_phase = phase
	phase_timer = 0.0
	attack_speed_mult = 1.0
	emit_signal("boss_phase_changed", phase)
	
	# Phase transition dialogue
	if phase == 2 and phase2_timeline != "":
		start_dialogue(phase2_timeline)
	
	# Screen shake on phase change
	if has_node("/root/effects"):
		get_node("/root/effects").screen_shake(5.0, 0.3)
	
	# Override in subclass for phase-specific behavior
	on_phase_changed(phase)

# Override this
func on_phase_changed(phase):
	pass

# ============================================================
# STUN (boss-resistant: shorter stun)  
# ============================================================
func get_stunned(duration):
	is_stunned = true
	stun_timer = 0.0
	stun_duration = min(duration, 0.8)  # bosses resist long stuns
	is_attacking = false
	is_telegraphing = false
	telegraph_timer = 0.0
	currentVelocity.x = 0

# ============================================================
# TELEGRAPH
# ============================================================
func telegraph(duration, callback_method):
	is_telegraphing = true
	telegraph_timer = 0.0
	var actual_duration = duration / attack_speed_mult
	yield(get_tree().create_timer(actual_duration), "timeout")
	if is_instance_valid(self) and !is_dying and !is_stunned and !is_in_dialogue:
		is_telegraphing = false
		$Sprite.modulate = Color(1, 1, 1, 1)
		if has_method(callback_method):
			call(callback_method)

# ============================================================
# DIALOGUE (uses Dialogic 1.x)
# ============================================================
func start_dialogue(timeline_path):
	is_in_dialogue = true
	emit_signal("boss_dialogue_started")
	
	# Load and show dialogue using Dialogic
	# Dialogic 1.x API: Dialogic.start(timeline_resource_path)
	var dialog = Dialogic.start(timeline_path)
	if dialog != null:
		get_tree().root.add_child(dialog)
		dialog.connect("dialogic_signal", self, "_on_dialogic_signal")
		dialog.connect("timeline_end", self, "_on_dialogue_end")
	else:
		# If Dialogic fails, just continue
		_on_dialogue_end("")

func _on_dialogue_end(_timeline_name = ""):
	is_in_dialogue = false
	emit_signal("boss_dialogue_ended")

func _on_dialogic_signal(argument):
	pass

# ============================================================
# DEATH
# ============================================================
func die():
	is_dying = true
	is_attacking = false
	is_telegraphing = false
	currentVelocity = Vector2.ZERO
	
	# Death dialogue
	if defeat_timeline != "":
		start_dialogue(defeat_timeline)
		yield(self, "boss_dialogue_ended")
	
	emit_signal("boss_defeated")
	
	# Screen shake on death
	if has_node("/root/effects"):
		get_node("/root/effects").boss_death_effect()
	
	# Death animation
	$Sprite.modulate = Color(1, 1, 1, 1)
	var tween = get_tree().create_tween() if Engine.has_method("create_tween") else null
	# Fade out and fall
	for i in range(10):
		yield(get_tree().create_timer(0.1), "timeout")
		if is_instance_valid(self):
			$Sprite.modulate.a -= 0.1
			$Sprite.rotation_degrees += 6
	
	if is_instance_valid(self):
		queue_free()

# ============================================================
# FACING
# ============================================================
func face_player():
	var players = get_tree().get_nodes_in_group("player")
	if !players.empty():
		var player = players[0]
		if player.get_global_position().x < get_global_position().x:
			change_facing("left")
		else:
			change_facing("right")

func change_facing(dir):
	if currentFacing != dir:
		if dir == "right":
			$Sprite.set_scale(Vector2(1, 1))
		elif dir == "left":
			$Sprite.set_scale(Vector2(-1, 1))
		currentFacing = dir

func get_player():
	var players = get_tree().get_nodes_in_group("player")
	if !players.empty():
		return players[0]
	return null

func get_dir_to_player():
	var player = get_player()
	if player:
		return 1 if player.get_global_position().x > get_global_position().x else -1
	return 1
