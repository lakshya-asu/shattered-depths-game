extends Area2D

var damage = 1
var direction = 1  # 1 = right, -1 = left
var lifetime = 0.15
var life_timer = 0.0
var is_parry = false

signal melee_hit(enemy, damage)
signal parry_success(enemy)

func _ready():
	set_as_toplevel(true)
	$CollisionShape2D.disabled = false

func _physics_process(d):
	life_timer += d
	if life_timer >= lifetime:
		queue_free()

func setup(pos, dir, dmg, parry):
	set_global_position(pos + Vector2(dir * 14, 0))
	damage = dmg
	direction = dir
	is_parry = parry

func _on_body_entered(body):
	if body.get_groups().has("enemy"):
		if is_parry and body.has_method("get_stunned"):
			emit_signal("parry_success", body)
		else:
			emit_signal("melee_hit", body, damage)
