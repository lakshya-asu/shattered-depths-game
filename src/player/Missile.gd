extends Area2D

var speed = 150.0
var turn_rate = 3.0  # radians per second
var target = null
var lifetime = 3.0
var life_timer = 0.0
var damage = 3
var aoe_radius = 20.0
var velocity = Vector2.ZERO
var initial_dir = Vector2(1, 0)

signal missile_hit(pos, damage, aoe_radius)
signal missile_exploded(pos, aoe_radius)

func _ready():
	set_as_toplevel(true)
	find_target()

func setup(start_pos, dir):
	set_global_position(start_pos)
	initial_dir = dir
	velocity = dir * speed
	set_rotation(dir.angle())

func find_target():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest = null
	var closest_dist = 9999.0
	for enemy in enemies:
		if enemy.has_method("die") and !enemy.is_dying:
			var dist = get_global_position().distance_to(enemy.get_global_position())
			if dist < closest_dist:
				closest_dist = dist
				closest = enemy
	target = closest

func _physics_process(d):
	life_timer += d
	if life_timer >= lifetime:
		explode()
		return
	
	# Re-acquire target periodically
	if target == null or !is_instance_valid(target):
		find_target()
	
	# Homing behavior
	if target != null and is_instance_valid(target):
		var desired_dir = (target.get_global_position() - get_global_position()).normalized()
		var current_angle = velocity.angle()
		var desired_angle = desired_dir.angle()
		var angle_diff = wrapf(desired_angle - current_angle, -PI, PI)
		var max_turn = turn_rate * d
		var actual_turn = clamp(angle_diff, -max_turn, max_turn)
		var new_angle = current_angle + actual_turn
		velocity = Vector2(cos(new_angle), sin(new_angle)) * speed
	
	set_global_position(get_global_position() + velocity * d)
	set_rotation(velocity.angle())

func explode():
	emit_signal("missile_exploded", get_global_position(), aoe_radius)
	# Deal AOE damage to all enemies in range
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if is_instance_valid(enemy) and !enemy.is_dying:
			var dist = get_global_position().distance_to(enemy.get_global_position())
			if dist <= aoe_radius:
				emit_signal("missile_hit", enemy, damage)
	queue_free()

func _on_body_entered(body):
	if body.get_groups().has("enemy"):
		explode()
	elif body.get_groups().has("ground"):
		explode()
