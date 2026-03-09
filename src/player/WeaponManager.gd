extends Node

# Weapon data: each weapon is a dictionary
var weapons = [
	{
		"name": "Pistol",
		"damage": 1,
		"fire_rate": 0.20,
		"spread": 0.05,
		"burst_count": 1,
		"bullet_speed": 300,
		"bullet_lifetime": 2.2,
		"bullet_scale": Vector2(1, 1),
	},
	{
		"name": "Shotgun",
		"damage": 1,
		"fire_rate": 0.5,
		"spread": 0.3,
		"burst_count": 5,
		"bullet_speed": 250,
		"bullet_lifetime": 0.6,
		"bullet_scale": Vector2(0.7, 0.7),
	},
	{
		"name": "Rapid-Fire",
		"damage": 1,
		"fire_rate": 0.08,
		"spread": 0.1,
		"burst_count": 1,
		"bullet_speed": 350,
		"bullet_lifetime": 1.8,
		"bullet_scale": Vector2(0.6, 0.6),
	},
	{
		"name": "Charged Shot",
		"damage": 3,
		"fire_rate": 1.0,
		"spread": 0.0,
		"burst_count": 1,
		"bullet_speed": 400,
		"bullet_lifetime": 3.0,
		"bullet_scale": Vector2(2.0, 2.0),
	},
]

var current_weapon_index = 0

signal weapon_switched(weapon_data)

func get_current_weapon():
	return weapons[current_weapon_index]

func next_weapon():
	current_weapon_index = (current_weapon_index + 1) % weapons.size()
	emit_signal("weapon_switched", get_current_weapon())
	return get_current_weapon()

func prev_weapon():
	current_weapon_index = (current_weapon_index - 1)
	if current_weapon_index < 0:
		current_weapon_index = weapons.size() - 1
	emit_signal("weapon_switched", get_current_weapon())
	return get_current_weapon()

func get_weapon_name():
	return weapons[current_weapon_index].name

func get_fire_rate():
	return weapons[current_weapon_index].fire_rate

func get_damage():
	return weapons[current_weapon_index].damage

func get_spread():
	return weapons[current_weapon_index].spread

func get_burst_count():
	return weapons[current_weapon_index].burst_count

func get_bullet_speed():
	return weapons[current_weapon_index].bullet_speed

func get_bullet_lifetime():
	return weapons[current_weapon_index].bullet_lifetime

func get_bullet_scale():
	return weapons[current_weapon_index].bullet_scale
