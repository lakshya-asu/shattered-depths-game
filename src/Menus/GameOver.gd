extends Control

func _ready():
	$points/value.set_text(str(score.best_score.points))
	$Waves/value.set_text(str(score.player_data.rooms_cleared))

func _on_PlayAgain_pressed():
	score.reset_run()
	get_tree().change_scene("res://src/Levels/ProceduralLevel.tscn")


func _on_music_stream_finished():
	$music_stream.play()
