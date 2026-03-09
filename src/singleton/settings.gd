extends Node

var best_score = {
	"points" : 0,
	"waves" : 0
}

# Track player state across scenes / rooms
var player_data = {
	"current_weapon" : 0,
	"missiles" : 3,
	"health" : 4,
	"coins" : 0,
	"rooms_cleared" : 0,
	"enemies_killed" : 0,
	"bosses_defeated" : 0,
	"best_combo" : 0,
	"total_points" : 0,
}

func reset_run():
	player_data = {
		"current_weapon" : 0,
		"missiles" : 3,
		"health" : 4,
		"coins" : 0,
		"rooms_cleared" : 0,
		"enemies_killed" : 0,
		"bosses_defeated" : 0,
		"best_combo" : 0,
		"total_points" : 0,
	}

func save_player_state(player):
	if player:
		player_data.health = player.health
		player_data.missiles = player.missile_count
		player_data.current_weapon = player.weapon_manager.current_weapon_index

func load_player_state(player):
	if player:
		player.health = player_data.health
		player.missile_count = player_data.missiles
		player.weapon_manager.current_weapon_index = player_data.current_weapon
