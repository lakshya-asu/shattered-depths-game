extends Area2D
# ============================================================
# BOSS PROJECTILE — Used by ranged bosses
# ============================================================

var dir = Vector2(1, 0)
var speed = 200
var damage = 1
var lifetime = 3.0
var lifecount = 0.0
var is_homing = false
var homing_strength = 2.0
var can_be_parried = true

func _ready():
	set_as_toplevel(true)

func setup(start_pos, direction, spd):
	set_global_position(start_pos)
	dir = direction.normalized()
	speed = spd
	set_rotation(dir.angle())

func _physics_process(d):
	lifecount += d
	if lifecount > lifetime:
		queue_free()
		return
	
	# Homing behavior
	if is_homing:
		var players = get_tree().get_nodes_in_group("player")
		if !players.empty():
			var player = players[0]
			var desired = (player.get_global_position() - get_global_position()).normalized()
			var current_angle = dir.angle()
			var desired_angle = desired.angle()
			var diff = wrapf(desired_angle - current_angle, -PI, PI)
			var turn = clamp(diff, -homing_strength * d, homing_strength * d)
			var new_angle = current_angle + turn
			dir = Vector2(cos(new_angle), sin(new_angle))
			set_rotation(dir.angle())
	
	set_global_position(get_global_position() + d * dir * speed)

func _on_body_entered(body):
	if body.get_groups().has("player"):
		if body.has_method("get_hurt_amount"):
			body.get_hurt_amount(damage)
		queue_free()
	elif body.get_groups().has("ground"):
		queue_free()

# Called when player parries this projectile — reverse direction
func get_parried():
	dir = -dir
	set_rotation(dir.angle())
	# Now it damages enemies instead
	can_be_parried = false
	# Remove "harms player" and seek enemies instead
	is_homing = false
	
	# Check if it hits any bosses
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if is_instance_valid(enemy):
			# Will hit on next collision
			pass
