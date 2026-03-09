extends Node2D

var waves = [
	load("res://src/Wave/Wave.tscn"),
	load("res://src/Wave/Wave1.tscn"),
	load("res://src/Wave/Wave2.tscn"),
	load("res://src/Wave/Wave3.tscn"),
	load("res://src/Wave/Wave4.tscn"),
]

# Boss scenes
var boss_brute_scene = preload("res://src/Enemies/BossBrute.tscn")
var boss_caster_scene = preload("res://src/Enemies/BossCaster.tscn")

func _ready():
	randomize()
	spawn_new_wave()

var spawn_timer = 16.0
var spawn_count = 0

var wave_defeated = 0
var is_boss_active = false

func _process(d):
	
	if is_boss_active:
		return  # No regular spawning during boss fight
	
	if spawn_timer < spawn_count:
		if check_enemies() < 15:
			spawn_new_wave()
			spawn_count = 0
		else:
			spawn_count = spawn_count / 2
		
	
	spawn_count += d
	

export (PackedScene) var spanwer_ref
export (PackedScene) var running_enemy_ref
signal new_wave
signal boss_spawned(boss)

func spawn_new_wave():
	
	# Check if this wave should be a boss wave
	if wave_defeated > 0 and wave_defeated % 5 == 0:
		spawn_boss()
		return
	
	if spawn_timer >= 5 and wave_defeated%3 == 0:
		spawn_timer -=1.2
	
	var new_wave = waves[randi()%waves.size()].instance()
	
	add_child(new_wave)
	
	for pos in new_wave.get_children():
		var new_spawner = spanwer_ref.instance()
		
		add_child(new_spawner)
		
		new_spawner.enemy_to_spawn = running_enemy_ref.instance()
		new_spawner.set_position(pos.get_position())
		new_spawner.connect("creature_spawned", self, "add_enemy")
	
	new_wave.queue_free()
	
	wave_defeated += 1
	emit_signal("new_wave", wave_defeated)

func spawn_boss():
	is_boss_active = true
	wave_defeated += 1
	emit_signal("new_wave", wave_defeated)
	
	# Alternate between bosses
	var boss
	if (wave_defeated / 5) % 2 == 1:
		boss = boss_brute_scene.instance()
	else:
		boss = boss_caster_scene.instance()
	
	add_child(boss)
	boss.set_position(Vector2(250, 100))
	
	# Connect boss signals
	boss.connect("boss_defeated", self, "_on_boss_defeated")
	if boss.has_signal("boss_summon_enemy"):
		boss.connect("boss_summon_enemy", self, "_on_boss_summon")
	
	emit_signal("boss_spawned", boss)

func _on_boss_defeated():
	is_boss_active = false
	spawn_count = 0
	# Resume normal waves after a delay
	yield(get_tree().create_timer(2.0), "timeout")
	if is_instance_valid(self):
		spawn_new_wave()

func _on_boss_summon(enemy, pos):
	add_child(enemy)
	enemy.set_position(pos)
	enemy.connect("dead", self, "check_enemies")
	emit_signal("enemy_to_connect", enemy)

signal enemy_to_connect(enemy_ref)

func add_enemy(enemy, pos):
	add_child(enemy)
	enemy.set_position(pos)
	
	enemy.connect("dead", self, "check_enemies")
	emit_signal("enemy_to_connect", enemy)

func check_enemies():
	
	var enemy_left = []
	
	for child in get_children():
		if child is Enemy and !child.is_dying:
			enemy_left.append(child)
	
	if enemy_left.empty() and !is_boss_active:
		spawn_new_wave()
		spawn_count = 0
	
	return enemy_left.size()
