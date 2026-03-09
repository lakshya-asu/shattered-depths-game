extends Control
# ============================================================
# PROCEDURAL LEVEL — Main gameplay scene with room progression
# ============================================================
# Flow: Start → 4 Combat → Boss → 4 Combat → Boss → ...
# Each room is a single-screen arena. Clear enemies → exit opens.

var RoomGenerator = preload("res://src/Levels/RoomGenerator.gd")
var room_gen = null

var boss_brute_scene = preload("res://src/Enemies/BossBrute.tscn")
var boss_caster_scene = preload("res://src/Enemies/BossCaster.tscn")
var boss_hud_scene = preload("res://src/Menus/BossHUD.tscn")
var player_hud_scene = preload("res://src/Menus/PlayerHUD.tscn")
var running_enemy_scene = preload("res://src/Enemies/RunningEnemy.tscn")
var spawner_scene = preload("res://src/Wave/Spawner.tscn")

export (PackedScene) var smallCoin_ref
export (PackedScene) var bigCoin_ref

# --- State ---
var current_room = 0
var rooms_since_boss = 0
var boss_every_n_rooms = 5
var is_boss_active = false
var room_cleared = false
var enemies_alive = 0
var points = 0
var total_rooms_cleared = 0
var kill_streak = 0

# HUDs
var boss_hud = null
var player_hud = null
var current_boss = null

# Exit portal
var exit_portal = null

func _ready():
	randomize()
	room_gen = RoomGenerator.new()
	add_child(room_gen)
	
	# Connect player signals
	$entities/MapPlayer.connect("shoot_fired", self, "create_bullet")
	$entities/MapPlayer.connect("game_over", self, "game_over")
	$entities/MapPlayer.connect("missile_fired", self, "connect_missile")
	$entities/MapPlayer.connect("weapon_changed", self, "update_weapon_display")
	$entities/MapPlayer.connect("health_down", self, "update_health_display")
	
	# Create PlayerHUD (replaces old UI labels)
	player_hud = player_hud_scene.instance()
	$UI.add_child(player_hud)
	
	# Create boss HUD (hidden)
	boss_hud = boss_hud_scene.instance()
	$UI.add_child(boss_hud)
	
	# Hide the old label nodes (PlayerHUD replaces them)
	for old_label in ["Points", "Waves", "Health", "Weapon", "Missiles"]:
		if $UI.has_node(old_label):
			$UI.get_node(old_label).visible = false
	
	# Generate first room
	generate_room()

func _process(d):
	# Update dash cooldown bar in real-time
	if player_hud and has_node("entities/MapPlayer"):
		var player = $entities/MapPlayer
		player_hud.update_dash_cooldown(player.dash_cooldown_timer, player.dash_cooldown)

# ============================================================
# ROOM GENERATION
# ============================================================
func generate_room():
	current_room += 1
	rooms_since_boss += 1
	room_cleared = false
	
	clear_room()
	
	var room_type = room_gen.RoomType.COMBAT
	
	if current_room == 1:
		room_type = room_gen.RoomType.START
	elif rooms_since_boss >= boss_every_n_rooms:
		room_type = room_gen.RoomType.BOSS
		rooms_since_boss = 0
	elif current_room > 1 and current_room % 8 == 0:
		room_type = room_gen.RoomType.REST
	
	var data = room_gen.generate_room_data(current_room, room_type)
	room_gen.create_platforms(self, data.platforms)
	
	# Update HUD
	if player_hud:
		player_hud.update_room("Room " + str(current_room))
	
	match room_type:
		room_gen.RoomType.COMBAT:
			spawn_enemies(data)
		room_gen.RoomType.BOSS:
			spawn_boss()
		room_gen.RoomType.START:
			yield(get_tree().create_timer(1.0), "timeout")
			if is_instance_valid(self):
				show_exit_portal()
		room_gen.RoomType.REST:
			if has_node("entities/MapPlayer"):
				var player = $entities/MapPlayer
				player.health = min(player.health + 1, 4)
				update_health_display()
				# Flash green to indicate heal
				if has_node("/root/effects"):
					get_node("/root/effects").flash_screen(Color(0.2, 1, 0.3, 0.3), 0.5)
			show_exit_portal()

func clear_room():
	for child in get_children():
		if child.name == "platforms":
			child.queue_free()
		if child is ColorRect and child.get_parent() == self:
			child.queue_free()
	
	if exit_portal != null and is_instance_valid(exit_portal):
		exit_portal.queue_free()
		exit_portal = null
	
	for child in $entities.get_children():
		if child.name != "MapPlayer" and child is KinematicBody2D:
			child.queue_free()
	
	for child in $bullets.get_children():
		child.queue_free()
	for child in $coins.get_children():
		child.queue_free()

# ============================================================
# ENEMY SPAWNING
# ============================================================
func spawn_enemies(room_data):
	enemies_alive = 0
	kill_streak = 0
	
	for i in range(room_data.enemy_count):
		var spawn_pos = room_data.spawn_points[i % room_data.spawn_points.size()]
		spawn_pos += Vector2(randi() % 20 - 10, 0)
		
		var spawner = spawner_scene.instance()
		$entities.add_child(spawner)
		spawner.enemy_to_spawn = running_enemy_scene.instance()
		spawner.set_position(spawn_pos)
		spawner.connect("creature_spawned", self, "add_enemy")

func add_enemy(enemy, pos):
	$entities.add_child(enemy)
	enemy.set_position(pos)
	enemy.connect("dead", self, "_on_enemy_died")
	enemy.connect("explode_coins", self, "create_many_coins")
	enemies_alive += 1
	
	if current_room > 5:
		enemy.health += current_room / 5

func _on_enemy_died():
	enemies_alive -= 1
	kill_streak += 1
	
	# Combo tracking
	if player_hud:
		player_hud.add_combo()
	
	# Bonus points for streaks
	var streak_bonus = kill_streak - 1
	if streak_bonus > 0:
		points += streak_bonus
		if player_hud:
			player_hud.update_points(points)
	
	if enemies_alive <= 0 and !is_boss_active:
		room_cleared = true
		total_rooms_cleared += 1
		yield(get_tree().create_timer(0.8), "timeout")
		if is_instance_valid(self) and room_cleared:
			show_exit_portal()

# ============================================================
# EXIT PORTAL
# ============================================================
func show_exit_portal():
	if exit_portal != null and is_instance_valid(exit_portal):
		return
	
	exit_portal = Area2D.new()
	exit_portal.name = "ExitPortal"
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.extents = Vector2(6, 20)
	shape.shape = rect
	exit_portal.add_child(shape)
	
	var visual = ColorRect.new()
	visual.rect_position = Vector2(-6, -20)
	visual.rect_size = Vector2(12, 40)
	visual.color = Color(0.2, 1.0, 0.3, 0.8)
	exit_portal.add_child(visual)
	
	var label = Label.new()
	label.text = "EXIT"
	label.rect_position = Vector2(-12, -30)
	label.add_color_override("font_color", Color(0.2, 1.0, 0.3, 1))
	exit_portal.add_child(label)
	
	exit_portal.set_position(Vector2(305, 155))
	add_child(exit_portal)
	
	exit_portal.connect("body_entered", self, "_on_exit_entered")
	_pulse_portal()

func _pulse_portal():
	if exit_portal == null or !is_instance_valid(exit_portal):
		return
	while is_instance_valid(exit_portal):
		for child in exit_portal.get_children():
			if child is ColorRect:
				child.color.a = 0.5
		yield(get_tree().create_timer(0.4), "timeout")
		if !is_instance_valid(exit_portal):
			break
		for child in exit_portal.get_children():
			if child is ColorRect:
				child.color.a = 0.9
		yield(get_tree().create_timer(0.4), "timeout")

func _on_exit_entered(body):
	if body.get_groups().has("player"):
		transition_to_next_room()

func transition_to_next_room():
	if has_node("entities/MapPlayer"):
		$entities/MapPlayer.setMovable(false)
	
	var flash = ColorRect.new()
	flash.name = "transition_flash"
	flash.rect_position = Vector2(0, 0)
	flash.rect_size = Vector2(320, 180)
	flash.color = Color(0, 0, 0, 0)
	$UI.add_child(flash)
	
	for i in range(10):
		flash.color.a += 0.1
		yield(get_tree().create_timer(0.03), "timeout")
	
	if has_node("entities/MapPlayer"):
		$entities/MapPlayer.set_position(Vector2(30, 155))
		$entities/MapPlayer.setMovable(true)
	
	generate_room()
	
	for i in range(10):
		if is_instance_valid(flash):
			flash.color.a -= 0.1
		yield(get_tree().create_timer(0.03), "timeout")
	
	if is_instance_valid(flash):
		flash.queue_free()

# ============================================================
# BOSS SPAWNING
# ============================================================
func spawn_boss():
	is_boss_active = true
	
	var boss
	if (current_room / boss_every_n_rooms) % 2 == 1:
		boss = boss_brute_scene.instance()
	else:
		boss = boss_caster_scene.instance()
	
	$entities.add_child(boss)
	boss.set_position(Vector2(250, 100))
	current_boss = boss
	
	boss.connect("boss_health_changed", self, "_on_boss_health_changed")
	boss.connect("boss_phase_changed", self, "_on_boss_phase_changed")
	boss.connect("boss_defeated", self, "_on_boss_defeated")
	boss.connect("boss_dialogue_started", self, "_on_boss_dialogue_started")
	boss.connect("boss_dialogue_ended", self, "_on_boss_dialogue_ended")
	if boss.has_signal("boss_summon_enemy"):
		boss.connect("boss_summon_enemy", self, "_on_boss_summon")
	
	if boss_hud:
		boss_hud.show_boss(boss.boss_name, boss.health, boss.max_health)

func _on_boss_health_changed(hp, max_hp):
	if boss_hud:
		boss_hud.update_health(hp, max_hp)

func _on_boss_phase_changed(phase):
	# Big hit effect on phase change
	if has_node("/root/effects"):
		get_node("/root/effects").big_hit_effect()

func _on_boss_defeated():
	is_boss_active = false
	if boss_hud:
		boss_hud.hide_boss()
	current_boss = null
	
	# Boss death effect
	if has_node("/root/effects"):
		get_node("/root/effects").boss_death_effect()
	
	points += 100
	if player_hud:
		player_hud.update_points(points)
	total_rooms_cleared += 1
	
	yield(get_tree().create_timer(2.0), "timeout")
	if is_instance_valid(self):
		show_exit_portal()

func _on_boss_dialogue_started():
	if has_node("entities/MapPlayer"):
		$entities/MapPlayer.setMovable(false)

func _on_boss_dialogue_ended():
	if has_node("entities/MapPlayer"):
		$entities/MapPlayer.setMovable(true)

func _on_boss_summon(enemy, pos):
	$entities.add_child(enemy)
	enemy.set_position(pos)
	enemy.connect("dead", self, "_on_enemy_died")
	enemy.connect("explode_coins", self, "create_many_coins")
	enemies_alive += 1

# ============================================================
# BULLETS / COINS / MISSILES
# ============================================================
func create_bullet(bullet_instance, start_pos, dir):
	$bullets.add_child(bullet_instance)
	bullet_instance.set_bullet(start_pos, dir)
	bullet_instance.connect("enemy_hurt", self, "damage_enemy")

func damage_enemy(bullet, enemy):
	if enemy.has_method("take_damage"):
		enemy.take_damage(bullet.damage)
	else:
		enemy.health -= bullet.damage
		if enemy.health <= 0:
			enemy.die()
		else:
			enemy.knockback(bullet.dir)

func connect_missile(missile):
	missile.connect("missile_hit", self, "missile_damage_enemy")
	if player_hud:
		player_hud.update_missiles($entities/MapPlayer.missile_count)

func missile_damage_enemy(enemy, damage):
	if is_instance_valid(enemy) and !enemy.is_dying:
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		else:
			enemy.health -= damage
			if enemy.health <= 0:
				enemy.die()

func create_many_coins(pos, amount):
	for i in range(amount):
		var coin = bigCoin_ref.instance()
		if !randi()%5 != 0:
			coin = smallCoin_ref.instance()
		create_coin(coin, pos)

func create_coin(coin, start_pos):
	$coins.add_child(coin)
	coin.set_position(start_pos)
	coin.connect("collected", self, "get_coin_points")

func get_coin_points(coin):
	points += coin.points
	$entities/MapPlayer.play_pick_up_sound()
	if player_hud:
		player_hud.update_points(points)

# ============================================================
# HUD UPDATES
# ============================================================
func update_weapon_display(weapon_name):
	if player_hud:
		player_hud.update_weapon(weapon_name)

func update_health_display():
	if player_hud and has_node("entities/MapPlayer"):
		player_hud.update_health($entities/MapPlayer.health, 4)
		player_hud.update_missiles($entities/MapPlayer.missile_count)

# ============================================================
# GAME OVER
# ============================================================
func game_over():
	if score.best_score.points < points:
		score.best_score = {"points" : points, "waves" : total_rooms_cleared}
	score.player_data.rooms_cleared = total_rooms_cleared
	get_tree().change_scene("res://src/Menus/GameOver.tscn")

func _on_music_stream_finished():
	$music_stream.play()
