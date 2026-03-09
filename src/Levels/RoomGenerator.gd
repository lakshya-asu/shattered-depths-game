extends Node
# ============================================================
# ROOM GENERATOR — Procedural platform and spawn layouts
# ============================================================
# Generates collision shapes for platforms and spawn positions
# for enemies within a 320x180 arena

# Room types
enum RoomType { COMBAT, BOSS, START, REST }

# Platform presets — arrays of Rect2(x, y, width, height)
var platform_presets = [
	# Preset 0: Original layout (two low platforms, one mid, two upper)
	[
		Rect2(30, 124, 40, 8),
		Rect2(248, 126, 40, 8),
		Rect2(130, 90, 60, 8),
		Rect2(44, 60, 60, 8),
		Rect2(220, 60, 60, 8),
	],
	# Preset 1: Staircase left to right
	[
		Rect2(20, 140, 50, 8),
		Rect2(90, 120, 50, 8),
		Rect2(160, 100, 50, 8),
		Rect2(230, 80, 50, 8),
		Rect2(130, 55, 60, 8),
	],
	# Preset 2: U-shape (platforms on sides, gap in middle)
	[
		Rect2(20, 100, 70, 8),
		Rect2(230, 100, 70, 8),
		Rect2(20, 60, 50, 8),
		Rect2(250, 60, 50, 8),
		Rect2(120, 130, 80, 8),
	],
	# Preset 3: Central tower with surrounding platforms
	[
		Rect2(130, 70, 60, 8),
		Rect2(130, 120, 60, 8),
		Rect2(30, 90, 50, 8),
		Rect2(240, 90, 50, 8),
		Rect2(80, 140, 40, 8),
		Rect2(200, 140, 40, 8),
	],
	# Preset 4: Zigzag
	[
		Rect2(30, 140, 60, 8),
		Rect2(120, 110, 60, 8),
		Rect2(230, 140, 60, 8),
		Rect2(60, 75, 60, 8),
		Rect2(200, 75, 60, 8),
		Rect2(130, 45, 50, 8),
	],
	# Preset 5: Scattered small platforms
	[
		Rect2(40, 130, 35, 8),
		Rect2(110, 110, 35, 8),
		Rect2(180, 130, 35, 8),
		Rect2(250, 110, 35, 8),
		Rect2(70, 80, 35, 8),
		Rect2(150, 65, 35, 8),
		Rect2(220, 80, 35, 8),
	],
	# Preset 6: Wide platforms (boss-friendly)
	[
		Rect2(50, 120, 80, 8),
		Rect2(190, 120, 80, 8),
		Rect2(110, 80, 100, 8),
		Rect2(40, 50, 50, 8),
		Rect2(230, 50, 50, 8),
	],
	# Preset 7: Narrow gauntlet
	[
		Rect2(30, 140, 25, 8),
		Rect2(80, 120, 25, 8),
		Rect2(130, 100, 25, 8),
		Rect2(180, 80, 25, 8),
		Rect2(230, 60, 25, 8),
		Rect2(280, 130, 25, 8),
		Rect2(130, 50, 30, 8),
	],
]

# Spawn position presets (enemy spawn points)
var spawn_presets = [
	[Vector2(50, 100), Vector2(270, 100)],
	[Vector2(40, 80), Vector2(160, 60), Vector2(280, 80)],
	[Vector2(30, 50), Vector2(160, 80), Vector2(290, 50)],
	[Vector2(60, 120), Vector2(140, 80), Vector2(260, 120)],
	[Vector2(50, 60), Vector2(160, 100), Vector2(270, 60), Vector2(160, 40)],
]

# ============================================================
# GENERATION
# ============================================================
func generate_room_data(room_number, room_type = RoomType.COMBAT):
	randomize()
	var data = {
		"platforms": [],
		"spawn_points": [],
		"enemy_count": 0,
		"room_type": room_type,
	}
	
	match room_type:
		RoomType.COMBAT:
			# Pick random platform preset
			var preset_idx = randi() % platform_presets.size()
			data.platforms = platform_presets[preset_idx]
			
			# Add slight random variation to platform positions
			var varied_platforms = []
			for plat in data.platforms:
				var varied = Rect2(
					plat.position.x + randi() % 10 - 5,
					plat.position.y + randi() % 6 - 3,
					plat.size.x,
					plat.size.y
				)
				# Clamp within arena bounds
				varied.position.x = clamp(varied.position.x, 10, 280)
				varied.position.y = clamp(varied.position.y, 30, 155)
				varied_platforms.append(varied)
			data.platforms = varied_platforms
			
			# Pick spawn points
			var spawn_idx = randi() % spawn_presets.size()
			data.spawn_points = spawn_presets[spawn_idx]
			
			# Scale enemy count with room depth
			data.enemy_count = min(3 + room_number / 2, 8)
			
		RoomType.BOSS:
			# Boss room: wide open arena
			data.platforms = platform_presets[6]  # Wide platforms
			data.spawn_points = [Vector2(250, 100)]
			data.enemy_count = 0  # Boss handles its own spawn
			
		RoomType.START:
			# Start room: simple safe area
			data.platforms = platform_presets[0]
			data.spawn_points = []
			data.enemy_count = 0
			
		RoomType.REST:
			# Rest room: safe with potential healing
			data.platforms = [
				Rect2(60, 120, 80, 8),
				Rect2(180, 120, 80, 8),
				Rect2(110, 80, 100, 8),
			]
			data.spawn_points = []
			data.enemy_count = 0
	
	return data

func create_platforms(parent, platform_data):
	# Create a StaticBody2D with CollisionShapes for each platform
	var body = StaticBody2D.new()
	body.add_to_group("ground")
	body.name = "platforms"
	
	for plat in platform_data:
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.extents = Vector2(plat.size.x / 2, plat.size.y / 2)
		shape.shape = rect
		shape.position = Vector2(plat.position.x + plat.size.x / 2, plat.position.y + plat.size.y / 2)
		body.add_child(shape)
		
		# Visual indicator for platforms (simple colored rect)
		var visual = ColorRect.new()
		visual.rect_position = plat.position
		visual.rect_size = plat.size
		visual.color = Color(0.35, 0.3, 0.25, 1)
		parent.add_child(visual)
	
	parent.add_child(body)
	return body
