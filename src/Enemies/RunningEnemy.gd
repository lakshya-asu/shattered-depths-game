extends KinematicBody2D
class_name Enemy


var health = 2

func _ready():
	randomize()
	$Sprite/anim.play("idle")

var speed = Vector2(100, 0)
var currentVelocity = Vector2(0, 1)

var change_state_time = 2.0
var change_state_count = 0

var majorState = "idle"

# ============================================================
# STUN SYSTEM (for parry)
# ============================================================
var is_stunned = false
var stun_timer = 0.0
var stun_duration = 0.0

# ============================================================
# ATTACK TELEGRAPH
# ============================================================
var is_telegraphing = false
var telegraph_timer = 0.0
var telegraph_duration = 0.5
var is_charging = false
var charge_speed = 200
var charge_target = null

func _physics_process(d):
	
	# --- Stun state ---
	if is_stunned:
		stun_timer += d
		# Flash yellow while stunned
		$Sprite.modulate = Color(1, 1, 0.3, 1) if fmod(stun_timer, 0.2) < 0.1 else Color(1, 1, 0.6, 1)
		if stun_timer >= stun_duration:
			is_stunned = false
			stun_timer = 0.0
			$Sprite.modulate = Color(1, 1, 1, 1)
		return
	
	if !is_dying:
		
		# --- Attack telegraph ---
		if is_telegraphing:
			telegraph_timer += d
			$Sprite.modulate = Color(1, 0.3, 0.3, 1) if fmod(telegraph_timer, 0.15) < 0.075 else Color(1, 0.6, 0.6, 1)
			if telegraph_timer >= telegraph_duration:
				is_telegraphing = false
				telegraph_timer = 0.0
				$Sprite.modulate = Color(1, 1, 1, 1)
				start_charge()
			return
		
		# --- Charge attack ---
		if is_charging:
			var charge_dir = 1 if currentFacing == "right" else -1
			move_and_slide(Vector2(charge_dir * charge_speed, speed.y), Vector2(0, -1))
			if !is_on_floor():
				speed.y += 350 * d
			else:
				speed.y = 0
			# Stop charging after hitting a wall
			if is_on_wall():
				is_charging = false
				$Sprite.modulate = Color(1, 1, 1, 1)
			return
		
		if change_state_time < change_state_count:
			if currentState != "idle":
				change_state("idle")
				majorState = "idle"
			else:
				# Chance to telegraph an attack instead
				if randi() % 4 == 0:
					start_telegraph()
				else:
					change_state("run")
					majorState = "run"
				
			change_state_count = 0
		else:
			change_state_count += d
		
		if !is_on_floor():
			speed.y += 350 * d
		else:
			speed.y = 0
		
		
		
		var movement = move_and_slide(speed * currentVelocity, Vector2(0, -1))
		
		if movement.y != 0:
			change_state("in_air")
		else:
			if movement.x != 0:
				change_state("run")
			else:
				if majorState == "run":
					if !enemies_to_view.empty():
						currentVelocity.x = -currentVelocity.x
				else:
					change_state("idle")
				
				if currentVelocity.x > 0:
					change_facing("right")
				else:
					change_facing("left")

var currentFacing = "right"

func change_facing(dir):
	
	if currentFacing != dir:
		if dir == "right":
			$Sprite.set_scale(Vector2(1, 1))
		elif dir == "left":
			$Sprite.set_scale(Vector2(-1, 1))
		
		currentFacing = dir
	

var currentState = "idle"
func change_state(newState):
	if currentState != newState:
		currentState = newState
		match(newState):
			"run":
				var dir = 1
				if randi()%2 == 0:
					dir = -1
				
				if currentFacing == "right" and dir == -1:
					change_facing("left")
				if currentFacing == "left" and dir == 1:
					change_facing("right")
				
				currentVelocity.x = dir
			"idle":
				currentVelocity.x = 0
			
		
		$Sprite/anim.play(newState)

# ============================================================
# TELEGRAPH / CHARGE ATTACK
# ============================================================
func start_telegraph():
	is_telegraphing = true
	telegraph_timer = 0.0
	# Face the player if visible
	var players = get_tree().get_nodes_in_group("player")
	if !players.empty():
		var player = players[0]
		if player.get_global_position().x < get_global_position().x:
			change_facing("left")
		else:
			change_facing("right")

func start_charge():
	is_charging = true
	change_state("run")
	# Charge for a fixed duration then stop
	yield(get_tree().create_timer(0.6), "timeout")
	is_charging = false

# ============================================================
# DAMAGE / STUN
# ============================================================
func take_damage(amount):
	health -= amount
	if health <= 0:
		die()
	else:
		# Brief red flash
		$Sprite.modulate = Color(1, 0.3, 0.3, 1)
		yield(get_tree().create_timer(0.1), "timeout")
		if is_instance_valid(self) and !is_dying:
			$Sprite.modulate = Color(1, 1, 1, 1)

func get_stunned(duration):
	is_stunned = true
	stun_timer = 0.0
	stun_duration = duration
	is_charging = false
	is_telegraphing = false
	currentVelocity.x = 0

func knockback(dir):
	pass

var is_dying = false

signal explode_coins(pos, amount)
signal dead()


func die():
	is_dying = true
	$hurtBox.queue_free()
	$CollisionShape2D.queue_free()
	$Sprite/anim.play("die")
	$dying_stream.play()
	
	emit_signal("explode_coins", get_global_position(), randi()%2 + 3)
	emit_signal("dead")


func _on_anim_animation_finished(anim_name):
	if anim_name == "die":
		queue_free()


func _on_bounce_checker_body_entered(body):
	if !body.get_groups().has("ground"):
		speed.y = -100

var enemies_to_view = []

func _on_vision_body_entered(body):
	if body.get_groups().has("enemy") or body.get_groups().has("ground"):
		enemies_to_view.append(body)


func _on_vision_body_exited(body):
	if (body.get_groups().has("enemy") or body.get_groups().has("ground")) and enemies_to_view.has(body):
		enemies_to_view.erase(body)
