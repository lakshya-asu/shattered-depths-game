extends Control
# ============================================================
# PLAYER HUD — Rich overlay with health pips, dash bar,
# weapon display, missile count, combo counter, room info
# ============================================================

var max_health = 4

# Combo display
var combo_count = 0
var combo_timer = 0.0
var combo_window = 2.0  # seconds before combo resets

func _ready():
	update_all()

func _process(d):
	# Combo timer
	if combo_count > 0:
		combo_timer += d
		if combo_timer >= combo_window:
			combo_count = 0
			combo_timer = 0.0
			update_combo_display()

# ============================================================
# HEALTH PIPS (hearts)
# ============================================================
func update_health(current_hp, max_hp):
	max_health = max_hp
	if has_node("HealthPips"):
		# Remove old pips
		for child in $HealthPips.get_children():
			child.queue_free()
		
		# Create new pips
		for i in range(max_hp):
			var pip = ColorRect.new()
			pip.rect_size = Vector2(8, 8)
			pip.rect_position = Vector2(i * 11, 0)
			
			if i < current_hp:
				pip.color = Color(0.9, 0.15, 0.15, 1)  # Red = filled
			else:
				pip.color = Color(0.3, 0.1, 0.1, 0.6)  # Dark = empty
			
			$HealthPips.add_child(pip)

# ============================================================
# DASH COOLDOWN BAR
# ============================================================
func update_dash_cooldown(current, max_cd):
	if has_node("DashBar/Fill"):
		var percent = clamp(current / max_cd, 0.0, 1.0)
		$DashBar/Fill.rect_size.x = 30 * percent
		
		if percent >= 1.0:
			$DashBar/Fill.color = Color(0.2, 0.8, 1.0, 0.9)  # Cyan = ready
		else:
			$DashBar/Fill.color = Color(0.4, 0.4, 0.5, 0.7)  # Grey = charging

# ============================================================
# WEAPON DISPLAY
# ============================================================
func update_weapon(weapon_name):
	if has_node("WeaponLabel"):
		$WeaponLabel.text = weapon_name

# ============================================================
# MISSILES
# ============================================================
func update_missiles(count):
	if has_node("MissileLabel"):
		$MissileLabel.text = "M:" + str(count)

# ============================================================
# POINTS
# ============================================================
func update_points(pts):
	if has_node("PointsLabel"):
		$PointsLabel.text = str(pts)

# ============================================================
# ROOM / WAVE
# ============================================================
func update_room(room_text):
	if has_node("RoomLabel"):
		$RoomLabel.text = room_text

# ============================================================
# COMBO COUNTER
# ============================================================
func add_combo():
	combo_count += 1
	combo_timer = 0.0
	update_combo_display()

func update_combo_display():
	if has_node("ComboLabel"):
		if combo_count > 1:
			$ComboLabel.text = str(combo_count) + "x COMBO!"
			$ComboLabel.visible = true
			# Scale effect
			$ComboLabel.rect_scale = Vector2(1.3, 1.3)
			yield(get_tree().create_timer(0.1), "timeout")
			if is_instance_valid(self) and has_node("ComboLabel"):
				$ComboLabel.rect_scale = Vector2(1.0, 1.0)
		else:
			$ComboLabel.visible = false

# ============================================================
# UPDATE ALL
# ============================================================
func update_all():
	update_health(4, 4)
	update_dash_cooldown(1.0, 1.0)
	update_weapon("Pistol")
	update_missiles(3)
	update_points(0)
	update_room("Room 1")
