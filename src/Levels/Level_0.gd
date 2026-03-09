extends Control

var boss_hud_scene = preload("res://src/Menus/BossHUD.tscn")
var boss_hud = null

func _ready():
	randomize()
	
	$entities.connect("enemy_to_connect", self, "connect_enemy_to_money")
	$entities.connect("new_wave", self, "update_waves")
	$entities.connect("boss_spawned", self, "_on_boss_spawned")
	
	$entities/MapPlayer.connect("shoot_fired", self, "create_bullet")
	$entities/MapPlayer.connect("game_over", self, "game_over")
	$entities/MapPlayer.connect("missile_fired", self, "connect_missile")
	$entities/MapPlayer.connect("weapon_changed", self, "update_weapon_display")
	$entities/MapPlayer.connect("health_down", self, "update_health_display")
	
	# Create BossHUD (hidden by default)
	boss_hud = boss_hud_scene.instance()
	$UI.add_child(boss_hud)

func connect_enemy_to_money(enemy):
	enemy.connect("explode_coins", self, "create_many_coins")

export (PackedScene) var smallCoin_ref
export (PackedScene) var bigCoin_ref

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
	

var points = 0

var sound_stack = []

func get_coin_points(coin):
	
	points += coin.points
	$entities/MapPlayer.play_pick_up_sound()
	$UI/Points/value.set_text(str(points))

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
	update_missile_display()

func missile_damage_enemy(enemy, damage):
	if is_instance_valid(enemy) and !enemy.is_dying:
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		else:
			enemy.health -= damage
			if enemy.health <= 0:
				enemy.die()

func update_weapon_display(weapon_name):
	if has_node("UI/Weapon"):
		$UI/Weapon/value.set_text(weapon_name)

func update_missile_display():
	if has_node("UI/Missiles"):
		$UI/Missiles/value.set_text(str($entities/MapPlayer.missile_count))

func update_health_display():
	if has_node("UI/Health"):
		$UI/Health/value.set_text(str($entities/MapPlayer.health))
	update_missile_display()

# ============================================================
# BOSS INTEGRATION
# ============================================================
var current_boss = null

func _on_boss_spawned(boss):
	current_boss = boss
	
	# Connect boss signals
	boss.connect("boss_health_changed", self, "_on_boss_health_changed")
	boss.connect("boss_phase_changed", self, "_on_boss_phase_changed")
	boss.connect("boss_defeated", self, "_on_boss_defeated")
	boss.connect("boss_dialogue_started", self, "_on_boss_dialogue_started")
	boss.connect("boss_dialogue_ended", self, "_on_boss_dialogue_ended")
	
	# Connect money from boss-summoned enemies
	if boss.has_signal("boss_summon_enemy"):
		# Already handled in entities.gd
		pass
	
	# Show boss HUD
	if boss_hud:
		boss_hud.show_boss(boss.boss_name, boss.health, boss.max_health)

func _on_boss_health_changed(hp, max_hp):
	if boss_hud:
		boss_hud.update_health(hp, max_hp)

func _on_boss_phase_changed(phase):
	pass  # HUD already updates from health changes

func _on_boss_defeated():
	if boss_hud:
		boss_hud.hide_boss()
	current_boss = null
	
	# Bonus points for boss kill
	points += 50
	$UI/Points/value.set_text(str(points))

func _on_boss_dialogue_started():
	# Pause player during dialogue
	if has_node("entities/MapPlayer"):
		$entities/MapPlayer.setMovable(false)

func _on_boss_dialogue_ended():
	# Resume player after dialogue
	if has_node("entities/MapPlayer"):
		$entities/MapPlayer.setMovable(true)

func retry():
	get_tree().change_scene("res://src/Levels/Level_0.tscn")

func update_waves(wave):
	$UI/Waves/value.set_text(str(wave))

func game_over():
	
	if score.best_score.points < points:
		score.best_score = {"points" : points, "waves" : $entities.wave_defeated}
	
	get_tree().change_scene("res://src/Menus/GameOver.tscn")
	

func _on_music_stream_finished():
	$music_stream.play()
