extends Node3D

enum Phase { TITLE, WAKE, GIFT, PLAY }
enum PathId { NONE, STEEL, SONG, SPARK, FEATHER }

const SPEED := 8.8
const JUMP_V := 7.4
const GRAVITY := 18.0
const DITCH := Vector3(0.0, 0.0, 28.8)

var phase: Phase = Phase.TITLE
var path: PathId = PathId.NONE
var invited := false
var hp := 100
var coin := 0
var spark := 3
var wake_t := 0.0
var yaw := 0.0
var pitch := 0.18
var swinging := 0.0
var spell_cd := 0.0
var fairy_t := 0.0
var fairy_gone := false
var fairy_talk: String = "Up, ditch-rat. Aldric took her in a cart. I took offense. Different crimes."
var prompt := ""
var log_line := "The cinematic is a blank page. Then mud."
var look_sens := 0.0022
var hob_node := ""
var dog_node := ""

var player: CharacterBody3D
var head: Node3D
var camera: Camera3D
var fairy: Node3D
var gifts: Array = []
var npcs: Array = []
var sword_view: Node3D
var lute_view: Node3D
var book_view: Node3D
var overlay: Control
var talk_label: Label
var prompt_label: Label
var stats_label: Label
var title_box: Control
var wake_btn: Button
var nix_tex: Texture2D
var mud_tex: Texture2D
var stone_tex: Texture2D
var pine_scene: PackedScene
var haunted_trees: Array[PackedScene] = []
var haunted_bushes: Array[PackedScene] = []
var grass_mats: Array[StandardMaterial3D] = []
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var is_day := false
var bg_mesh: MeshInstance3D
var menu_open := false
var menu_page := "root"
var menu_box: Control
var menu_col: VBoxContainer
var fires: Array = []

func _ready() -> void:
	DisplayServer.window_set_title("RJ-READY")
	nix_tex = load("res://assets/nix.png")
	mud_tex = load("res://assets/mud.png")
	stone_tex = load("res://assets/stone.png")
	pine_scene = load("res://assets/psx-nature/pine_tree.glb")
	for n in ["tree1", "tree2", "tree3", "tree4", "tree5"]:
		haunted_trees.append(load("res://assets/psx-nature/haunted/%s.glb" % n))
	for n in ["bush1", "bush2", "bush3", "bush5", "bush6"]:
		haunted_bushes.append(load("res://assets/psx-nature/haunted/%s.glb" % n))
	for i in range(1, 7):
		grass_mats.append(_psx_alpha("res://assets/psx-nature/grass_%d.png" % i))
	_build_world()
	_build_player()
	_build_ditch()
	_build_hud()
	_set_phase_title()
	camera.current = true

func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	add_child(sun)
	_apply_time()
	_build_clouds()
	_build_backdrop()

	_box(Vector3(160, 1, 160), Vector3(0, -0.5, 0), Color(0.72, 0.66, 0.52), mud_tex, true, 24.0)
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(200, 2, 200)
	floor_col.shape = floor_shape
	floor_body.position.y = -1
	floor_body.add_child(floor_col)
	add_child(floor_body)
	_cobble_path()
	_house(Vector3(-9.2, 0, 21.5), Vector3(7.2, 4.1, 6.2), "MUD HOUSE", false, "e", "cottage")
	_house(Vector3(-9.2, 0, 14.2), Vector3(7.2, 4.4, 6.4), "NO BEDS", false, "e", "hostel")
	_house(Vector3(-9.4, 0, 6.4), Vector3(7.8, 5.0, 7.2), "IRON & ASH", true, "e", "smith")
	_house(Vector3(-9.6, 0, -2.2), Vector3(8.2, 6.4, 7.6), "ST. DRIP", true, "e", "chapel")
	_house(Vector3(-9.0, 0, -11.6), Vector3(6.8, 4.0, 5.6), "LEAN-TO", false, "e", "cottage")
	_house(Vector3(9.2, 0, 21.5), Vector3(7.2, 4.0, 6.2), "COOPER", false, "w", "shop")
	_house(Vector3(9.2, 0, 14.2), Vector3(7.2, 4.2, 6.4), "HIDE WORKS", false, "w", "shop")
	_house(Vector3(9.6, 0, 6.2), Vector3(8.4, 6.2, 8.4), "THE GENEROUS CUP", false, "w", "inn")
	_house(Vector3(9.4, 0, -3.4), Vector3(8.0, 4.3, 7.4), "THE KING'S NAGS", false, "w", "stables")
	_house(Vector3(8.8, 0, -12.0), Vector3(6.6, 3.9, 5.4), "TALLOW", false, "w", "shop")
	_box(Vector3(2.6, 2.4, 2.2), Vector3(-3.6, 1.2, 4.2), Color(0.29, 0.23, 0.17), null, true, 2.0)
	_sign(Vector3(-2.3, 2.35, 4.2), "ROAD TAX")
	_lantern(Vector3(-2.25, 1.85, 4.2))
	_lantern(Vector3(-2.35, 2.55, 22.2))
	_lantern(Vector3(2.35, 2.55, 22.2))
	_lantern(Vector3(-2.35, 2.55, 14.4))
	_lantern(Vector3(2.35, 2.55, 14.4))
	_lantern(Vector3(-2.35, 2.55, 7.6))
	_lantern(Vector3(2.35, 2.55, 7.6))
	_lantern(Vector3(-2.35, 2.55, -0.4))
	_lantern(Vector3(2.35, 2.55, -0.4))
	_lantern(Vector3(-2.35, 2.55, -16.2))
	_lantern(Vector3(2.35, 2.55, -16.2))
	_firepit(Vector3(-5.4, 0, 10.2), true)
	_firepit(Vector3(5.6, 0, 10.6), false)
	_firepit(Vector3(-8.2, 0, -16.6), false)
	_firepit(Vector3(8.2, 0, -16.6), false)
	_build_castle_gate()
	_sign(Vector3(0, 3.5, 4.1), "ROAD TAX")
	_plant_forest()

func _castle_piece(src: Dictionary, name: String, pos: Vector3, yaw: float, s: float) -> void:
	if not src.has(name):
		return
	var n := (src[name] as Node3D).duplicate() as Node3D
	n.position = pos
	n.rotation = Vector3(0, yaw, 0)
	n.scale = Vector3(s, s, s)
	_unshade(n)
	add_child(n)

func _build_castle_gate() -> void:
	var packed = load("res://assets/models/castle/Castles_and_Forts.glb")
	if packed == null:
		return
	var catalog := packed.instantiate() as Node3D
	var src := {}
	var stack: Array = [catalog]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		src[n.name] = n
		for c in n.get_children():
			stack.append(c)
	var S := 2.5
	var z := -21.2
	var yaw := PI / 2.0
	_castle_piece(src, "Gate_2x4_doorway", Vector3(0, 0, z), yaw, S)
	_castle_piece(src, "Gate_Door", Vector3(-0.7, 0, z + 0.15), yaw, S)
	_castle_piece(src, "Gate_Door", Vector3(0.7, 0, z + 0.15), yaw + PI, S)
	for side in [-1.0, 1.0]:
		var tx := side * 6.6
		_castle_piece(src, "Tower_Mid", Vector3(tx, 0, z), 0.0, S)
		_castle_piece(src, "Tower_top_1", Vector3(tx, 2.0 * S, z), 0.0, S)
		_castle_piece(src, "Roof_Cone", Vector3(tx, 4.15 * S, z), 0.0, S)
		_torch(Vector3(tx + side * 1.1, 3.4, z + 1.3), Color(1.0, 0.54, 0.2), 2.2)
		for i in 3:
			var wx := side * (12.2 + i * 10.0)
			var wall := "Wall_2x4_ruined" if i == 2 else "Wall_2x4"
			_castle_piece(src, wall, Vector3(wx, 0, z), yaw, S)
			_castle_piece(src, "Wall_2x4_walkway", Vector3(wx, 2.0 * S, z), yaw, S)
		var ex := side * 38.0
		_castle_piece(src, "Tower_Mid", Vector3(ex, 0, z), 0.0, S)
		_castle_piece(src, "Tower_top_1", Vector3(ex, 2.0 * S, z), 0.0, S)
		_castle_piece(src, "Roof_Cone", Vector3(ex, 4.15 * S, z), 0.0, S)
	catalog.queue_free()
	for xoff in [-1.0, 1.0]:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(37.6, 8, 2.8)
		col.shape = sh
		body.position = Vector3(xoff * 21.2, 4, z)
		body.add_child(col)
		add_child(body)

func _forest_blocked(x: float, z: float, r := 0.0) -> bool:
	var on_street := z > -22.0 and z < 32.0
	if on_street and absf(x) < 5.2 + r:
		return true
	var houses := [
		[-9.2, 21.5, 7.2, 6.2],
		[-9.2, 14.2, 7.2, 6.4],
		[-9.4, 6.4, 7.8, 7.2],
		[-9.6, -2.2, 8.2, 7.6],
		[-9.0, -11.6, 6.8, 5.6],
		[9.2, 21.5, 7.2, 6.2],
		[9.2, 14.2, 7.2, 6.4],
		[9.6, 6.2, 8.4, 8.4],
		[9.4, -3.4, 8.0, 7.4],
		[8.8, -12.0, 6.6, 5.4],
		[-3.6, 4.2, 2.6, 2.2],
	]
	for h in houses:
		if absf(x - h[0]) < h[2] * 0.5 + r and absf(z - h[1]) < h[3] * 0.5 + r:
			return true
	if z < -19.2 + r and absf(x) < 40.0:
		return true
	if Vector2(x, z - 28.0).length() < 5.0 + r * 0.35:
		return true
	return false

func _plant_forest() -> void:
	_plant_grass_ground()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var placed: Array[Vector2] = []
	var n := 0
	var tries := 0
	var occ := {}
	while n < 1400 and tries < 12000:
		tries += 1
		var x := (rng.randf() - 0.5) * 152.0
		var z := (rng.randf() - 0.5) * 140.0 + 6.0
		var r := rng.randf()
		var kind := "pine"
		if r < 0.18:
			kind = "bush"
		elif r < 0.38:
			kind = "dead"
		var in_town := absf(x) < 15.5 and z > -16.5 and z < 25.8
		if in_town and kind != "bush":
			continue
		var rad := 1.05 if kind == "bush" else (6.2 if kind == "dead" else 8.0)
		if _forest_blocked(x, z, rad):
			continue
		var min_d := 2.4 if kind == "bush" else 4.2
		var key := "%d,%d" % [int(round(x / (min_d * 0.65))), int(round(z / (min_d * 0.65)))]
		if occ.has(key):
			continue
		occ[key] = true
		_psx_tree(kind, Vector3(x, 0, z), rng)
		placed.append(Vector2(x, z))
		n += 1
	var yard := [
		[-9.2, 21.5, 7.2, 6.2],
		[-9.2, 14.2, 7.2, 6.4],
		[-9.4, 6.4, 7.8, 7.2],
		[-9.6, -2.2, 8.2, 7.6],
		[-9.0, -11.6, 6.8, 5.6],
		[9.2, 21.5, 7.2, 6.2],
		[9.2, 14.2, 7.2, 6.4],
		[9.6, 6.2, 8.4, 8.4],
		[9.4, -3.4, 8.0, 7.4],
		[8.8, -12.0, 6.6, 5.4],
	]
	for h in yard:
		var toward := -1.0 if h[0] < 0.0 else 1.0
		for oz in [-h[3] * 0.28, h[3] * 0.28]:
			var bx := h[0] + toward * (h[2] * 0.5 + 1.15)
			var bz := h[1] + oz
			if _forest_blocked(bx, bz, 0.95):
				continue
			_psx_tree("bush", Vector3(bx, 0, bz), rng)
	for i in 40:
		var x := (rng.randf() - 0.5) * 110.0
		var z := (rng.randf() - 0.5) * 100.0 + 4.0
		if _forest_blocked(x, z, 0.9):
			continue
		_prop("res://assets/sprites/rock.png", Vector3(x, 0.42, z), 0.018)
	for i in 1600:
		var x := (rng.randf() - 0.5) * 96.0
		var z := (rng.randf() - 0.5) * 88.0 + 4.0
		if absf(x) < 2.2 and z > -18.0 and z < 30.0:
			continue
		if Vector2(x, z - 28.0).length() < 3.8:
			continue
		if grass_mats.is_empty():
			break
		var mat := grass_mats[rng.randi() % grass_mats.size()]
		var w := 1.2 + rng.randf() * 0.9
		var h := 0.6 + rng.randf() * 0.45
		_psx_card(mat, Vector3(x, h * 0.48, z), w, h, rng.randf() * TAU)

func _tile_mat(path: String, repeat: float, tint: Color, repeat_y := -1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var ry := repeat if repeat_y < 0.0 else repeat_y
	m.uv1_scale = Vector3(repeat, ry, 1)
	return m

func _ground_patch(pos: Vector3, size: Vector2, mat: Material) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.rotation.x = -PI / 2.0
	mi.position = pos
	add_child(mi)

func _cobble_path() -> void:
	var cobble := _tile_mat("res://assets/psx-nature/cobble.png", 3.4, Color(0.83, 0.8, 0.72), 18.0)
	_ground_patch(Vector3(0, 0.018, 5), Vector2(4.4, 50), cobble)
	var z := -17.0
	while z < 28.0:
		for side in [-1.0, 1.0]:
			var w := 0.5 + absf(fmod(z * 13.0, 7.0)) * 0.06
			_ground_patch(Vector3(side * (2.15 + w * 0.42), 0.017, z), Vector2(w, 2.3), cobble)
		z += 2.2
	_ground_patch(Vector3(0, 0.016, 27.2), Vector2(5.4, 4.2), cobble)

func _plant_grass_ground() -> void:
	var grass := _tile_mat("res://assets/psx-nature/grass_tile.png", 2.2, Color(0.77, 0.83, 0.64))
	var moss := _tile_mat("res://assets/psx-nature/moss_tile.png", 2.0, Color(0.72, 0.78, 0.6))
	var mix := _tile_mat("res://assets/psx-nature/dirt_grass.png", 2.4, Color(0.78, 0.72, 0.6))
	var gx := -76.0
	while gx <= 76.0:
		var gz := -70.0
		while gz <= 76.0:
			var skip := absf(gx) < 2.15 and gz > -19.0 and gz < 31.0
			skip = skip or (gz < -19.0 and absf(gx) < 38.0)
			skip = skip or Vector2(gx, gz - 28.0).length() < 3.6
			if not skip:
				var mat := moss if int(gx * 13.0 + gz * 7.0) % 5 == 0 else grass
				var plane := PlaneMesh.new()
				plane.size = Vector2(9.4, 9.4)
				var mi := MeshInstance3D.new()
				mi.mesh = plane
				mi.material_override = mat
				mi.rotation.x = -PI / 2.0
				mi.position = Vector3(gx, 0.014, gz)
				add_child(mi)
			gz += 8.0
		gx += 8.0
	var ez := -16.0
	while ez <= 26.0:
		for side in [-1.0, 1.0]:
			_ground_patch(Vector3(side * 2.55, 0.02, ez), Vector2(1.35, 2.8), mix)
			_ground_patch(Vector3(side * 3.35, 0.021, ez), Vector2(1.5, 2.8), grass)
		ez += 2.4
	for lot in [-9.2, 9.2]:
		for z in [21.5, 14.2, 6.4, -2.2, -11.6]:
			var plane := PlaneMesh.new()
			plane.size = Vector2(4.8, 6.2)
			var mi := MeshInstance3D.new()
			mi.mesh = plane
			mi.material_override = grass
			mi.rotation.x = -PI / 2.0
			mi.position = Vector3(lot * 0.52, 0.015, z)
			add_child(mi)

func _psx_alpha(path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = Color(1, 1, 1)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.32
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m

func _psx_card(mat: Material, pos: Vector3, w: float, h: float, yaw: float) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = yaw
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var a := MeshInstance3D.new()
	a.mesh = q
	a.material_override = mat
	var b := MeshInstance3D.new()
	b.mesh = q
	b.material_override = mat
	b.rotation.y = PI / 2.0
	g.add_child(a)
	g.add_child(b)
	add_child(g)

func _psx_tree(kind: String, pos: Vector3, rng: RandomNumberGenerator) -> void:
	if kind == "bush" and haunted_bushes.size() > 0:
		var inst := haunted_bushes[rng.randi() % haunted_bushes.size()].instantiate() as Node3D
		_fit_plant(inst, pos, 1.8 + rng.randf() * 0.6, rng)
		return
	if haunted_trees.size() > 0:
		var inst := haunted_trees[rng.randi() % haunted_trees.size()].instantiate() as Node3D
		var h := 9.0 if kind == "dead" else 12.0
		_fit_plant(inst, pos, h + rng.randf() * 3.0, rng)
		return
	if kind == "pine" and pine_scene:
		var inst := pine_scene.instantiate() as Node3D
		_fit_plant(inst, pos, 10.0 + rng.randf() * 4.0, rng)

func _flatten_xz(n: Node) -> void:
	if n is Node3D:
		var p := n as Node3D
		p.position.x = 0.0
		p.position.z = 0.0
	for c in n.get_children():
		_flatten_xz(c)

func _fit_plant(inst: Node3D, pos: Vector3, target_h: float, rng: RandomNumberGenerator) -> void:
	_flatten_xz(inst)
	add_child(inst)
	var a := AABB()
	var first := true
	var stack: Array = [inst]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var ma: AABB = (n as MeshInstance3D).get_aabb()
			var xf := (n as MeshInstance3D).global_transform
			var world := AABB(xf * ma.position, ma.size)
			if first:
				a = world
				first = false
			else:
				a = a.merge(world)
		for c in n.get_children():
			stack.append(c)
	if first or a.size.y < 0.01:
		inst.position = pos
		return
	var s := target_h / a.size.y
	inst.scale = Vector3(s, s, s)
	inst.rotation.y = rng.randf() * TAU
	inst.position = Vector3(pos.x, pos.y, pos.z)
	_unshade(inst)

func _unshade(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var sm := mi.get_active_material(i)
				if sm is BaseMaterial3D:
					var m := (sm as BaseMaterial3D).duplicate() as BaseMaterial3D
					m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					m.alpha_scissor_threshold = 0.4
					m.cull_mode = BaseMaterial3D.CULL_DISABLED
					m.albedo_color = Color(1, 1, 1)
					mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_unshade(c)

func _prop(path: String, pos: Vector3, px: float) -> void:
	var s := Sprite3D.new()
	s.texture = load(path)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.pixel_size = px
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.position = pos
	add_child(s)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = DITCH + Vector3(0, 0.9, 0)
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.6
	cap.shape = shape
	player.add_child(cap)
	head = Node3D.new()
	head.position = Vector3(0, 0.72, 0)
	player.add_child(head)
	camera = Camera3D.new()
	camera.fov = 75
	camera.near = 0.08
	camera.far = 200
	head.add_child(camera)
	add_child(player)
	_build_viewmodels()
	_apply_look()

func _build_ditch() -> void:
	var bank_mat := _tile_mat("res://assets/psx-nature/dirt_grass.png", 6.0, Color(0.78, 0.69, 0.56))
	var mud_mat := _tile_mat("res://assets/mud.png", 3.0, Color(0.54, 0.42, 0.28))
	var bank := CylinderMesh.new()
	bank.top_radius = 7.4
	bank.bottom_radius = 3.4
	bank.height = 0.36
	bank.radial_segments = 14
	var bank_mi := MeshInstance3D.new()
	bank_mi.mesh = bank
	bank_mi.material_override = bank_mat
	bank_mi.position = Vector3(0.0, -0.1, 27.7)
	add_child(bank_mi)
	var bed := CylinderMesh.new()
	bed.top_radius = 3.2
	bed.bottom_radius = 3.0
	bed.height = 0.08
	bed.radial_segments = 12
	var bed_mi := MeshInstance3D.new()
	bed_mi.mesh = bed
	bed_mi.material_override = mud_mat
	bed_mi.position = Vector3(0.0, -0.24, 27.7)
	add_child(bed_mi)
	_firepit(Vector3(0.2, 0, 27.4), false)
	_lantern(Vector3(-2.6, 2.2, 26.4))
	_lantern(Vector3(2.6, 2.2, 26.4))

	fairy = Node3D.new()
	fairy.position = Vector3(2.6, 1.45, 24.4)
	var spr := Sprite3D.new()
	spr.texture = nix_tex
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.pixel_size = 0.0044
	spr.shaded = false
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.position.y = 0.2
	fairy.add_child(spr)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.72, 0.82, 0.5)
	glow.light_energy = 1.4
	glow.omni_range = 12.0
	fairy.add_child(glow)
	_tag(fairy, "Nix", 1.15)
	add_child(fairy)

	_add_gift_node("steel", _make_sword(), Vector3(-1.7, 0.08, 25.4), "E — take the sword. Fight the party.")
	_add_gift_node("song", _make_lute(), Vector3(0.05, 0.22, 24.6), "E — take the lute. Get invited.")
	_add_gift_node("spark", _make_book(), Vector3(1.75, 0.08, 25.5), "E — take the spellbook. Blast the party.")
	_build_npcs()

func _tag(node: Node3D, text: String, y: float) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 36
	lab.pixel_size = 0.012
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.91, 0.84, 0.72)
	lab.outline_size = 8
	lab.outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
	lab.position.y = y
	node.add_child(lab)

func _mat(color: Color, rough := 0.7, metal := 0.0, emit: Color = Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit.a > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = 1.3
	return m

func _mesh_part(mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	return mi

func _spr(path: String, pixel_size: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load(path)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.pixel_size = pixel_size
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
	return s

func _make_sword() -> Node3D:
	var g := Node3D.new()
	var s := _spr("res://assets/sprites/sword.png", 0.012)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.position.y = 0.75
	g.add_child(s)
	_tag(g, "Sword", 1.55)
	return g

func _make_lute() -> Node3D:
	var g := Node3D.new()
	var s := _spr("res://assets/sprites/lute.png", 0.011)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.position.y = 0.4
	g.add_child(s)
	_tag(g, "Lute", 0.95)
	return g

func _make_book() -> Node3D:
	var g := Node3D.new()
	var s := _spr("res://assets/sprites/book.png", 0.011)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.position.y = 0.35
	g.add_child(s)
	_tag(g, "Spellbook", 0.85)
	return g

func _add_gift_node(id: String, node: Node3D, pos: Vector3, hint: String) -> void:
	node.position = pos
	add_child(node)
	gifts.append({ "id": id, "node": node, "hint": hint })

func _build_npcs() -> void:
	_add_npc("hob", "Hob", Color(0.29, 0.23, 0.16), Vector3(1.6, 0, 5.2), 0.4, false, [
		"Road tax. Feast night. Double, unless you're expected.",
		"If anyone asks, you were a priest. I'm a businessman.",
	])
	_add_npc("marta", "Marta", Color(0.42, 0.16, 0.16), Vector3(4.8, 0, 6.2), -1.2, false, [
		"They named this cup after him. The ale tastes like a policy.",
		"East gallery, first course. That's where he parks what he stole.",
	])
	_add_npc("bren", "Guard Bren", Color(0.23, 0.27, 0.31), Vector3(-5.5, 0, -17.5), 0.0, true, [
		"Kitchen door unlatches at the second bell. That's not a gift.",
		"Keep that iron in its hole. Feast night is noisy enough.",
	])
	_add_npc("cole", "Guard Cole", Color(0.23, 0.27, 0.31), Vector3(5.5, 0, -17.5), 3.14, true, [
		"Cousin of a baron, are you? They all are, tonight.",
		"The swan is already burnt. His Generous Majesty will not notice.",
	])
	_add_npc("pell", "Sister Pell", Color(0.16, 0.16, 0.22), Vector3(-5.2, 0, -2.2), 1.1, false, [
		"I keep a key because I do not trust doors that belong to kings.",
		"Mara Venn has a spine. Try not to rescue her like furniture.",
	])
	_add_npc("ralf", "Drunk Ralf", Color(0.29, 0.29, 0.16), Vector3(4.2, 0, 11.4), 2.0, false, [
		"I am Cousin Ralf of the eastern orchards. Ask anyone. Don't.",
		"If you need a name at the gate, mine is already ruined. Be my guest.",
	])
	_add_hound(Vector3(4.8, 0, 9.4))
	_add_critter("sq1", "Squirrel", "res://assets/sprites/squirrel.png", Vector3(-14.5, 0, 19), 0.01)
	_add_critter("sq2", "Squirrel", "res://assets/sprites/squirrel.png", Vector3(15.2, 0, 12), 0.01)
	_add_critter("rat1", "Rat", "res://assets/sprites/rat.png", Vector3(6.2, 0, 8.4), 0.012)
	_add_critter("rat2", "Rat", "res://assets/sprites/rat.png", Vector3(-3.2, 0, 5.8), 0.012)

func _add_critter(id: String, npc_name: String, tex: String, pos: Vector3, px: float) -> void:
	var g := Node3D.new()
	g.position = pos
	var s := Sprite3D.new()
	s.texture = load(tex)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.pixel_size = px
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.position.y = 0.25
	g.add_child(s)
	add_child(g)
	npcs.append({
		"id": id, "name": npc_name, "node": g, "kind": "critter",
		"home": pos, "tgt": pos, "wander": randf() * 2.0, "guard": false, "ally": false, "sit": 0.0
	})

func _add_hound(pos: Vector3) -> void:
	var g := Node3D.new()
	g.position = pos
	var sit := Sprite3D.new()
	sit.texture = load("res://assets/sprites/hound-sit.png")
	sit.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sit.pixel_size = 0.014
	sit.shaded = false
	sit.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sit.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sit.position.y = 0.55
	var walk := Sprite3D.new()
	walk.texture = load("res://assets/sprites/hound-walk.png")
	walk.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	walk.pixel_size = 0.014
	walk.shaded = false
	walk.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	walk.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	walk.position.y = 0.4
	walk.visible = false
	g.add_child(sit)
	g.add_child(walk)
	_tag(g, "Bramble", 1.35)
	add_child(g)
	npcs.append({
		"id": "bramble", "name": "Bramble", "node": g, "kind": "hound",
		"sitSpr": sit, "walkSpr": walk,
		"home": pos, "tgt": pos, "wander": 2.0, "guard": false, "ally": false, "sit": 3.0,
		"lines": ["The hound wheezes like a bellows that filed for retirement."]
	})

func _add_npc(id: String, npc_name: String, tunic: Color, pos: Vector3, rot: float, guard: bool, lines: Array) -> void:
	var g := _rig_person(tunic, Color(0.69, 0.54, 0.38), guard, id)
	g.position = pos
	g.rotation.y = rot
	_tag(g, npc_name, 1.95)
	add_child(g)
	npcs.append({
		"id": id, "name": npc_name, "node": g,
		"armL": g.get_meta("armL"), "armR": g.get_meta("armR"),
		"legL": g.get_meta("legL"), "legR": g.get_meta("legR"),
		"torso": g.get_meta("torso"),
		"lines": lines, "purse": 4, "picked": false, "i": 0,
		"home": pos, "tgt": pos, "wander": randf() * 2.0, "guard": guard, "ally": false, "kind": "person"
	})

func _rig_person(tunic: Color, skin: Color, guard: bool, extras: String) -> Node3D:
	var who := extras
	var g := Node3D.new()
	var hips := Node3D.new()
	hips.position.y = 0.9
	g.add_child(hips)
	var torso := Node3D.new()
	torso.position.y = 0.14
	hips.add_child(torso)
	torso.add_child(_doll_spr("res://assets/sprites/doll/%s_torso.png" % who, 0.018, 0.1))
	torso.add_child(_doll_spr("res://assets/sprites/doll/%s_head.png" % who, 0.018, 0.48))
	var armL := Node3D.new()
	armL.position = Vector3(-0.2, 0.22, 0.03)
	armL.add_child(_doll_spr("res://assets/sprites/doll/%s_arm.png" % who, 0.016, -0.22))
	var armR := Node3D.new()
	armR.position = Vector3(0.2, 0.22, 0.03)
	armR.add_child(_doll_spr("res://assets/sprites/doll/%s_arm_r.png" % who, 0.016, -0.22))
	if guard and ResourceLoader.exists("res://assets/sprites/doll/%s_spear.png" % who):
		armR.add_child(_doll_spr("res://assets/sprites/doll/%s_spear.png" % who, 0.014, -0.2))
	torso.add_child(armL)
	torso.add_child(armR)
	var legL := Node3D.new()
	legL.position = Vector3(-0.09, 0, 0)
	legL.add_child(_doll_spr("res://assets/sprites/doll/%s_leg.png" % who, 0.016, -0.26))
	var legR := Node3D.new()
	legR.position = Vector3(0.09, 0, 0)
	legR.add_child(_doll_spr("res://assets/sprites/doll/%s_leg_r.png" % who, 0.016, -0.26))
	hips.add_child(legL)
	hips.add_child(legR)
	g.set_meta("armL", armL)
	g.set_meta("armR", armR)
	g.set_meta("legL", legL)
	g.set_meta("legR", legR)
	g.set_meta("torso", torso)
	return g

func _doll_spr(path: String, pixel_h: float, y: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load(path)
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.pixel_size = 0.016
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.position.y = y
	return s

func _forge_sword() -> Node3D:
	var g := Node3D.new()
	var s := _spr("res://assets/sprites/sword.png", 0.0046)
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.rotation_degrees = Vector3(-90, 0, 0)
	g.add_child(s)
	return g

func _make_arm(tunic: Color, skin: Color, side: float) -> Node3D:
	var arm := Node3D.new()
	arm.position = Vector3(0.24 * side, 0.28, 0)
	var upper := BoxMesh.new()
	upper.size = Vector3(0.1, 0.28, 0.1)
	arm.add_child(_mesh_part(upper, _mat(tunic, 0.92), Vector3(0, -0.14, 0)))
	var fore := BoxMesh.new()
	fore.size = Vector3(0.09, 0.26, 0.09)
	arm.add_child(_mesh_part(fore, _mat(skin, 0.9), Vector3(0, -0.4, 0)))
	return arm

func _make_leg(hide: Material, side: float) -> Node3D:
	var leg := Node3D.new()
	leg.position = Vector3(0.1 * side, 0, 0)
	var thigh := BoxMesh.new()
	thigh.size = Vector3(0.13, 0.34, 0.14)
	leg.add_child(_mesh_part(thigh, hide, Vector3(0, -0.16, 0)))
	var shin := BoxMesh.new()
	shin.size = Vector3(0.12, 0.34, 0.13)
	leg.add_child(_mesh_part(shin, hide, Vector3(0, -0.48, 0)))
	return leg

func _box(size: Vector3, pos: Vector3, color: Color, tex: Texture2D, solid: bool, repeat: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(repeat, repeat, 1)
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		col.shape = sh
		body.add_child(col)
		mi.add_child(body)

func _unlit_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func _torch(pos: Vector3, color: Color, energy: float) -> void:
	_unlit_box(Vector3(0.09, 0.2, 0.09), pos, Color(1.0, 0.58, 0.22))
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 11.0
	light.position = pos
	add_child(light)
	fires.append({ "light": light, "base": energy, "seed": pos.x + pos.z })

func _lantern(pos: Vector3) -> void:
	var h := pos.y
	_unlit_box(Vector3(0.11, h, 0.11), Vector3(pos.x, h * 0.5, pos.z), Color(0.54, 0.35, 0.2))
	_unlit_box(Vector3(0.34, 0.07, 0.34), Vector3(pos.x, h + 0.3, pos.z), Color(0.35, 0.23, 0.14))
	_unlit_box(Vector3(0.22, 0.04, 0.22), Vector3(pos.x, h + 0.02, pos.z), Color(0.29, 0.2, 0.12))
	var glass := _unlit_box(Vector3(0.2, 0.24, 0.2), Vector3(pos.x, h + 0.16, pos.z), Color(1.0, 0.82, 0.56))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.84, 0.55)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.72, 0.32)
	glow.emission_energy_multiplier = 2.4
	glass.material_override = glow
	_torch(pos + Vector3(0, 0.16, 0), Color(1.0, 0.78, 0.42), 2.8)

func _wall_lantern(pos: Vector3) -> void:
	_unlit_box(Vector3(0.28, 0.06, 0.28), pos + Vector3(0, 0.16, 0), Color(0.35, 0.23, 0.14))
	var glass := _unlit_box(Vector3(0.16, 0.18, 0.16), pos, Color(1.0, 0.82, 0.56))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.84, 0.55)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.72, 0.32)
	glow.emission_energy_multiplier = 2.4
	glass.material_override = glow
	_torch(pos, Color(1.0, 0.78, 0.42), 2.2)

func _firepit(pos: Vector3, big: bool) -> void:
	var s := 1.15 if big else 0.85
	_box(Vector3(1.1 * s, 0.18, 1.1 * s), pos + Vector3(0, 0.1, 0), Color(0.16, 0.12, 0.08), null, true, 1.0)
	var flame := OmniLight3D.new()
	flame.light_color = Color(1.0, 0.52, 0.18)
	flame.light_energy = 3.2 if big else 2.3
	flame.omni_range = 12.0
	flame.position = pos + Vector3(0, 1.0, 0)
	add_child(flame)
	fires.append({ "light": flame, "base": flame.light_energy, "seed": pos.x * 3.0 })

func _sign(pos: Vector3, text: String) -> void:
	_box(Vector3(1.7, 0.64, 0.08), pos, Color(0.22, 0.14, 0.08), null, false, 1.0)
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 42
	lab.pixel_size = 0.012
	lab.modulate = Color(0.91, 0.84, 0.72)
	lab.outline_size = 6
	lab.outline_modulate = Color(0.05, 0.03, 0.02)
	lab.position = pos + Vector3(0, 0, 0.08)
	add_child(lab)

func _house(pos: Vector3, size: Vector3, name: String, stone: bool, face: String, art: String = "") -> void:
	_box(size, pos + Vector3(0, size.y * 0.5, 0), Color(0.35, 0.22, 0.16), stone_tex if stone else null, true, 2.0)
	_box(Vector3(size.x + 0.9, 0.22, size.z + 0.7), pos + Vector3(0, size.y + 0.08, 0), Color(0.22, 0.12, 0.08), null, true, 1.0)
	_box(Vector3(0.55, 1.15, 0.55), pos + Vector3(size.x * 0.28, size.y + 0.7, -size.z * 0.22), Color(0.22, 0.16, 0.12), null, true, 1.0)
	var fx := pos.x
	var fz := pos.z
	if face == "e":
		fx = pos.x + size.x * 0.5
	elif face == "w":
		fx = pos.x - size.x * 0.5
	elif face == "s":
		fz = pos.z + size.z * 0.5
	else:
		fz = pos.z - size.z * 0.5
	if art != "":
		var s := Sprite3D.new()
		s.texture = load("res://assets/sprites/buildings/%s.png" % art)
		s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		s.shaded = false
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var front_w := size.z if face == "e" or face == "w" else size.x
		s.pixel_size = front_w / 128.0
		s.position = Vector3(fx, size.y * 0.5, fz)
		if face == "e":
			s.rotation.y = PI * 0.5
		elif face == "w":
			s.rotation.y = -PI * 0.5
		elif face == "n":
			s.rotation.y = PI
		add_child(s)
	_sign(Vector3(fx, size.y + 0.28, fz), name)
	_wall_lantern(Vector3(fx, 2.2, fz))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.72, 0.38)
	glow.light_energy = 1.1
	glow.omni_range = 6.0
	glow.position = Vector3(fx, 1.7, fz)
	add_child(glow)

func _shop(pos: Vector3, size: Vector3, name: String, stone: bool) -> void:
	_house(pos, size, name, stone, "s")

func _build_backdrop() -> void:
	bg_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 82.0
	cyl.bottom_radius = 82.0
	cyl.height = 36.0
	cyl.radial_segments = 24
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	bg_mesh.mesh = cyl
	bg_mesh.position.y = 14.0
	add_child(bg_mesh)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = load("res://assets/sprites/bg/1.png")
	mat.disable_fog = true
	bg_mesh.material_override = mat

func _apply_time() -> void:
	if is_day:
		sky_mat.sky_top_color = Color(0.42, 0.52, 0.62)
		sky_mat.sky_horizon_color = Color(0.62, 0.55, 0.45)
		sky_mat.ground_horizon_color = Color(0.45, 0.38, 0.28)
		sky_mat.ground_bottom_color = Color(0.18, 0.14, 0.1)
		env.fog_light_color = Color(0.48, 0.44, 0.38)
		env.fog_density = 0.008
		env.ambient_light_energy = 1.05
		sun.light_color = Color(0.95, 0.85, 0.65)
		sun.light_energy = 1.3
		sun.rotation_degrees = Vector3(-62, 30, 0)
	else:
		sky_mat.sky_top_color = Color(0.04, 0.05, 0.08)
		sky_mat.sky_horizon_color = Color(0.12, 0.1, 0.09)
		sky_mat.ground_horizon_color = Color(0.1, 0.08, 0.07)
		sky_mat.ground_bottom_color = Color(0.05, 0.04, 0.03)
		env.fog_light_color = Color(0.09, 0.07, 0.06)
		env.fog_density = 0.012
		env.ambient_light_energy = 0.38
		sun.light_color = Color(0.45, 0.5, 0.58)
		sun.light_energy = 0.16
		sun.rotation_degrees = Vector3(-50, 40, 0)

func _build_clouds() -> void:
	for i in 7:
		var s := Sprite3D.new()
		s.texture = load("res://assets/sprites/cloud%d.png" % ((i % 3) + 1))
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.pixel_size = 0.18
		s.shaded = false
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.position = Vector3(-40.0 + i * 14.0, 34.0 + (i % 3) * 3.0, -28.0 + (i % 2) * 22.0)
		s.modulate = Color(0.75, 0.78, 0.82, 0.7)
		add_child(s)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	overlay = Control.new()
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	title_box = ColorRect.new()
	overlay.add_child(title_box)
	title_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_box.color = Color(0.05, 0.035, 0.025, 0.78)

	var center := CenterContainer.new()
	title_box.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 320)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var kicker := Label.new()
	kicker.text = "ROGUE'S JOURNAL  ·  HARTH"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ink(kicker, 14)
	col.add_child(kicker)

	var title := Label.new()
	title.text = "ROGUE'S JOURNAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ink(title, 44)
	col.add_child(title)

	var blurb := Label.new()
	blurb.text = "The cinematic opens later. After it, you wake in the mud.\nA marsh fairy has four ways to get your wife back from the king."
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ink(blurb, 16)
	col.add_child(blurb)

	wake_btn = Button.new()
	wake_btn.text = "Click anywhere — wake in the mud"
	wake_btn.custom_minimum_size = Vector2(280, 48)
	wake_btn.pressed.connect(_on_wake)
	col.add_child(wake_btn)

	var hud := Control.new()
	overlay.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	stats_label = Label.new()
	stats_label.position = Vector2(18, 16)
	_ink(stats_label, 16)
	hud.add_child(stats_label)

	prompt_label = Label.new()
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_label.offset_top = -70
	prompt_label.offset_bottom = -28
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ink(prompt_label, 16)
	hud.add_child(prompt_label)

	talk_label = Label.new()
	talk_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	talk_label.offset_left = -320
	talk_label.offset_right = 320
	talk_label.offset_top = -170
	talk_label.offset_bottom = -84
	talk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	talk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ink(talk_label, 18)
	hud.add_child(talk_label)

	var cross := ColorRect.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -2
	cross.offset_right = 2
	cross.offset_top = -2
	cross.offset_bottom = 2
	cross.color = Color(0.91, 0.84, 0.72, 0.7)
	hud.add_child(cross)

	menu_box = ColorRect.new()
	overlay.add_child(menu_box)
	menu_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_box.color = Color(0.05, 0.035, 0.025, 0.82)
	menu_box.visible = false
	menu_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var mcenter := CenterContainer.new()
	menu_box.add_child(mcenter)
	mcenter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_col = VBoxContainer.new()
	menu_col.custom_minimum_size = Vector2(340, 280)
	menu_col.add_theme_constant_override("separation", 10)
	mcenter.add_child(menu_col)
	_rebuild_menu()
	_refresh_hud()

func _menu_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 40)
	b.pressed.connect(cb)
	return b

func _rebuild_menu() -> void:
	for c in menu_col.get_children():
		c.queue_free()
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ink(title, 22)
	menu_col.add_child(title)
	if menu_page == "settings":
		title.text = "SETTINGS"
		var note := Label.new()
		note.text = "Placeholder. The journal has no knobs yet, only mud."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ink(note, 14)
		menu_col.add_child(note)
		menu_col.add_child(_menu_btn("Back", func() -> void: menu_page = "root"; _rebuild_menu()))
	elif menu_page == "god":
		title.text = "GOD MODE"
		var now := Label.new()
		now.text = "Sky: %s" % ("Day" if is_day else "Night")
		now.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ink(now, 14)
		menu_col.add_child(now)
		menu_col.add_child(_menu_btn("Day", func() -> void: is_day = true; _apply_time(); _rebuild_menu()))
		menu_col.add_child(_menu_btn("Night", func() -> void: is_day = false; _apply_time(); _rebuild_menu()))
		menu_col.add_child(_menu_btn("Back", func() -> void: menu_page = "root"; _rebuild_menu()))
	else:
		title.text = "ROGUE'S JOURNAL"
		menu_col.add_child(_menu_btn("Resume", _close_menu))
		menu_col.add_child(_menu_btn("Settings", func() -> void: menu_page = "settings"; _rebuild_menu()))
		menu_col.add_child(_menu_btn("God mode", func() -> void: menu_page = "god"; _rebuild_menu()))
		menu_col.add_child(_menu_btn("Quit game", func() -> void: get_tree().quit()))

func _open_menu() -> void:
	menu_open = true
	menu_page = "root"
	menu_box.visible = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rebuild_menu()

func _close_menu() -> void:
	menu_open = false
	menu_box.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _ink(label: Label, size: int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.91, 0.84, 0.72))

func _set_phase_title() -> void:
	phase = Phase.TITLE
	title_box.visible = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_wake() -> void:
	if phase != Phase.TITLE:
		return
	phase = Phase.WAKE
	wake_t = 0.0
	title_box.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	log_line = "Mud in your teeth. A light that does not belong to Harth."
	_refresh_hud()

func _input(event: InputEvent) -> void:
	if phase == Phase.TITLE:
		var click: bool = event is InputEventMouseButton and event.pressed
		var key: bool = event is InputEventKey and event.pressed and not event.echo
		if key and event.physical_keycode == KEY_ESCAPE:
			return
		if click or key:
			_on_wake()
		return
	if menu_open:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			_close_menu()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * look_sens
		pitch -= event.relative.y * look_sens
		pitch = clampf(pitch, -1.35, 1.35)
		_apply_look()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_open_menu()
			return
		if event.physical_keycode == KEY_E:
			_interact()
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_4:
			if dog_node != "":
				_dog_pick(event.physical_keycode - KEY_1)
			else:
				_hob_pick(event.physical_keycode - KEY_1)
		if event.physical_keycode == KEY_F:
			_pocket()
		if event.physical_keycode == KEY_R:
			_cast()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_attack()

func _physics_process(delta: float) -> void:
	if phase == Phase.TITLE or menu_open:
		return
	if phase == Phase.WAKE:
		wake_t = minf(1.0, wake_t + delta / 2.2)
		pitch = lerpf(0.85, 0.18, wake_t)
		_apply_look()
		if wake_t >= 1.0:
			phase = Phase.GIFT
		_bob_fairy(delta)
		_refresh_hud()
		return

	var wish := Vector3.ZERO
	var basis := player.global_transform.basis
	if Input.is_physical_key_pressed(KEY_W):
		wish -= basis.z
	if Input.is_physical_key_pressed(KEY_S):
		wish += basis.z
	if Input.is_physical_key_pressed(KEY_A):
		wish -= basis.x
	if Input.is_physical_key_pressed(KEY_D):
		wish += basis.x
	wish.y = 0.0
	if wish.length() > 0.001:
		wish = wish.normalized() * SPEED
	player.velocity.x = wish.x
	player.velocity.z = wish.z
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		player.velocity.y = JUMP_V
	player.move_and_slide()

	if swinging > 0.0:
		swinging -= delta
		var u := 1.0 - clampf(swinging / 0.4, 0.0, 1.0)
		_pose_sword(u)
	elif path == PathId.STEEL and sword_view:
		var idle := sin(fairy_t * 2.1) * 0.03
		sword_view.position = Vector3(0.38, -0.28 + idle, -0.58)
		sword_view.rotation_degrees = Vector3(-32, 10, -18)
	_anim_npcs(delta)
	if spell_cd > 0.0:
		spell_cd -= delta
	_bob_fairy(delta)
	_update_prompt()
	_refresh_hud()
	for f in fires:
		var flick: float = 0.82 + sin(fairy_t * 7.0 + float(f["seed"])) * 0.14
		f["light"].light_energy = float(f["base"]) * flick

func _pose_sword(u: float) -> void:
	if sword_view == null:
		return
	if u < 0.18:
		var k := u / 0.18
		sword_view.position = Vector3(0.38, -0.28 + k * 0.12, -0.58)
		sword_view.rotation_degrees = Vector3(-32 - k * 28.0, 10.0, -18.0 + k * 10.0)
	elif u < 0.5:
		var k := (u - 0.18) / 0.32
		sword_view.position = Vector3(0.38 - k * 0.2, -0.16 - k * 0.08, -0.58 + k * 0.22)
		sword_view.rotation_degrees = Vector3(-60.0 + k * 80.0, 10.0 - k * 20.0, -8.0 - k * 60.0)
	else:
		var k := (u - 0.5) / 0.5
		sword_view.position = Vector3(0.18 + k * 0.2, -0.24 - k * 0.04, -0.36 - k * 0.22)
		sword_view.rotation_degrees = Vector3(-32.0 + (1.0 - k) * 12.0, 10.0, -18.0 - (1.0 - k) * 20.0)

func _anim_npcs(delta: float) -> void:
	for n in npcs:
		if n["node"] == null or not is_instance_valid(n["node"]):
			continue
		n["wander"] = float(n["wander"]) - delta
		var home: Vector3 = n["home"]
		var tgt: Vector3 = n["tgt"]
		n["sit"] = float(n.get("sit", 0.0)) - delta
		var freeze := (hob_node != "" and str(n["id"]) == "hob") or (dog_node != "" and str(n["id"]) == "bramble") or (n.get("kind", "") == "hound" and float(n.get("sit", 0.0)) > 0.0)
		if freeze:
			tgt = n["node"].global_position
			n["tgt"] = tgt
		elif n.get("ally", false):
			tgt = player.global_position + Vector3(1.4, 0, 1.1)
			n["tgt"] = tgt
		elif float(n["wander"]) < 0.0:
			n["wander"] = 0.8 + randf() * 1.4 if n.get("kind", "") == "critter" else 1.8 + randf() * 2.6
			var span := 5.0 if n.get("kind", "") == "critter" else (2.2 if n["guard"] else 2.4)
			tgt = home + Vector3((randf() - 0.5) * span * 2.0, 0.0, (randf() - 0.5) * (1.0 if n["guard"] else span))
			n["tgt"] = tgt
		var pos: Vector3 = n["node"].global_position
		var d := Vector3(tgt.x - pos.x, 0.0, tgt.z - pos.z)
		var moving := (not freeze) and d.length() > 0.2
		if moving:
			var sp := 3.0 if n.get("kind", "") == "critter" else (0.7 if n.get("kind", "") == "hound" else 1.2)
			n["node"].global_position = pos + d.normalized() * sp * delta
		if n.get("kind", "") == "hound":
			var sitting := freeze or float(n.get("sit", 0.0)) > 0.0
			if n.get("sitSpr"):
				n["sitSpr"].visible = sitting
			if n.get("walkSpr"):
				n["walkSpr"].visible = not sitting
		var to_cam: Vector3 = player.global_position - n["node"].global_position
		n["node"].rotation.y = atan2(to_cam.x, to_cam.z)
		var t := fairy_t * (9.0 if moving else 2.4) + home.x
		var a := 0.7 if moving else 0.1
		if n.get("legL"):
			n["legL"].rotation.x = sin(t) * a
			n["legR"].rotation.x = sin(t + PI) * a
			n["armL"].rotation.x = sin(t + PI) * a * 0.85
			n["armR"].rotation.x = sin(t) * a * (0.28 if n["guard"] else 0.85)
			n["torso"].rotation.z = sin(t * 0.5) * (0.06 if moving else 0.025)

func _apply_look() -> void:
	player.rotation.y = yaw
	head.rotation.x = pitch

func _bob_fairy(delta: float) -> void:
	if fairy == null or fairy_gone:
		return
	fairy_t += delta
	fairy.position.y = 1.45 + sin(fairy_t * 2.2) * 0.12

func _near_fairy(max_d := 3.6) -> bool:
	if fairy == null or fairy_gone:
		return false
	var a := Vector2(player.global_position.x, player.global_position.z)
	var b := Vector2(fairy.global_position.x, fairy.global_position.z)
	return a.distance_to(b) < max_d

func _nearest_gift() -> Dictionary:
	var best: Dictionary = {}
	var best_d := 2.2
	for g in gifts:
		if g["node"] == null or not is_instance_valid(g["node"]) or not g["node"].visible:
			continue
		var d: float = player.global_position.distance_to(g["node"].global_position)
		if d < best_d:
			best_d = d
			best = g
	return best

func _nearest_npc(max_d := 2.4) -> Dictionary:
	var best: Dictionary = {}
	var best_d := max_d
	for n in npcs:
		if n["node"] == null or not is_instance_valid(n["node"]):
			continue
		if n.get("kind", "person") == "critter":
			continue
		var d: float = player.global_position.distance_to(n["node"].global_position)
		if d < best_d:
			best_d = d
			best = n
	return best

func _update_prompt() -> void:
	if path == PathId.NONE:
		var g := _nearest_gift()
		if not g.is_empty():
			prompt = g["hint"]
		elif _near_fairy():
			prompt = "E talk with Nix   ·   F pickpocket her for Feather Hands"
		else:
			prompt = "Sword · lute · spellbook in the mud. Or her pockets."
		return
	var n := _nearest_npc()
	if not n.is_empty():
		prompt = "E talk with %s" % n["name"]
		if path == PathId.FEATHER:
			prompt += "   ·   F pickpocket"
		elif path == PathId.SONG:
			prompt += "   ·   click to play for them"
		return
	match path:
		PathId.STEEL:
			prompt = "Click swing  ·  WASD  ·  E talk"
		PathId.SONG:
			prompt = "Click play  ·  get invited at the gate"
		PathId.SPARK:
			prompt = "R cast  ·  the book still bites"
		PathId.FEATHER:
			prompt = "F pickpocket anyone  ·  rob your way in"
		_:
			prompt = "WASD move  ·  mouse look"

func _interact() -> void:
	if path == PathId.NONE:
		var g := _nearest_gift()
		if not g.is_empty():
			_take(g["id"])
			return
		if _near_fairy():
			fairy_talk = "Steel, song, or spark. Pick a gift. Or pick a pocket — I am not your mother."
			return
	var n := _nearest_npc()
	if not n.is_empty():
		if n["id"] == "hob":
			_open_hob(n)
			return
		if n.get("kind", "") == "hound":
			_open_dog(n)
			return
		var lines: Array = n["lines"]
		var i: int = n["i"]
		log_line = "%s\n%s" % [n["name"], lines[i % lines.size()]]
		n["i"] = i + 1
		fairy_talk = ""
		return
	fairy_talk = ""

func _take(id: String) -> void:
	match id:
		"steel":
			path = PathId.STEEL
			fairy_talk = "Try not to die in the first sentence."
			log_line = "The sword is wet. It does not mind."
			if sword_view:
				sword_view.visible = true
		"song":
			path = PathId.SONG
			fairy_talk = "Smile when you lie. It's cheaper than a seal."
			log_line = "The lute smells like someone else's feast."
			if lute_view:
				lute_view.visible = true
		"spark":
			path = PathId.SPARK
			fairy_talk = "The book bites. Point it at problems."
			log_line = "The pages are already warm."
			if book_view:
				book_view.visible = true
	_dismiss_gifts()

func _pocket() -> void:
	if path == PathId.NONE and _near_fairy():
		path = PathId.FEATHER
		fairy_talk = "Feather hands. Don't look so pleased. I felt that."
		log_line = "You lift a coin and a talent she did not offer."
		coin += 9
		fairy_gone = true
		fairy.visible = false
		_dismiss_gifts()
		return
	if path == PathId.FEATHER:
		var n := _nearest_npc()
		if not n.is_empty() and not n["picked"]:
			n["picked"] = true
			coin += int(n["purse"])
			log_line = "You lift %s's purse. They do not notice. Yet." % n["name"]
			return
		coin += 1
		log_line = "A purse that was not watching you."

func _build_viewmodels() -> void:
	sword_view = _forge_sword()
	sword_view.position = Vector3(0.38, -0.28, -0.58)
	sword_view.rotation_degrees = Vector3(-32, 10, -18)
	sword_view.visible = false
	camera.add_child(sword_view)
	lute_view = _make_lute()
	for c in lute_view.get_children():
		if c is Label3D or c is OmniLight3D:
			c.queue_free()
	lute_view.position = Vector3(0.32, -0.24, -0.5)
	lute_view.rotation_degrees = Vector3(20, 40, -14)
	lute_view.visible = false
	camera.add_child(lute_view)
	book_view = _make_book()
	for c in book_view.get_children():
		if c is Label3D or c is OmniLight3D:
			c.queue_free()
	book_view.position = Vector3(0.3, -0.22, -0.48)
	book_view.rotation_degrees = Vector3(28, 22, -8)
	book_view.visible = false
	camera.add_child(book_view)
func _dismiss_gifts() -> void:
	for g in gifts:
		if g["node"] and is_instance_valid(g["node"]):
			g["node"].visible = false
	phase = Phase.PLAY

func _attack() -> void:
	if path != PathId.STEEL and path != PathId.NONE:
		return
	swinging = 0.4
	log_line = "Steel talks first."

func _cast() -> void:
	if path != PathId.SPARK or spell_cd > 0.0 or spark <= 0:
		return
	spark -= 1
	spell_cd = 0.6
	log_line = "The book spat. The drapes will remember."

func _refresh_hud() -> void:
	var path_name := "NONE"
	match path:
		PathId.STEEL:
			path_name = "THE SWORD"
		PathId.SONG:
			path_name = "THE LUTE"
		PathId.SPARK:
			path_name = "THE BOOK"
		PathId.FEATHER:
			path_name = "FEATHER HANDS"
	stats_label.text = "HP %d   COIN %d   SPARK %d\n%s" % [hp, coin, spark, path_name]
	prompt_label.text = prompt
	if hob_node != "":
		var node: Dictionary = _hob_tree().get(hob_node, {})
		var line := str(node.get("line", ""))
		var choices: Array = node.get("choices", [])
		var extra := ""
		for i in choices.size():
			extra += "\n%d. %s" % [i + 1, choices[i]["label"]]
		talk_label.text = "Hob\n" + line + extra
	elif dog_node != "":
		var node: Dictionary = _dog_tree().get(dog_node, {})
		var line := str(node.get("line", ""))
		var choices: Array = node.get("choices", [])
		var extra := ""
		for i in choices.size():
			extra += "\n%d. %s" % [i + 1, choices[i]["label"]]
		talk_label.text = "Bramble\n" + line + extra
	else:
		talk_label.text = ("Nix\n" + fairy_talk) if fairy_talk != "" and not fairy_gone else log_line

func _hob_tree() -> Dictionary:
	return {
		"open": {
			"line": "Road tax. Feast night. Double, unless you're expected. You look like a man who lost a wife and found a ditch. That's not a deduction.",
			"choices": [
				{"id": "wife", "label": "Aldric took my wife. I need the gate."},
				{"id": "bribe", "label": "How much to look the other way?"},
				{"id": "hire", "label": "Walk with me. I'll make you richer than a tax."},
				{"id": "leave", "label": "Keep the road. I'll keep my coin."},
			],
		},
		"wife": {
			"line": "Everyone's wife is at the party. His Generous Majesty collects them like overdue stamps. Bren likes complaints. Cole likes lists. Neither likes husbands.",
			"choices": [
				{"id": "hire", "label": "Then come with me. You know who takes the bribes."},
				{"id": "who", "label": "Who else hates him tonight?"},
				{"id": "leave", "label": "I'll take my chances."},
			],
		},
		"who": {
			"line": "Marta waters the cups. Pell keeps a key she shouldn't. Ralf is already Cousin-of-a-Baron, drunk. Me? I hate the paperwork. The king is a very tall form.",
			"choices": [
				{"id": "hire", "label": "Hate the form with me."},
				{"id": "leave", "label": "I'll start with Marta."},
			],
		},
		"bribe": {
			"line": "Four coins looks the other way. Six writes you onto a list that did not exist this morning. Or you can hire the man who writes the list.",
			"choices": [
				{"id": "pay4", "label": "Four coins. Look away."},
				{"id": "pay6", "label": "Six coins. Put me on the list."},
				{"id": "hire", "label": "Keep the coin. Draw a sword instead."},
			],
		},
		"hire": {
			"line": "Join you? I collect coins, not corpses. Unless the corpses were already late on Tuesday. What's in it besides a ditch and a king?",
			"choices": [
				{"id": "recruit_steal", "label": "He steals from you every feast night. Tonight we steal back."},
				{"id": "recruit_split", "label": "Whatever we lift, we split. I need a clerk with a knife."},
				{"id": "coward", "label": "Coward."},
			],
		},
		"coward": {
			"line": "That's a professional assessment. I'll be here, counting. Try not to become a line item.",
			"choices": [
				{"id": "recruit_steal", "label": "I take it back. Walk with me."},
				{"id": "leave", "label": "Stay counting."},
			],
		},
		"recruited": {
			"line": "Fine. I am an official accompaniment. If anyone asks, you hired a clerk. Clerks bleed like anyone. I'll hit what hits you.",
			"choices": [{"id": "leave", "label": "Stay close."}],
		},
		"paid4": {
			"line": "That's a permit. Don't tell the tune. The gate still has eyes. I don't.",
			"choices": [{"id": "leave", "label": "Good."}, {"id": "hire", "label": "Change of plan. Come with me."}],
		},
		"paid6": {
			"line": "You're expected. You were always expected. I just hadn't written it yet. Don't make me erase you.",
			"choices": [{"id": "leave", "label": "See you at the gate."}, {"id": "recruit_split", "label": "Walk me there."}],
		},
		"broke": {
			"line": "That's pocket lint. Come back when you've robbed someone honest. I don't take IOUs from ditches.",
			"choices": [{"id": "hire", "label": "Then work it off. Walk with me."}, {"id": "leave", "label": "I'll be back."}],
		},
		"ally": {
			"line": "Still breathing. Good. I charge extra for funerals. Point me at a problem if you've got one.",
			"choices": [{"id": "leave", "label": "Stay on my shoulder."}, {"id": "ally_gate", "label": "About the gate."}],
		},
		"ally_gate": {
			"line": "Bren unlatches the kitchen on the second bell. Cole believes in lists. I believe in not being the body they count. I'll swing if they swing.",
			"choices": [{"id": "leave", "label": "That's the job."}],
		},
	}

func _open_hob(n: Dictionary) -> void:
	hob_node = "ally" if n.get("ally", false) else "open"
	fairy_talk = ""
	log_line = "Hob folds a ledger that is mostly threats."
	_refresh_hud()

func _hob_pick(i: int) -> void:
	if hob_node == "":
		return
	var node: Dictionary = _hob_tree().get(hob_node, {})
	var choices: Array = node.get("choices", [])
	if i < 0 or i >= choices.size():
		return
	_hob_apply(str(choices[i]["id"]))

func _hob_apply(id: String) -> void:
	var hob: Dictionary = {}
	for n in npcs:
		if n["id"] == "hob":
			hob = n
			break
	if hob.is_empty():
		return
	if id == "leave":
		hob_node = ""
		log_line = "Hob goes back to counting."
		_refresh_hud()
		return
	if id == "pay4" or id == "pay6":
		var cost := 4 if id == "pay4" else 6
		if coin < cost:
			hob_node = "broke"
			log_line = "Hob sniffs the purse. Dust."
			_refresh_hud()
			return
		coin -= cost
		if id == "pay6":
			invited = true
		hob_node = "paid4" if id == "pay4" else "paid6"
		log_line = "Hob writes something that wasn't there." if id == "pay6" else "Hob looks at a wall."
		_refresh_hud()
		return
	if id == "recruit_steal" or id == "recruit_split":
		hob["ally"] = true
		hob_node = "recruited"
		log_line = "Hob shuts the ledger. The tax has a knife now."
		_refresh_hud()
		return
	if _hob_tree().has(id):
		hob_node = id
		_refresh_hud()

func _dog_tree() -> Dictionary:
	return {
		"open": {
			"line": "The hound wheezes like a bellows that filed for retirement. One ear is considering you. The other is union.",
			"choices": [
				{"id": "pet", "label": "Scratch behind the ear."},
				{"id": "ask", "label": "Ask if he's seen a stolen wife."},
				{"id": "leave", "label": "Leave the old man to his dirt."},
			],
		},
		"pet": {
			"line": "He sits. The whole sagging cathedral of him. A tail thumps once, as if tax has been waived.",
			"choices": [
				{"id": "petmore", "label": "Again. He earned it."},
				{"id": "leave", "label": "That's enough dignity for one night."},
			],
		},
		"petmore": {
			"line": "A groan. Then he leans the entire failed kingdom of his head into your palm. Somewhere a king is not being pet.",
			"choices": [{"id": "leave", "label": "Good boy. Worse king."}],
		},
		"ask": {
			"line": "He smells the ditch on you. Then the inn. Then pity. No wife in that nose. Only gravy, and a rat he has already forgiven.",
			"choices": [
				{"id": "pet", "label": "Scratch him anyway."},
				{"id": "leave", "label": "Keep sniffing, soldier."},
			],
		},
	}

func _open_dog(n: Dictionary) -> void:
	dog_node = "open"
	n["sit"] = maxf(float(n.get("sit", 0.0)), 2.0)
	fairy_talk = ""
	log_line = "The hound has outlived three tax policies."
	_refresh_hud()

func _dog_pick(i: int) -> void:
	if dog_node == "":
		return
	var node: Dictionary = _dog_tree().get(dog_node, {})
	var choices: Array = node.get("choices", [])
	if i < 0 or i >= choices.size():
		return
	var id := str(choices[i]["id"])
	var dog: Dictionary = {}
	for n in npcs:
		if n.get("kind", "") == "hound":
			dog = n
			break
	if id == "leave":
		dog_node = ""
		log_line = "Bramble returns to the important work of existing."
		_refresh_hud()
		return
	if id == "pet" or id == "petmore":
		if not dog.is_empty():
			dog["sit"] = 12.0
		dog_node = "pet" if id == "pet" else "petmore"
		log_line = "You scratch. A kingdom notices nothing." if id == "pet" else "He leans. You are, briefly, a good person."
		_refresh_hud()
		return
	if _dog_tree().has(id):
		dog_node = id
		_refresh_hud()