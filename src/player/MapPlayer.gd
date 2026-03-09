extends KinematicBody2D

# ============================================================
# INPUT COMMANDS
# ============================================================
var controls = []
var commands = {
	"move_jump" : {
		"flag" : false,
		"input" : [KEY_K, JOY_BUTTON_0],
		"id" : "jump"
	},
	"look_up" : {
		"flag" : false,
		"input" : [KEY_W, JOY_DPAD_UP],
		"id" : "look_up"
	},
	"look_down" : {
		"flag" : false,
		"input" : [KEY_S, JOY_DPAD_DOWN],
		"id" : "look_down"
	},
	"shoot" : {
		"flag" : false,
		"input" : [KEY_J, JOY_BUTTON_2],
		"id" : "shoot"
	},
	"move_left" : {
		"flag" : false,
		"input" : [KEY_A, JOY_DPAD_LEFT],
		"id" : "left"
	},
	"move_right" : {
		"flag" : false,
		"input" : [KEY_D, JOY_DPAD_RIGHT],
		"id" : "right"
	},
	"dash" : {
		"flag" : false,
		"input" : [KEY_L, JOY_BUTTON_3],
		"id" : "dash"
	},
	"melee" : {
		"flag" : false,
		"input" : [KEY_I, JOY_BUTTON_1],
		"id" : "melee"
	},
	"missile" : {
		"flag" : false,
		"input" : [KEY_U, JOY_BUTTON_4],
		"id" : "missile"
	},
	"weapon_next" : {
		"flag" : false,
		"input" : [KEY_E],
		"id" : "weapon_next"
	},
	"weapon_prev" : {
		"flag" : false,
		"input" : [KEY_Q],
		"id" : "weapon_prev"
	},
}

# ============================================================
# SCENES / REFS
# ============================================================
export (PackedScene) var bullet_reference
var melee_hitbox_scene = preload("res://src/player/MeleeHitbox.tscn")
var missile_scene = preload("res://src/player/Missile.tscn")

# ============================================================
# WEAPON MANAGER
# ============================================================
var weapon_manager = preload("res://src/player/WeaponManager.gd").new()

# ============================================================
# CORE STATE
# ============================================================
var speed = Vector2(100, 0)
var isDying = false
var currentVelocity = Vector2(0, 1)
var canJump = false
var canMove = true
var currentState = ""
var currentFacing = "right"

# ============================================================
# JUMP
# ============================================================
var currentJumps = 0
var maxJumps = 2

# ============================================================
# DASH
# ============================================================
var isDashing = false
var dash_speed = 400.0
var dash_duration = 0.15
var dash_timer = 0.0
var dash_cooldown = 0.6
var dash_cooldown_timer = 999.0  # ready to dash immediately

# ============================================================
# DODGE
# ============================================================
var isDodging = false
var dodge_speed = 300.0
var dodge_duration = 0.2
var dodge_timer = 0.0
var dodge_direction = 1

# ============================================================
# MELEE / PARRY
# ============================================================
var melee_combo = 0            # 0, 1, 2
var melee_combo_timer = 0.0
var melee_combo_window = 0.4   # seconds to chain next hit
var melee_damage = [1, 1, 2]   # damage per combo step
var parry_window = 0.1         # first 0.1s of melee = parry
var melee_attack_timer = 0.0
var is_melee_active = false
var melee_cooldown = 0.25
var melee_cooldown_timer = 999.0

# ============================================================
# SHOOTING
# ============================================================
onready var bullet_spawn = $image/gun/gun/bullet_spawn
var shoot_count = 1.0
var shoot_down = false
var shoot_up = false

# ============================================================
# MISSILES
# ============================================================
var missile_count = 3
var missile_max = 5
var missile_cooldown = 1.0
var missile_cooldown_timer = 999.0

# ============================================================
# HEALTH
# ============================================================
var health = 4
var isInvulnerable = false

# ============================================================
# SIGNALS
# ============================================================
signal shoot_fired(instance, start_pos, direction)
signal melee_attack(hitbox_instance)
signal missile_fired(missile_instance)
signal game_over()
signal health_down()
signal weapon_changed(weapon_name)
signal stamina_changed(dash_cd, melee_cd)

# ============================================================
# INIT
# ============================================================
func _ready():
	$image/gun/gun/anim.play("idle")
	change_anim("idle")
	
	for cmd in commands.values():
		for input in cmd.input:
			controls.append(input)
	
	add_child(weapon_manager)

# ============================================================
# INPUT HANDLING
# ============================================================
func _input(ev):
	if isDying:
		return
	
	if ev is InputEventKey:
		if controls.has(ev.scancode):
			for cmd in commands.values():
				if cmd.input.has(ev.scancode):
					if !cmd.flag and ev.pressed:
						just_pressed_events(cmd.id)
					if cmd.flag and !ev.pressed:
						just_released_events(cmd.id)
					cmd.flag = ev.pressed
	
	if ev is InputEventJoypadButton:
		if controls.has(ev.button_index):
			for cmd in commands.values():
				if cmd.input.has(ev.button_index):
					if !cmd.flag and ev.pressed:
						just_pressed_events(cmd.id)
					if cmd.flag and !ev.pressed:
						just_released_events(cmd.id)
					cmd.flag = ev.pressed

# ============================================================
# PHYSICS
# ============================================================
func _physics_process(d):
	if isDying:
		return
	
	# --- Update cooldown timers ---
	dash_cooldown_timer += d
	melee_cooldown_timer += d
	missile_cooldown_timer += d
	
	# --- Melee combo timer ---
	if melee_combo > 0:
		melee_combo_timer += d
		if melee_combo_timer >= melee_combo_window:
			melee_combo = 0
			melee_combo_timer = 0.0
	
	# --- Melee active window (for parry detection) ---
	if is_melee_active:
		melee_attack_timer += d
		if melee_attack_timer >= 0.2:
			is_melee_active = false
			melee_attack_timer = 0.0
	
	# --- DASH STATE ---
	if isDashing:
		dash_timer += d
		if dash_timer >= dash_duration:
			isDashing = false
			dash_timer = 0.0
			# Restore hitbox
			_restore_hitbox()
		else:
			# Dash movement
			var dash_dir = 1 if currentFacing == "right" else -1
			move_and_slide(Vector2(dash_dir * dash_speed, 0), Vector2(0, -1))
			# Flicker effect
			$image.modulate.a = 0.3 if fmod(dash_timer, 0.06) < 0.03 else 0.8
			return
	
	# --- DODGE STATE ---
	if isDodging:
		dodge_timer += d
		if dodge_timer >= dodge_duration:
			isDodging = false
			dodge_timer = 0.0
			_restore_hitbox()
		else:
			move_and_slide(Vector2(dodge_direction * dodge_speed, 0), Vector2(0, -1))
			$image.modulate.a = 0.4 if fmod(dodge_timer, 0.05) < 0.025 else 0.7
			return
	
	# Reset modulate
	if !isDashing and !isDodging:
		$image.modulate.a = 1.0
	
	# --- NORMAL MOVEMENT ---
	currentVelocity = Vector2(0, 1)
	
	if canMove:
		if commands.move_left.flag:
			currentVelocity.x -= 1
		if commands.move_right.flag:
			currentVelocity.x += 1
	var movement = move_and_slide(speed * currentVelocity, Vector2(0, -1))
	
	if !is_on_floor():
		speed.y += 350 * d
	else:
		if shoot_down:
			shoot_down = false
			$image/gun/gun/anim.play("idle")
		canJump = true
		currentJumps = 0
		if !commands.move_jump.flag:
			speed.y = 0
	
	if movement.y == 0:
		if movement.x == 0:
			change_anim("idle")
		else:
			change_anim("run")
	else:
		if commands.look_down.flag:
			$image/gun/gun/anim.play("look_down")
			shoot_down = true
		
		if speed.y > 0:
			change_anim("jump_down")
		else:
			change_anim("jump_up")
	
	if movement.x < 0:
		change_facing("left")
	elif movement.x > 0:
		change_facing("right")
	
	if is_on_ceiling():
		speed.y += 100
	
	# --- SHOOTING (hold to fire) ---
	var fire_rate = weapon_manager.get_fire_rate()
	if commands.shoot.flag and shoot_count > fire_rate:
		shoot()
	
	if shoot_count < fire_rate:
		shoot_count += d

# ============================================================
# JUST PRESSED / RELEASED EVENTS
# ============================================================
func just_pressed_events(cmd_id):
	match(cmd_id):
		"jump":
			if canJump:
				jump()
				change_anim("jump_up")
		"look_up":
			$image/gun/gun/anim.play("look_up")
			shoot_up = true
		"look_down":
			if !speed.y == 0:
				$image/gun/gun/anim.play("look_down")
				shoot_down = true
		"shoot":
			shoot()
		"dash":
			try_dash()
		"melee":
			try_melee()
		"missile":
			try_missile()
		"weapon_next":
			weapon_manager.next_weapon()
			emit_signal("weapon_changed", weapon_manager.get_weapon_name())
		"weapon_prev":
			weapon_manager.prev_weapon()
			emit_signal("weapon_changed", weapon_manager.get_weapon_name())

func just_released_events(cmd_id):
	match(cmd_id):
		"look_up":
			$image/gun/gun/anim.play("idle")
			shoot_up = false
		"look_down" :
			$image/gun/gun/anim.play("idle")
			shoot_down = false

# ============================================================
# MOVEMENT ACTIONS
# ============================================================
func change_facing(dir):
	if currentFacing != dir:
		if dir == "right":
			$image.set_scale(Vector2(1, 1))
		elif dir == "left":
			$image.set_scale(Vector2(-1, 1))
		currentFacing = dir

func jump():
	currentJumps += 1 
	$jump_stream.play()
	speed.y = -150
	if currentJumps == maxJumps:
		canJump = false

func change_anim(newState):
	if isDying:
		pass
	if currentState != newState and $image/anim.has_animation(newState):
		currentState = newState
		if newState == "die":
			stopCommands()
		if $image/anim.current_animation != "hurt":
			$image/anim.play(newState)

func stopCommands():
	isDying = true
	for cmd in commands.values():
		cmd.flag = false

func setMovable(value : bool):
	canMove = value
	if !value:
		for cmd in commands.values():
			cmd.flag = false

func go_to_position(vec):
	pass

# ============================================================
# DASH
# ============================================================
func try_dash():
	if dash_cooldown_timer < dash_cooldown:
		return
	
	# If on ground and holding down → dodge roll instead
	if is_on_floor() and commands.look_down.flag:
		try_dodge()
		return
	
	isDashing = true
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	
	# Remove hitbox for i-frames
	_remove_hitbox()
	
	# Play dash sound (reuse jump sound)
	$jump_stream.play()

# ============================================================
# DODGE
# ============================================================
func try_dodge():
	isDodging = true
	dodge_timer = 0.0
	dash_cooldown_timer = 0.0  # shares cooldown with dash
	
	# Dodge in movement direction, or facing direction
	if commands.move_left.flag:
		dodge_direction = -1
	elif commands.move_right.flag:
		dodge_direction = 1
	else:
		dodge_direction = 1 if currentFacing == "right" else -1
	
	# i-frames
	_remove_hitbox()
	$jump_stream.play()

# ============================================================
# MELEE / PARRY
# ============================================================
func try_melee():
	if melee_cooldown_timer < melee_cooldown:
		return
	
	melee_cooldown_timer = 0.0
	is_melee_active = true
	melee_attack_timer = 0.0
	
	# Check if within parry window (first 0.1s of attack = parry)
	var is_parry_attempt = true  # first frame of melee = always parry window
	
	# Advance combo
	if melee_combo_timer < melee_combo_window and melee_combo > 0:
		melee_combo = min(melee_combo + 1, 2)
	else:
		melee_combo = 0
	
	var dmg = melee_damage[melee_combo]
	melee_combo_timer = 0.0
	
	# Spawn melee hitbox
	var hitbox = melee_hitbox_scene.instance()
	var dir = 1 if currentFacing == "right" else -1
	
	get_parent().add_child(hitbox)
	hitbox.setup(get_global_position(), dir, dmg, is_parry_attempt)
	hitbox.connect("melee_hit", self, "_on_melee_hit")
	hitbox.connect("parry_success", self, "_on_parry_success")
	
	emit_signal("melee_attack", hitbox)
	
	# Advance combo for next hit
	melee_combo += 1
	if melee_combo > 2:
		melee_combo = 0
	
	# Play shoot sound for melee (reuse)
	$shoot_stream.play()

func _on_melee_hit(enemy, damage):
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
	else:
		enemy.health -= damage
		if enemy.health <= 0:
			enemy.die()

func _on_parry_success(enemy):
	if enemy.has_method("get_stunned"):
		enemy.get_stunned(1.5)
	$collect_stream.play()  # parry success sound
	# Full parry effect: screen flash + shake + hit pause
	if has_node("/root/effects"):
		get_node("/root/effects").parry_flash()

# ============================================================
# SHOOTING (now uses WeaponManager)
# ============================================================
func shoot():
	var fire_rate = weapon_manager.get_fire_rate()
	if fire_rate > shoot_count:
		return
	shoot_count = 0
	
	var burst = weapon_manager.get_burst_count()
	var spread = weapon_manager.get_spread()
	
	for i in range(burst):
		var dir
		if shoot_up:
			dir = Vector2(0, -1.0).rotated(rand_range(-spread, spread))
		elif shoot_down:
			dir = Vector2(0, 1.0).rotated(rand_range(-spread, spread))
		else:
			dir = Vector2(1.0, 0).rotated(rand_range(-spread, spread))
			if currentFacing == "left":
				dir = Vector2(-dir.x, dir.y)
		
		var bullet = bullet_reference.instance()
		# Set bullet properties from weapon
		bullet.speed = weapon_manager.get_bullet_speed()
		bullet.lifetime = weapon_manager.get_bullet_lifetime()
		bullet.damage = weapon_manager.get_damage()
		
		$shoot_stream.play()
		emit_signal("shoot_fired", bullet, bullet_spawn.get_global_position(), dir)

# ============================================================
# MISSILES
# ============================================================
func try_missile():
	if missile_count <= 0:
		return
	if missile_cooldown_timer < missile_cooldown:
		return
	
	missile_cooldown_timer = 0.0
	missile_count -= 1
	
	var missile = missile_scene.instance()
	var dir = Vector2(1, 0) if currentFacing == "right" else Vector2(-1, 0)
	
	get_parent().add_child(missile)
	missile.setup(bullet_spawn.get_global_position(), dir)
	
	emit_signal("missile_fired", missile)
	$shoot_stream.play()

func add_missiles(amount):
	missile_count = min(missile_count + amount, missile_max)

# ============================================================
# HEALTH / DAMAGE
# ============================================================
func get_hurt():
	if isDashing or isDodging:
		return  # i-frames
	if $hitbox.monitoring == false:
		pass
	else:
		remove_child($hitbox)
		health -= 1
		if health <= 0:
			change_anim("die")
			$death_stream.play()
		else:
			$image/anim.play("hurt")
			$hurt_player.play("hurt")
			emit_signal("health_down")
			$hurt_stream.play()
			# Screen shake on taking damage
			if has_node("/root/effects"):
				get_node("/root/effects").screen_shake(2.0, 0.1)

func get_hurt_amount(amount):
	if isDashing or isDodging:
		return  # i-frames
	if $hitbox.monitoring == false:
		pass
	else:
		remove_child($hitbox)
		health -= amount
		if health <= 0:
			change_anim("die")
			$death_stream.play()
		else:
			$image/anim.play("hurt")
			$hurt_player.play("hurt")
			emit_signal("health_down")
			$hurt_stream.play()
			# Big hit effect for strong attacks
			if has_node("/root/effects"):
				if amount >= 2:
					get_node("/root/effects").big_hit_effect()
				else:
					get_node("/root/effects").screen_shake(2.0, 0.1)

func play_pick_up_sound():
	$collect_stream.stop()
	$collect_stream.play()

# ============================================================
# HITBOX MANAGEMENT (for i-frames)
# ============================================================
onready var hitbox_ref = $hitbox.duplicate()

func _remove_hitbox():
	if has_node("hitbox"):
		remove_child($hitbox)

func _restore_hitbox():
	if !has_node("hitbox"):
		var newHitbox = hitbox_ref.duplicate()
		add_child(newHitbox)
		newHitbox.set_name("hitbox")
		newHitbox.connect("body_entered", self, "_on_hitbox_body_entered")

# ============================================================
# ANIMATION CALLBACKS
# ============================================================
func _on_anim_animation_finished(anim_name):
	if anim_name == "hurt":
		change_anim("idle")
	elif anim_name == "die":
		emit_signal("game_over")

func _on_hitbox_body_entered(body):
	if body.get_groups().has("enemy"):
		get_hurt()

func _on_hurt_player_animation_finished(anim_name):
	if anim_name == "hurt":
		_restore_hitbox()

func _on_bounce_checker_area_entered(area):
	if area.get_groups().has("bounce"):
		if $bounce_checker.get_global_position().y > area.get_global_position().y:
			$jump_stream.play()
			speed.y = -120
