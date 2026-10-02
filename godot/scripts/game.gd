extends Node3D

enum Phase { TITLE, WAKE, GIFT, PLAY }
enum PathId { NONE, STEEL, SONG, SPARK, FEATHER }

const SPEED := 8.8
const JUMP_V := 7.4
const GRAVITY := 18.0
# Crest, west bend, then back to the gate. Flat at both ends so you leave
# the ditch and arrive at the door heading north, without a straight sightline.
const ROAD_KNOTS: Array[Vector2] = [
	Vector2(16.0, 58.0),
	Vector2(16.0, 50.0),
	Vector2(12.0, 42.0),
	Vector2(5.0, 34.0),
	Vector2(-3.0, 26.0),
	Vector2(-10.0, 18.0),
	Vector2(-14.0, 10.0),
	Vector2(-14.0, 2.0),
	Vector2(-10.0, -6.0),
	Vector2(-4.0, -12.0),
	Vector2(0.0, -17.0),
	Vector2(0.0, -21.2),
]

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
var _night_mats: Array = []
var _pool_tex: Texture2D
var _flame_tex: Texture2D
var _sign_tex: Dictionary = {}
var _lot_root: Node3D = null
var _lots: Array = []
var _road_pts: PackedVector2Array = PackedVector2Array()
var _road_dst: PackedFloat32Array = PackedFloat32Array()
var _road_len := 0.0
var ditch_pos := Vector3.ZERO
var _booth: Dictionary = {}

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

	# Flat unshaded dirt under the whole town. A lit mud box went black at night,
	# and mud.png itself is dark enough to read as a void wherever the grass
	# tiles do not cover (yards, footprints, the ground past the last row).
	var dirt := _tile_mat("res://assets/psx-nature/dirt_grass.png", 28.0, Color(1.05, 0.98, 0.82))
	_watch_night(dirt)
	_ground_patch(Vector3(0, 0.004, 0), Vector2(220, 220), dirt)
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(220, 2, 220)
	floor_col.shape = floor_shape
	floor_body.position.y = -1
	floor_body.add_child(floor_col)
	add_child(floor_body)
	_trace_road()
	_cobble_path()
	_place_town()
	_build_castle_gate()
	_plant_forest()

func _castle_piece(src: Dictionary, name: String, pos: Vector3, yaw: float, s: float) -> void:
	if not src.has(name):
		return
	var n := (src[name] as Node3D).duplicate() as Node3D
	n.position = pos
	n.rotation = Vector3(0, yaw, 0)
	n.scale = Vector3(s, s, s)
	_unshade(n, false)
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
		var tx: float = float(side) * 6.6
		_castle_piece(src, "Tower_Mid", Vector3(tx, 0, z), 0.0, S)
		_castle_piece(src, "Tower_top_1", Vector3(tx, 2.0 * S, z), 0.0, S)
		_castle_piece(src, "Roof_Cone", Vector3(tx, 4.15 * S, z), 0.0, S)
		_torch(Vector3(tx + side * 1.1, 3.4, z + 1.3), Color(1.0, 0.54, 0.2), 2.2)
		for i in 3:
			var wx: float = float(side) * (12.2 + float(i) * 10.0)
			var wall := "Wall_2x4_ruined" if i == 2 else "Wall_2x4"
			_castle_piece(src, wall, Vector3(wx, 0, z), yaw, S)
			_castle_piece(src, "Wall_2x4_walkway", Vector3(wx, 2.0 * S, z), yaw, S)
		var ex: float = float(side) * 38.0
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
	var approach := _road_frame(_road_len - 3.4)
	_sign(Vector3(float(approach["x"]), 2.62, float(approach["z"])), "HARTH\nKING'S GATE", float(approach["yaw"]), true, 0.0, 3.5)

func _adopt(n: Node) -> void:
	if _lot_root != null:
		_lot_root.add_child(n)
	else:
		add_child(n)

func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func _trace_road() -> void:
	_road_pts = PackedVector2Array()
	_road_dst = PackedFloat32Array()
	var ext: Array[Vector2] = []
	ext.append(ROAD_KNOTS[0])
	for k in ROAD_KNOTS:
		ext.append(k)
	ext.append(ROAD_KNOTS[ROAD_KNOTS.size() - 1])
	for i in range(1, ext.size() - 2):
		for s in 10:
			_road_pts.append(_catmull(ext[i - 1], ext[i], ext[i + 1], ext[i + 2], float(s) / 10.0))
	_road_pts.append(ROAD_KNOTS[ROAD_KNOTS.size() - 1])
	_road_dst.append(0.0)
	for i in range(1, _road_pts.size()):
		_road_dst.append(_road_dst[i - 1] + _road_pts[i].distance_to(_road_pts[i - 1]))
	_road_len = _road_dst[_road_dst.size() - 1]
	var start := _road_frame(0.0)
	ditch_pos = Vector3(start["x"], 0.0, start["z"])
	var saw_east := false
	var saw_west := false
	for p in _road_pts:
		saw_east = saw_east or p.x > 8.0
		saw_west = saw_west or p.x < -8.0
	if not saw_east or not saw_west:
		push_error("Town road does not bend into an S")

func _road_frame(dist: float) -> Dictionary:
	var d := clampf(dist, 0.0, maxf(_road_len - 0.05, 0.0))
	var lo := 0
	var hi := _road_dst.size() - 1
	while lo < hi - 1:
		var mid := (lo + hi) >> 1
		if _road_dst[mid] <= d:
			lo = mid
		else:
			hi = mid
	var i := mini(lo, _road_pts.size() - 2)
	var span := maxf(_road_dst[i + 1] - _road_dst[i], 0.0001)
	var u := clampf((d - _road_dst[i]) / span, 0.0, 1.0)
	var a := _road_pts[i]
	var b := _road_pts[i + 1]
	var tangent := b - a
	if tangent.length_squared() < 0.000001:
		tangent = Vector2(0.0, -1.0)
	else:
		tangent = tangent.normalized()
	return {
		"x": lerpf(a.x, b.x, u),
		"z": lerpf(a.y, b.y, u),
		"tx": tangent.x,
		"tz": tangent.y,
		"rx": -tangent.y,
		"rz": tangent.x,
		"yaw": atan2(-tangent.x, -tangent.y),
	}

func _road_dist_to(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 10000.0
	for i in range(_road_pts.size() - 1):
		var a := _road_pts[i]
		var b := _road_pts[i + 1]
		var ab := b - a
		var denom := ab.length_squared()
		var t := 0.0 if denom < 0.0001 else clampf((p - a).dot(ab) / denom, 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

func _rect_corners(lot: Dictionary, pad: float) -> Array[Vector2]:
	var pos: Vector3 = lot["pos"]
	var size: Vector3 = lot["size"]
	var yaw: float = float(lot["yaw"])
	var hx := size.x * 0.5 + pad
	var hz := size.z * 0.5 + pad
	var c := cos(yaw)
	var s := sin(yaw)
	var out: Array[Vector2] = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var lx := float(sx) * hx
			var lz := float(sz) * hz
			out.append(Vector2(pos.x + c * lx + s * lz, pos.z - s * lx + c * lz))
	return out

func _lot_overlaps(a: Dictionary, b: Dictionary, pad: float) -> bool:
	var pa := _rect_corners(a, pad)
	var pb := _rect_corners(b, pad)
	var yaws: Array[float] = [float(a["yaw"]), float(b["yaw"])]
	for yaw in yaws:
		var c := cos(yaw)
		var s := sin(yaw)
		for axis_i in 2:
			var ax := c if axis_i == 0 else s
			var az := -s if axis_i == 0 else c
			var a0 := 1.0e9
			var a1 := -1.0e9
			for p in pa:
				var v: float = p.x * ax + p.y * az
				a0 = minf(a0, v)
				a1 = maxf(a1, v)
			var b0 := 1.0e9
			var b1 := -1.0e9
			for p in pb:
				var v: float = p.x * ax + p.y * az
				b0 = minf(b0, v)
				b1 = maxf(b1, v)
			if a1 < b0 or b1 < a0:
				return false
	return true

func _lot_hits_wall(lot: Dictionary) -> bool:
	for p in _rect_corners(lot, 0.0):
		if p.y < -18.5:
			return true
	return false

func _point_in_lot(x: float, z: float, lot: Dictionary, pad: float) -> bool:
	var pos: Vector3 = lot["pos"]
	var size: Vector3 = lot["size"]
	var yaw: float = float(lot["yaw"])
	var dx := x - pos.x
	var dz := z - pos.z
	var c := cos(yaw)
	var s := sin(yaw)
	var lx := c * dx - s * dz
	var lz := s * dx + c * dz
	return absf(lx) < size.x * 0.5 + pad and absf(lz) < size.z * 0.5 + pad

func _place_town() -> void:
	# Left bank faces the road: local +X is the walker's right, so that door looks back at the street.
	# Right-bank lots sit half a plot further along, which leaves a gap on the inside of each bend.
	var left: Array = [
		["MUD HOUSE", 7.2, 4.1, 6.2, "e", "cottage", false],
		["NO BEDS", 7.2, 4.4, 6.4, "e", "hostel", false],
		["CHAR HEAP", 7.8, 5.0, 7.2, "e", "shop", false],
		["ST. DRIP", 8.2, 6.4, 7.6, "e", "chapel", true],
		["LEAN-TO", 6.8, 4.0, 5.6, "e", "cottage", false],
	]
	var right: Array = [
		["COOPER", 7.2, 4.0, 6.2, "w", "shop", false],
		["HIDE WORKS", 7.2, 4.2, 6.4, "w", "shop", false],
		["THE CLOSED FIST", 8.4, 6.2, 8.4, "w", "smith", true],
		["THE KING'S NAGS", 8.0, 4.3, 7.4, "w", "stables", false],
		["TALLOW", 6.6, 3.9, 5.4, "w", "shop", false],
	]
	var li := 0
	var ri := 0
	var usable0 := 12.0
	var usable1 := _road_len - 9.0
	var span := 4.48
	while li < left.size() or ri < right.size():
		var use_left := ri >= right.size() or (li < left.size() and float(li) <= float(ri) + 0.48)
		var row: Array = left[li] if use_left else right[ri]
		var u := float(li) if use_left else float(ri) + 0.48
		var side := -1.0 if use_left else 1.0
		if use_left:
			li += 1
		else:
			ri += 1
		var name := str(row[0])
		var sx := float(row[1])
		var sy := float(row[2])
		var sz := float(row[3])
		var face := str(row[4])
		var kind := str(row[5])
		var stone: bool = bool(row[6])
		var d := usable0 + (usable1 - usable0) * (u / span)
		var found := false
		while d < _road_len - 6.0:
			var frame := _road_frame(d)
			var off := 4.8 + sx * 0.5
			var candidate := {
				"pos": Vector3(frame["x"] + side * float(frame["rx"]) * off, 0.0, frame["z"] + side * float(frame["rz"]) * off),
				"size": Vector3(sx, sy, sz),
				"yaw": float(frame["yaw"]),
			}
			var blocked := _lot_hits_wall(candidate)
			if not blocked:
				for prev in _lots:
					if _lot_overlaps(candidate, prev, 0.9):
						blocked = true
						break
			if not blocked:
				_house(candidate["pos"], candidate["size"], name, stone, face, kind, float(frame["yaw"]))
				found = true
				break
			d += 0.2
		if not found:
			push_error("No room on the S-curve for %s" % name)
	_dress_road()
	if _lots.size() != 10:
		push_error("S-curve town placed %d lots" % _lots.size())
	for i in _lots.size():
		for j in range(i + 1, _lots.size()):
			if _lot_overlaps(_lots[i], _lots[j], 0.3):
				push_error("Lots overlap: %s / %s" % [str(_lots[i]["name"]), str(_lots[j]["name"])])
	if not _booth.is_empty():
		for lot in _lots:
			if _lot_overlaps(lot, _booth, 0.15):
				push_error("Toll booth overlaps %s" % str(lot["name"]))

func _axis_cross() -> Dictionary:
	var best := _road_frame(8.0)
	var d := 9.0
	while d < _road_len - 8.0:
		var frame := _road_frame(d)
		if absf(float(frame["x"])) < absf(float(best["x"])):
			best = frame
		d += 1.0
	return best

func _dress_road() -> void:
	var toll := _axis_cross()
	var booth_side := -1.0
	var booth_off := 5.2
	var pivot := Node3D.new()
	pivot.position = Vector3(
		float(toll["x"]) + booth_side * float(toll["rx"]) * booth_off,
		0.0,
		float(toll["z"]) + booth_side * float(toll["rz"]) * booth_off
	)
	pivot.rotation.y = float(toll["yaw"])
	add_child(pivot)
	_lot_root = pivot
	_box(Vector3(2.2, 2.4, 2.4), Vector3(0.0, 1.2, 0.0), Color(0.55, 0.42, 0.30), null, true, 2.0)
	_sign(Vector3(1.42, 2.15, 0.15), "ROAD TAX", PI * 0.5)
	_wall_lantern(Vector3(1.36, 1.72, -0.72), PI * 0.5)
	_lot_root = null
	_booth = {
		"pos": pivot.position,
		"size": Vector3(2.2, 2.4, 2.4),
		"yaw": float(toll["yaw"]),
	}
	var d := 18.0
	var lamp_side := 1.0
	while d < _road_len - 14.0:
		var frame := _road_frame(d)
		var lamp_x: float = float(frame["x"]) + lamp_side * float(frame["rx"]) * 3.2
		var lamp_z: float = float(frame["z"]) + lamp_side * float(frame["rz"]) * 3.2
		if not _inside_lot(lamp_x, lamp_z, 0.35):
			_lantern(Vector3(lamp_x, 2.45, lamp_z))
		lamp_side = -lamp_side
		d += 18.0
	var last := _road_frame(_road_len - 8.0)
	for gate_side_v in [-1.0, 1.0]:
		var gate_side := float(gate_side_v)
		var gate_x: float = float(last["x"]) + gate_side * float(last["rx"]) * 2.7
		var gate_z: float = float(last["z"]) + gate_side * float(last["rz"]) * 2.7
		if not _inside_lot(gate_x, gate_z, 0.3):
			_lantern(Vector3(gate_x, 2.45, gate_z))
	var approach := _road_frame(_road_len - 8.0)
	for side_v in [-1.0, 1.0]:
		var side := float(side_v)
		var pit := Vector3.ZERO
		var placed := false
		for off in [6.4, 8.2, 10.0]:
			pit = Vector3(
				float(approach["x"]) + side * float(approach["rx"]) * off,
				0.0,
				float(approach["z"]) + side * float(approach["rz"]) * off
			)
			if not _inside_lot(pit.x, pit.z, 0.8):
				placed = true
				break
		if placed:
			_firepit(pit, false)


func _assert_stands(who: String, pos: Vector3) -> void:
	if _inside_shell(pos.x, pos.z):
		push_error("%s is standing inside a building" % who)

func _inside_shell(x: float, z: float) -> bool:
	for lot in _lots:
		if str(lot.get("kind", "")) == "smith":
			if _in_lot_span(x, z, lot, lot["solid"]):
				return true
		elif _point_in_lot(x, z, lot, -0.05):
			return true
	if not _booth.is_empty() and _point_in_lot(x, z, _booth, -0.05):
		return true
	return false

func _in_lot_span(x: float, z: float, lot: Dictionary, span: Array) -> bool:
	var pos: Vector3 = lot["pos"]
	var yaw: float = float(lot["yaw"])
	var dx := x - pos.x
	var dz := z - pos.z
	var c := cos(yaw)
	var s := sin(yaw)
	var lx := c * dx - s * dz
	var lz := s * dx + c * dz
	return lx > float(span[0]) and lx < float(span[1]) and lz > float(span[2]) and lz < float(span[3])

func _inside_lot(x: float, z: float, pad: float) -> bool:
	for lot in _lots:
		if _point_in_lot(x, z, lot, pad):
			return true
	if not _booth.is_empty() and _point_in_lot(x, z, _booth, pad):
		return true
	return false

func _lot_named(lot_name: String) -> Dictionary:
	for lot in _lots:
		if str(lot["name"]) == lot_name:
			return lot
	return {}

func _porch(lot: Dictionary, along: float, out: float) -> Vector3:
	return _lot_offset(lot, along, out, true)

func _outer(lot: Dictionary, along: float, out: float) -> Vector3:
	return _lot_offset(lot, along, out, false)

func _lot_offset(lot: Dictionary, along: float, out: float, toward_road: bool) -> Vector3:
	var size: Vector3 = lot["size"]
	var yaw: float = float(lot["yaw"])
	var inward := 1.0 if str(lot["face"]) == "e" else -1.0
	if not toward_road:
		inward = -inward
	var lx := inward * (size.x * 0.5 + out)
	var c := cos(yaw)
	var s := sin(yaw)
	var pos: Vector3 = lot["pos"]
	return pos + Vector3(c * lx + s * along, 0.0, -s * lx + c * along)

func _forest_blocked(x: float, z: float, r := 0.0) -> bool:
	if _road_dist_to(x, z) < 5.4 + r:
		return true
	for lot in _lots:
		if _point_in_lot(x, z, lot, r):
			return true
	if not _booth.is_empty() and _point_in_lot(x, z, _booth, r):
		return true
	if z < -19.2 + r and absf(x) < 42.0:
		return true
	if Vector2(x - ditch_pos.x, z - ditch_pos.z).length() < 6.2 + r * 0.35:
		return true
	return false

func _plant_forest() -> void:
	for mat in grass_mats:
		_watch_night(mat)
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
		var in_town := _road_dist_to(x, z) < 18.0
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
	for lot in _lots:
		var size: Vector3 = lot["size"]
		var yaw: float = float(lot["yaw"])
		var outward := -1.0 if str(lot["face"]) == "e" else 1.0
		var c := cos(yaw)
		var s := sin(yaw)
		var pos: Vector3 = lot["pos"]
		for oz in [-size.z * 0.28, size.z * 0.28]:
			var lx := outward * (size.x * 0.5 + 1.15)
			var bx: float = pos.x + c * lx + s * oz
			var bz: float = pos.z - s * lx + c * oz
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
		if _road_dist_to(x, z) < 3.4:
			continue
		if Vector2(x - ditch_pos.x, z - ditch_pos.z).length() < 4.2:
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

func _watch_night(mat: StandardMaterial3D) -> void:
	_night_mats.append({ "mat": mat, "day": mat.albedo_color })

func _tint_ground() -> void:
	# Unshaded ground ignores OmniLight. Night halves the albedo; lamp pools paint the light back.
	var k := 1.0 if is_day else 0.5
	for entry in _night_mats:
		var mat: StandardMaterial3D = entry["mat"]
		var day: Color = entry["day"]
		mat.albedo_color = Color(day.r * k, day.g * k, day.b * k, day.a)

func _ground_patch(pos: Vector3, size: Vector2, mat: Material, yaw := 0.0) -> void:
	# PlaneMesh defaults to FACE_Y (already flat, normal +Y). A -90° X
	# turn stands it up into a wall you walk through.
	var plane := PlaneMesh.new()
	plane.orientation = PlaneMesh.FACE_Y
	plane.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)

func _cobble_path() -> void:
	var cobble := _tile_mat("res://assets/psx-nature/cobble.png", 3.4, Color(0.83, 0.8, 0.72), 18.0)
	_watch_night(cobble)
	var step := 2.15
	var d := 5.0
	while d < _road_len - 2.4:
		var frame := _road_frame(d)
		var along := atan2(float(frame["tx"]), float(frame["tz"]))
		var lift := 0.018 if int(d / step) % 2 == 0 else 0.019
		_ground_patch(Vector3(float(frame["x"]), lift, float(frame["z"])), Vector2(5.1, step * 1.2), cobble, along)
		var w := 0.55 + absf(fmod(d * 1.7, 7.0)) * 0.05
		for side in [-1.0, 1.0]:
			var ox: float = float(side) * (2.35 + w * 0.35)
			_ground_patch(Vector3(
				float(frame["x"]) + float(frame["rx"]) * ox,
				0.017,
				float(frame["z"]) + float(frame["rz"]) * ox
			), Vector2(w, step * 1.2), cobble, along)
		d += step

func _plant_grass_ground() -> void:
	var grass := _tile_mat("res://assets/psx-nature/grass_tile.png", 2.2, Color(0.77, 0.83, 0.64))
	var moss := _tile_mat("res://assets/psx-nature/moss_tile.png", 2.0, Color(0.72, 0.78, 0.6))
	var mix := _tile_mat("res://assets/psx-nature/dirt_grass.png", 2.4, Color(0.78, 0.72, 0.6))
	_watch_night(grass)
	_watch_night(moss)
	_watch_night(mix)
	var gx := -76.0
	while gx <= 76.0:
		var gz := -70.0
		while gz <= 76.0:
			var skip := _road_dist_to(gx, gz) < 7.2
			skip = skip or (gz < -19.0 and absf(gx) < 38.0)
			skip = skip or Vector2(gx - ditch_pos.x, gz - ditch_pos.z).length() < 6.5
			if not skip:
				var mat := moss if int(gx * 13.0 + gz * 7.0) % 5 == 0 else grass
				var plane := PlaneMesh.new()
				plane.orientation = PlaneMesh.FACE_Y
				plane.size = Vector2(9.4, 9.4)
				var mi := MeshInstance3D.new()
				mi.mesh = plane
				mi.material_override = mat
				mi.position = Vector3(gx, 0.014, gz)
				add_child(mi)
			gz += 8.0
		gx += 8.0
	var ed := 6.0
	while ed < _road_len - 3.0:
		var frame := _road_frame(ed)
		var along := atan2(float(frame["tx"]), float(frame["tz"]))
		for side in [-1.0, 1.0]:
			_ground_patch(Vector3(
				float(frame["x"]) + float(side) * float(frame["rx"]) * 3.35,
				0.016,
				float(frame["z"]) + float(side) * float(frame["rz"]) * 3.35
			), Vector2(1.2, 2.6), mix, along)
			_ground_patch(Vector3(
				float(frame["x"]) + float(side) * float(frame["rx"]) * 4.35,
				0.0165,
				float(frame["z"]) + float(side) * float(frame["rz"]) * 4.35
			), Vector2(1.35, 2.6), grass, along)
		ed += 2.4
	for lot in _lots:
		var yard := _porch(lot, 0.0, 1.15)
		var plane := PlaneMesh.new()
		plane.orientation = PlaneMesh.FACE_Y
		plane.size = Vector2(1.7, 3.4)
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		mi.material_override = grass
		mi.position = Vector3(yard.x, 0.016, yard.z)
		mi.rotation.y = float(lot["yaw"])
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

func _unshade(n: Node, foliage: bool = true) -> void:
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
					m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
					m.roughness = 1.0
					m.metallic = 0.0
					m.metallic_specular = 0.0
					# Foliage cards need a cutout. Castle stone is opaque; scissor plus
					# two-sided drawing let the gate sort through the player.
					if foliage:
						m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
						m.alpha_scissor_threshold = 0.4
						m.cull_mode = BaseMaterial3D.CULL_DISABLED
					else:
						m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
						m.cull_mode = BaseMaterial3D.CULL_BACK
						m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
					if m.albedo_texture != null:
						m.albedo_color = Color(1, 1, 1)
					mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_unshade(c, foliage)

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
	player.position = ditch_pos + Vector3(0, 0.9, 0)
	var leave := _road_frame(2.0)
	yaw = float(leave["yaw"])
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
	_watch_night(bank_mat)
	_watch_night(mud_mat)
	var bank := CylinderMesh.new()
	bank.top_radius = 7.4
	bank.bottom_radius = 3.4
	bank.height = 0.36
	bank.radial_segments = 14
	var bank_mi := MeshInstance3D.new()
	bank_mi.mesh = bank
	bank_mi.material_override = bank_mat
	bank_mi.position = ditch_pos + Vector3(0.0, -0.1, 0.0)
	add_child(bank_mi)
	var bed := CylinderMesh.new()
	bed.top_radius = 3.2
	bed.bottom_radius = 3.0
	bed.height = 0.08
	bed.radial_segments = 12
	var bed_mi := MeshInstance3D.new()
	bed_mi.mesh = bed
	bed_mi.material_override = mud_mat
	bed_mi.position = ditch_pos + Vector3(0.0, -0.24, 0.0)
	add_child(bed_mi)
	var mouth := _road_frame(2.4)
	_firepit(Vector3(
		float(mouth["x"]) + float(mouth["rx"]) * 1.7,
		0.0,
		float(mouth["z"]) + float(mouth["rz"]) * 1.7
	), false)
	for side in [-1.0, 1.0]:
		_lantern(Vector3(
			ditch_pos.x + side * float(mouth["rx"]) * 3.3,
			2.35,
			ditch_pos.z + side * float(mouth["rz"]) * 3.3
		))
	var welcome := _road_frame(7.4)
	_sign(Vector3(
		float(welcome["x"]) - float(welcome["rx"]) * 2.55,
		2.28,
		float(welcome["z"]) - float(welcome["rz"]) * 2.55
	), "WELCOME\nTO HARTH", float(welcome["yaw"]), true, 0.32)

	var nix_at := _road_frame(5.4)
	fairy = Node3D.new()
	fairy.position = Vector3(
		float(nix_at["x"]) + float(nix_at["rx"]) * 2.3,
		1.45,
		float(nix_at["z"]) + float(nix_at["rz"]) * 2.3
	)
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

	var gifts_at := _road_frame(3.3)
	_add_gift_node("steel", _make_sword(), Vector3(
		float(gifts_at["x"]) - float(gifts_at["rx"]) * 1.55,
		0.08,
		float(gifts_at["z"]) - float(gifts_at["rz"]) * 1.55
	), "E — take the sword. Fight the party.")
	_add_gift_node("song", _make_lute(), Vector3(float(gifts_at["x"]), 0.22, float(gifts_at["z"])), "E — take the lute. Get invited.")
	_add_gift_node("spark", _make_book(), Vector3(
		float(gifts_at["x"]) + float(gifts_at["rx"]) * 1.6,
		0.08,
		float(gifts_at["z"]) + float(gifts_at["rz"]) * 1.6
	), "E — take the spellbook. Blast the party.")
	_tint_ground()
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
	var toll := _axis_cross()
	var hob_at := Vector3(
		float(toll["x"]) + float(toll["rx"]) * 1.15,
		0.0,
		float(toll["z"]) + float(toll["rz"]) * 1.15
	)
	_add_npc("hob", "Hob", hob_at, float(toll["yaw"]), false, [
		"Road tax. Feast night. Double, unless you're expected.",
		"If anyone asks, you were a priest. I'm a businessman.",
	])
	var fist_lot := _lot_named("THE CLOSED FIST")
	var marta_at: Vector3 = fist_lot["smith_pos"]
	_add_npc("marta", "Marta", marta_at, float(fist_lot["smith_yaw"]), false, [
		"The cup was his joke. This fist is mine. You want iron, you pay before it cools.",
		"East gallery, first course. I shod the horse that hauled her there. The steel was better than the man.",
	])
	var gate := _road_frame(_road_len - 4.2)
	var bren_at := Vector3(
		float(gate["x"]) - float(gate["rx"]) * 5.2,
		0.0,
		float(gate["z"]) - float(gate["rz"]) * 5.2
	)
	var cole_at := Vector3(
		float(gate["x"]) + float(gate["rx"]) * 5.2,
		0.0,
		float(gate["z"]) + float(gate["rz"]) * 5.2
	)
	_add_npc("bren", "Guard Bren", bren_at, float(gate["yaw"]), true, [
		"Kitchen door unlatches at the second bell. That's not a gift.",
		"Keep that iron in its hole. Feast night is noisy enough.",
	])
	_add_npc("cole", "Guard Cole", cole_at, float(gate["yaw"]) + PI, true, [
		"Cousin of a baron, are you? They all are, tonight.",
		"The swan is already burnt. His Generous Majesty will not notice.",
	])
	var pell_lot := _lot_named("ST. DRIP")
	_add_npc("pell", "Sister Pell", _porch(pell_lot, 0.4, 1.9), float(pell_lot["yaw"]), false, [
		"I keep a key because I do not trust doors that belong to kings.",
		"Mara Venn has a spine. Try not to rescue her like furniture.",
	])
	var ralf_lot := _lot_named("HIDE WORKS")
	var ralf_at := _porch(ralf_lot, 1.2, 1.7)
	_add_npc("ralf", "Drunk Ralf", ralf_at, float(ralf_lot["yaw"]) + 0.4, false, [
		"I am Cousin Ralf of the eastern orchards. Ask anyone. Don't.",
		"If you need a name at the gate, mine is already ruined. Be my guest.",
	])
	_add_hound(_porch(ralf_lot, -1.4, 2.6))
	var mud := _lot_named("MUD HOUSE")
	var coop := _lot_named("COOPER")
	_add_critter("sq1", "Squirrel", "res://assets/sprites/squirrel.png", _outer(mud, 0.4, 1.4), 0.01)
	_add_critter("sq2", "Squirrel", "res://assets/sprites/squirrel.png", _outer(coop, -0.6, 1.3), 0.01)
	_add_critter("rat1", "Rat", "res://assets/sprites/rat.png", hob_at + Vector3(float(toll["tx"]) * 2.2, 0.0, float(toll["tz"]) * 2.2), 0.012)
	_add_critter("rat2", "Rat", "res://assets/sprites/rat.png", hob_at - Vector3(float(toll["rx"]) * 1.8, 0.0, float(toll["rz"]) * 1.8), 0.012)
	_assert_stands("Hob", hob_at)
	_assert_stands("Marta", marta_at)
	_assert_stands("Guard Bren", bren_at)
	_assert_stands("Guard Cole", cole_at)
	_assert_stands("Sister Pell", _porch(pell_lot, 0.4, 1.9))
	_assert_stands("Drunk Ralf", ralf_at)
	_assert_stands("Bramble", _porch(ralf_lot, -1.4, 2.6))

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

func _add_npc(id: String, npc_name: String, pos: Vector3, rot: float, guard: bool, lines: Array) -> void:
	var g := _rig_person(id)
	g.position = pos
	g.rotation.y = rot
	add_child(g)
	var top := _mesh_top(g)
	_tag(g, npc_name, top + 0.22)
	var bob: Node3D = g.get_meta("body")
	npcs.append({
		"id": id, "name": npc_name, "node": g,
		"body": bob, "body_y": bob.position.y,
		"lines": lines, "purse": 4, "picked": false, "i": 0,
		"home": pos, "tgt": pos, "wander": randf() * 2.0, "guard": guard, "ally": false, "kind": "person"
	})
	if id == "marta":
		var hand := _arm_hammer(g)
		npcs[npcs.size() - 1]["station"] = true
		npcs[npcs.size() - 1]["work_yaw"] = rot
		npcs[npcs.size() - 1]["hammer"] = hand

func _npc_mesh(id: String) -> String:
	match id:
		"hob":
			return "res://assets/psx-characters/peasant.glb"
		"ralf":
			return "res://assets/psx-characters/peasant_blonde.glb"
		"marta":
			return "res://assets/psx-characters/bartender.glb"
		"pell":
			return "res://assets/psx-characters/nun.glb"
		"bren", "cole":
			return "res://assets/psx-characters/inquisitor.glb"
		_:
			push_error("No PSX mesh for NPC %s" % id)
			return "res://assets/psx-characters/peasant.glb"

func _rig_person(id: String) -> Node3D:
	var g := Node3D.new()
	var bob := Node3D.new()
	bob.name = "Bob"
	g.add_child(bob)
	var packed: PackedScene = load(_npc_mesh(id)) as PackedScene
	if packed == null:
		push_error("Missing PSX mesh for %s" % id)
		g.set_meta("body", bob)
		return g
	var body: Node3D = packed.instantiate() as Node3D
	body.name = "Mesh"
	# Imported in Godot 4.7.2 with an identity basis (root and mesh basis.z are +Z).
	# Rasterizing the painted head puts the face on mesh -Z and the hood on +Z
	# for the peasant, the nun, and the bartender. The shared look-at aims this
	# rig's +Z at the player, which is also how the sprite critters face. A half
	# turn brings the face around onto that axis.
	body.rotation.y = PI
	_psx_character(body)
	bob.add_child(body)
	g.set_meta("body", bob)
	return g

func _arm_hammer(rig: Node3D) -> Node3D:
	var packed: PackedScene = load("res://assets/psx-smith/strike_hammer.glb") as PackedScene
	var hand := Node3D.new()
	hand.name = "Hammer"
	# Rig +Z is her face, aimed at the anvil. The right hand sits on -X.
	hand.position = Vector3(-0.2, 1.02, 0.08)
	var bob: Node3D = rig.get_meta("body")
	bob.add_child(hand)
	if packed == null:
		push_error("Missing strike hammer")
		return hand
	var hammer := packed.instantiate() as Node3D
	hammer.scale = Vector3(1.4, 1.4, 1.4)
	_unshade(hammer, false)
	hand.add_child(hammer)
	return hand

func _psx_character(n: Node) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var src: Material = mi.get_active_material(i)
				var m := StandardMaterial3D.new()
				if src is StandardMaterial3D:
					var painted: StandardMaterial3D = src as StandardMaterial3D
					m.albedo_texture = painted.albedo_texture
					m.albedo_color = painted.albedo_color
				m.roughness = 1.0
				m.metallic = 0.0
				m.metallic_specular = 0.0
				m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				m.normal_enabled = false
				m.rim_enabled = false
				m.clearcoat_enabled = false
				mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_psx_character(c)

func _mesh_top(root: Node) -> float:
	var top := 1.7
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var mi: MeshInstance3D = n as MeshInstance3D
			var world: AABB = mi.global_transform * mi.get_aabb()
			top = maxf(top, world.position.y + world.size.y - root.global_position.y)
		for c in n.get_children():
			stack.append(c)
	return top

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
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.metallic_specular = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(repeat, repeat, 1)
	mi.material_override = mat
	mi.position = pos
	_adopt(mi)
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
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mi.material_override = mat
	mi.position = pos
	_adopt(mi)
	return mi

func _flame_texture() -> Texture2D:
	if _flame_tex != null:
		return _flame_tex
	var w := 8
	var h := 16
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := float(y) / float(h - 1)
		var hot := 1.0 - t * 0.45
		for x in w:
			var edge := absf((float(x) + 0.5) / float(w) - 0.5) * 2.0
			var body := clampf(1.0 - edge, 0.0, 1.0) * (1.0 - t)
			body = body * body
			img.set_pixel(x, y, Color(hot, hot * 0.5, hot * 0.12, body))
	_flame_tex = ImageTexture.create_from_image(img)
	return _flame_tex

func _flame_cards(pos: Vector3, height: float) -> void:
	var tex := _flame_texture()
	for i in 2:
		var q := QuadMesh.new()
		q.size = Vector2(height * 0.72, height)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.position = pos
		mi.rotation.y = float(i) * PI * 0.5
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = tex
		mat.albedo_color = Color(1, 1, 1, 1)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mi.material_override = mat
		_adopt(mi)

func _torch(pos: Vector3, color: Color, energy: float) -> void:
	_unlit_box(Vector3(0.18, 0.05, 0.18), pos + Vector3(0, -0.1, 0), Color(0.14, 0.12, 0.1))
	var flame_h := 0.34 if energy >= 3.0 else 0.22
	_flame_cards(pos + Vector3(0, flame_h * 0.35, 0), flame_h)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.position = pos
	_adopt(light)
	fires.append({ "light": light, "base": energy, "seed": pos.x + pos.z })

func _pool_texture() -> Texture2D:
	if _pool_tex != null:
		return _pool_tex
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var mid := (float(n) - 1.0) * 0.5
	var steps := 5
	for y in n:
		for x in n:
			var dx := (float(x) - mid) / mid
			var dy := (float(y) - mid) / mid
			var d := sqrt(dx * dx + dy * dy)
			var band := 0.0
			if d <= 1.0:
				var q := int(d * float(steps))
				band = 1.0 - float(q) / float(steps)
			img.set_pixel(x, y, Color(1, 1, 1, band))
	_pool_tex = ImageTexture.create_from_image(img)
	return _pool_tex

func _lamp_pool(pos: Vector3, size: float) -> StandardMaterial3D:
	var mesh := PlaneMesh.new()
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _pool_texture()
	var a := 0.07 if is_day else 0.9
	mat.albedo_color = Color(1.0, 0.56, 0.2, a)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.disable_receive_shadows = true
	mi.material_override = mat
	_adopt(mi)
	return mat

func _lantern_cage() -> StandardMaterial3D:
	var glass := _unlit_box(Vector3(0.11, 0.15, 0.11), Vector3(0, -0.02, 0), Color(1.0, 0.78, 0.42))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.78, 0.42)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.58, 0.18)
	glow.emission_energy_multiplier = 2.1
	glow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	glass.material_override = glow
	var iron := Color(0.14, 0.12, 0.11)
	var bars: Array[float] = [-0.1, 0.1]
	for x in bars:
		for z in bars:
			_unlit_box(Vector3(0.02, 0.28, 0.02), Vector3(x, 0.0, z), iron)
	_unlit_box(Vector3(0.24, 0.025, 0.24), Vector3(0, 0.14, 0), iron)
	_unlit_box(Vector3(0.24, 0.025, 0.24), Vector3(0, -0.14, 0), iron)
	_unlit_box(Vector3(0.16, 0.04, 0.16), Vector3(0, 0.18, 0), iron)
	_unlit_box(Vector3(0.07, 0.05, 0.07), Vector3(0, 0.22, 0), iron)
	return glow

func _hang_lamp(energy: float, pool_at: Vector3, pool_size: float) -> void:
	var glow := _lantern_cage()
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.73, 0.4)
	light.light_energy = energy * (0.2 if is_day else 1.0)
	light.omni_range = 7.5
	light.shadow_enabled = false
	_adopt(light)
	var pool := _lamp_pool(pool_at, pool_size)
	var seed_at := Vector3.ZERO
	if _lot_root != null:
		seed_at = _lot_root.global_position
	fires.append({
		"light": light,
		"base": energy,
		"seed": seed_at.x + seed_at.z * 1.7,
		"lamp": true,
		"pool": pool,
		"pool_a": 0.9,
		"glow": glow,
		"glow_base": 2.1,
	})

func _lantern(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	_adopt(pivot)
	var saved := _lot_root
	_lot_root = pivot
	var ground_y := -pos.y
	var post_top := -0.16
	var post_h := post_top - ground_y
	_unlit_box(Vector3(0.28, 0.06, 0.28), Vector3(0, ground_y + 0.03, 0), Color(0.2, 0.14, 0.09))
	_unlit_box(Vector3(0.11, post_h, 0.11), Vector3(0, ground_y + post_h * 0.5, 0), Color(0.32, 0.2, 0.11))
	_hang_lamp(1.8, Vector3(0, 0.05 - pos.y, 0), 5.4)
	_lot_root = saved

func _wall_lantern(pos: Vector3, yaw: float = 0.0) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = yaw
	_adopt(pivot)
	var saved := _lot_root
	_lot_root = pivot
	var iron := Color(0.14, 0.12, 0.11)
	_unlit_box(Vector3(0.035, 0.035, 0.36), Vector3(0, 0.2, -0.14), iron)
	_unlit_box(Vector3(0.025, 0.12, 0.025), Vector3(0, 0.12, 0), iron)
	_hang_lamp(1.45, Vector3(0, 0.05 - pos.y, 0.7), 4.2)
	_lot_root = saved

func _firepit(pos: Vector3, big: bool) -> void:
	var s := 1.15 if big else 0.85
	_box(Vector3(1.1 * s, 0.18, 1.1 * s), pos + Vector3(0, 0.1, 0), Color(0.16, 0.12, 0.08), null, true, 1.0)
	_flame_cards(pos + Vector3(0, 0.28, 0), 0.42 if big else 0.3)
	var flame := OmniLight3D.new()
	flame.light_color = Color(1.0, 0.52, 0.18)
	flame.light_energy = 3.2 if big else 2.3
	flame.omni_range = 10.0
	flame.shadow_enabled = false
	flame.position = pos + Vector3(0, 0.8, 0)
	add_child(flame)
	fires.append({ "light": flame, "base": flame.light_energy, "seed": pos.x * 3.0 })

const _SIGN_FONT := {
	"A": [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
	"B": [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E],
	"C": [0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E],
	"D": [0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E],
	"E": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F],
	"F": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10],
	"G": [0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0E],
	"H": [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
	"I": [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E],
	"J": [0x07, 0x02, 0x02, 0x02, 0x12, 0x12, 0x0C],
	"K": [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11],
	"L": [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F],
	"M": [0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11],
	"N": [0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11],
	"O": [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
	"P": [0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10],
	"Q": [0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D],
	"R": [0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11],
	"S": [0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E],
	"T": [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
	"U": [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
	"V": [0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04],
	"W": [0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x0A],
	"X": [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11],
	"Y": [0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04],
	"Z": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F],
	"0": [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
	"1": [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
	"2": [0x0E, 0x11, 0x01, 0x06, 0x08, 0x10, 0x1F],
	"3": [0x1E, 0x01, 0x01, 0x0E, 0x01, 0x01, 0x1E],
	"4": [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
	"5": [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
	"6": [0x0E, 0x10, 0x10, 0x1E, 0x11, 0x11, 0x0E],
	"7": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
	"8": [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
	"9": [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x01, 0x0E],
	"-": [0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00],
	"'": [0x06, 0x06, 0x02, 0x04, 0x00, 0x00, 0x00],
	".": [0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x06],
}

func _glyph_cols(ch: String) -> int:
	if ch == " ":
		return 2
	if ch == "'" or ch == ".":
		return 3
	return 5

func _sign_lines(text: String) -> PackedStringArray:
	var raw := text.to_upper()
	var out := PackedStringArray()
	if raw.contains("\n"):
		for part in raw.split("\n", false):
			var line := str(part).strip_edges()
			if line != "":
				out.append(line)
		if out.is_empty():
			out.append("?")
		return out
	if raw.length() <= 12:
		out.append(raw)
		return out
	var cut := raw.rfind(" ")
	if cut <= 0:
		out.append(raw)
		return out
	out.append(raw.substr(0, cut).strip_edges())
	out.append(raw.substr(cut + 1).strip_edges())
	return out

func _line_px(line: String, scale: int) -> int:
	var w := 0
	for i in line.length():
		w += _glyph_cols(line.substr(i, 1)) * scale
		if i < line.length() - 1:
			w += scale
	return w

func _paint_px(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, color)

func _paint_sign(text: String) -> Texture2D:
	if _sign_tex.has(text):
		return _sign_tex[text] as Texture2D
	var lines := _sign_lines(text)
	var scale := 2
	var gap := 3 * scale
	var row_h := 7 * scale
	var text_w := 0
	for line in lines:
		text_w = maxi(text_w, _line_px(line, scale))
	var text_h := lines.size() * row_h + (lines.size() - 1) * gap
	var pad := 4 * scale
	var w := text_w + pad * 2 + scale
	var h := text_h + pad * 2 + scale
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(text))
	for py in h:
		for px in w:
			var n := rng.randf_range(-0.02, 0.02)
			var grain := 0.035 if int(py / scale) % 4 == 0 else 0.0
			var wood := Color(0.22 + n + grain, 0.13 + n * 0.5, 0.06, 1)
			if px < 2 or py < 2 or px >= w - 2 or py >= h - 2:
				wood = Color(0.07, 0.04, 0.03, 1)
			img.set_pixel(px, py, wood)
	var ink := Color(0.9, 0.81, 0.62, 1)
	var soot := Color(0.04, 0.025, 0.015, 1)
	var y0 := pad
	for line in lines:
		var x0 := pad + int((text_w - _line_px(line, scale)) / 2.0)
		var cursor := x0
		for i in line.length():
			var ch := line.substr(i, 1)
			var cols := _glyph_cols(ch)
			if ch != " " and _SIGN_FONT.has(ch):
				var rows: Array = _SIGN_FONT[ch]
				for row in rows.size():
					var bits := int(rows[row])
					for bit in cols:
						var on: int = (bits >> (cols - 1 - bit)) & 1
						if on == 0:
							continue
						for sy in scale:
							for sx in scale:
								var gx := cursor + bit * scale + sx
								var gy := y0 + row * scale + sy
								_paint_px(img, gx + scale, gy + scale, soot)
								_paint_px(img, gx, gy, ink)
			elif ch != " ":
				push_error("Sign has no glyph for %s" % ch)
			cursor += cols * scale + scale
		y0 += row_h + gap
	var tex := ImageTexture.create_from_image(img)
	_sign_tex[text] = tex
	return tex

func _sign_pole(x: float, ground_y: float, top_y: float) -> void:
	var h := top_y - ground_y
	var at := Vector3(x, ground_y + h * 0.5, -0.04)
	_unlit_box(Vector3(0.12, h, 0.12), at, Color(0.28, 0.17, 0.1))
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.14, h, 0.14)
	col.shape = sh
	body.position = at
	body.add_child(col)
	_adopt(body)

func _sign(pos: Vector3, text: String, yaw: float = 0.0, post: bool = false, tilt: float = 0.0, span: float = 0.0) -> void:
	var tex := _paint_sign(text)
	var img_size := tex.get_size()
	var ppm := 0.012
	var board_w := float(img_size.x) * ppm
	var board_h := float(img_size.y) * ppm
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = yaw
	_adopt(pivot)
	var saved := _lot_root
	_lot_root = pivot
	var hang := board_h * 0.5
	var beam_y := hang + 0.16
	var iron := Color(0.15, 0.13, 0.12)
	var rope := Color(0.34, 0.26, 0.15)
	if post:
		var ground_y := -pos.y
		if span > 0.2:
			_sign_pole(-span * 0.5, ground_y, beam_y)
			_sign_pole(span * 0.5, ground_y, beam_y)
			_unlit_box(Vector3(span, 0.08, 0.08), Vector3(0, beam_y, -0.02), iron)
		else:
			_sign_pole(0.0, ground_y, beam_y)
			_unlit_box(Vector3(0.05, 0.05, 0.22), Vector3(0, beam_y, 0.04), iron)
	else:
		_unlit_box(Vector3(0.045, 0.045, 0.7), Vector3(0, beam_y, -0.3), iron)
	var chain_x: Array[float] = [-board_w * 0.28, board_w * 0.28]
	for cx in chain_x:
		_unlit_box(Vector3(0.02, 0.14, 0.02), Vector3(cx, hang + 0.05, 0), rope)
	var hinge := Node3D.new()
	hinge.position = Vector3(0, hang, 0)
	hinge.rotation.z = tilt
	_adopt(hinge)
	_lot_root = hinge
	_unlit_box(Vector3(board_w + 0.04, board_h + 0.04, 0.05), Vector3(0, -hang, -0.015), Color(0.16, 0.09, 0.05))
	var quad := QuadMesh.new()
	quad.size = Vector2(board_w, board_h)
	var face := MeshInstance3D.new()
	face.mesh = quad
	face.position = Vector3(0, -hang, 0.02)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	face.material_override = mat
	_adopt(face)
	var back := face.duplicate() as MeshInstance3D
	back.rotation.y = PI
	back.position = Vector3(0, -hang, -0.05)
	var back_mat := mat.duplicate() as StandardMaterial3D
	back_mat.uv1_scale = Vector3(-1, 1, 1)
	back_mat.uv1_offset = Vector3(1, 0, 0)
	back.material_override = back_mat
	_adopt(back)
	_lot_root = saved

func _footprint(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	body.add_child(col)
	_adopt(body)

func _street_pose(pos: Vector3, size: Vector3, face: String, outward: float, along: float, height: float) -> Array:
	var yaw := 0.0
	var p := pos
	if face == "e":
		yaw = PI * 0.5
		p = pos + Vector3(size.x * 0.5 + outward, height, along)
	elif face == "w":
		yaw = -PI * 0.5
		p = pos + Vector3(-size.x * 0.5 - outward, height, along)
	elif face == "s":
		p = pos + Vector3(along, height, size.z * 0.5 + outward)
	else:
		yaw = PI
		p = pos + Vector3(along, height, -size.z * 0.5 - outward)
	return [p, yaw]

func _instance_building(path: String) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("Missing building %s" % path)
		return Node3D.new()
	var n := packed.instantiate() as Node3D
	_unshade(n, false)
	return n

func _drop_model(path: String, pos: Vector3, yaw: float, lot: Vector3, file_min: Vector3, file_max: Vector3, unit: float, fit_height: bool) -> void:
	var src_size := (file_max - file_min) * unit
	if src_size.x < 0.001 or src_size.y < 0.001 or src_size.z < 0.001:
		return
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = yaw
	_adopt(pivot)
	var swap := absf(sin(yaw)) > 0.5
	var span_x := lot.z if swap else lot.x
	var span_z := lot.x if swap else lot.z
	var sx := span_x / src_size.x
	var sz := span_z / src_size.z
	var sy := lot.y / src_size.y if fit_height else (sx + sz) * 0.5 * 0.55
	var mesh := _instance_building(path)
	var sc := Vector3(sx, sy, sz) * unit
	mesh.scale = sc
	var center := (file_min + file_max) * 0.5
	mesh.position = Vector3(-center.x * sc.x, -file_min.y * sc.y, -center.z * sc.z)
	pivot.add_child(mesh)

func _module_house(pos: Vector3, size: Vector3, face: String, shell: String, roof: String, door: String, with_chimney: bool) -> void:
	var root := "res://assets/psx-buildings/"
	_drop_model(root + shell, pos, 0.0, size, Vector3(0, 0, -4), Vector3(4, 3, 0), 1.0, true)
	_drop_model(root + roof, pos + Vector3(0, size.y, 0), 0.0, size, Vector3(0, -0.37, -4.38), Vector3(4, 2.19, 0.38), 1.0, false)
	var door_pose: Array = _street_pose(pos, size, face, 0.12, 0.0, 0.0)
	var door_node := _instance_building(root + door)
	door_node.position = door_pose[0] as Vector3
	door_node.rotation.y = float(door_pose[1])
	_adopt(door_node)
	var win_pose: Array = _street_pose(pos, size, face, 0.14, 1.45, 1.65)
	var win := _instance_building(root + "window_square.glb")
	win.position = win_pose[0] as Vector3
	win.rotation.y = float(win_pose[1])
	_adopt(win)
	if with_chimney:
		var stack := _instance_building(root + "chimney.glb")
		stack.position = pos + Vector3(size.x * 0.22, size.y * 0.55, -size.z * 0.18)
		stack.scale = Vector3(0.42, 0.42, 0.42)
		_adopt(stack)

func _open_workshop(face: String, lot_name: String) -> Dictionary:
	# Daniel Andersson's CC0 blacksmith: closed shop on one side, open forge bay
	# under the roof on the other. glTF +Z is that open side. Yaw it onto the street.
	var model := _instance_building("res://assets/psx-smith/workshop.glb")
	model.rotation.y = -PI * 0.5 if face == "w" else PI * 0.5
	_adopt(model)
	_obstacle(model, Vector3(0.34, 0.0, -2.35), Vector3(3.43, 2.55, 3.50))
	_obstacle(model, Vector3(-3.20, 0.0, 0.62), Vector3(0.28, 1.9, 0.92))
	_obstacle(model, Vector3(-1.176, 0.0, 1.934), Vector3(0.107, 0.51, 3.232))
	_obstacle(model, Vector3(-2.204, 0.0, 2.318), Vector3(-1.072, 0.53, 3.048))
	_obstacle(model, Vector3(-0.17, 0.0, 1.46), Vector3(0.20, 0.54, 1.90))
	_obstacle(model, Vector3(-3.111, 0.0, 0.899), Vector3(-2.437, 1.07, 1.639))
	_obstacle(model, Vector3(-0.935, 0.0, 0.910), Vector3(-0.492, 0.64, 1.350))
	_obstacle(model, Vector3(-0.433, 0.0, 0.920), Vector3(0.008, 0.64, 1.362))
	_obstacle(model, Vector3(-2.334, 0.0, 0.785), Vector3(-1.140, 0.76, 1.379))
	var saved := _lot_root
	_lot_root = model
	_torch(Vector3(-0.54, 0.58, 2.55), Color(1.0, 0.42, 0.12), 3.4)
	_sign(Vector3(-1.55, 1.08, 3.42), lot_name)
	_wall_lantern(Vector3(-2.35, 1.48, 3.15))
	_lot_root = saved
	var marta_model := Vector3(-0.562, 0.0, 1.661)
	var anvil_model := Vector3(0.036, 0.42, 1.672)
	var marta_world: Vector3 = model.global_transform * marta_model
	var anvil_world: Vector3 = model.global_transform * anvil_model
	var toward := anvil_world - marta_world
	var solid := _lot_span(model, Vector3(0.34, 0.0, -2.35), Vector3(3.43, 0.0, 3.50))
	return {
		"smith_pos": marta_world,
		"smith_yaw": atan2(toward.x, toward.z),
		"solid": solid,
	}

func _lot_span(model: Node3D, a: Vector3, b: Vector3) -> Array:
	var min_x := 1.0e9
	var max_x := -1.0e9
	var min_z := 1.0e9
	var max_z := -1.0e9
	var parent := model.get_parent() as Node3D
	var xs: Array[float] = [a.x, b.x]
	var zs: Array[float] = [a.z, b.z]
	for x in xs:
		for z in zs:
			var world: Vector3 = model.global_transform * Vector3(x, 0.0, z)
			var local := world - parent.global_position
			var yaw: float = parent.global_rotation.y
			var c := cos(yaw)
			var s := sin(yaw)
			var lx := c * local.x - s * local.z
			var lz := s * local.x + c * local.z
			min_x = minf(min_x, lx)
			max_x = maxf(max_x, lx)
			min_z = minf(min_z, lz)
			max_z = maxf(max_z, lz)
	return [min_x, max_x, min_z, max_z]

func _obstacle(host: Node3D, box_min: Vector3, box_max: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box_max - box_min
	col.shape = sh
	body.position = (box_min + box_max) * 0.5
	body.add_child(col)
	host.add_child(body)

func _house(pos: Vector3, size: Vector3, name: String, _stone: bool, face: String, kind: String = "", street_yaw: float = 0.0) -> void:
	# Local +X is the walker's right once street_yaw aims local -Z down the road.
	# Face "e" therefore looks at the street from the left bank, "w" from the right.
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = street_yaw
	add_child(pivot)
	_lot_root = pivot
	var at := Vector3.ZERO
	var smith_extra: Dictionary = {}
	if kind != "smith":
		_footprint(size, at)
	var front := 1.0 if face == "e" or face == "s" else -1.0
	# Church door looks along file +Z. Tavern's long front looks along file -Z
	# (the volume sits on +Z of that wall). Both end up yawed ±90° onto the street.
	if kind == "chapel":
		# File +Z is the apse end. The door and steps sit on file -Z, so that
		# axis is the street front. Checked from the cobbles in 4.7.2.
		var model_front := -1.0
		var yaw := PI * 0.5 if front / model_front > 0.0 else -PI * 0.5
		_drop_model("res://assets/psx-buildings/church.glb", at, yaw, size, Vector3(-449.3, -1.5, -1060.7), Vector3(449.3, 1018.3, 372.2), 0.01, true)
	elif kind == "inn":
		# The tavern's long front (door and windows) looks along file +Z.
		var model_front := 1.0
		var yaw := PI * 0.5 if front / model_front > 0.0 else -PI * 0.5
		_drop_model("res://assets/psx-buildings/tavern.glb", at, yaw, size, Vector3(-819.8, 0.07, -28.1), Vector3(919.4, 482.2, 475.0), 0.01, true)
	elif kind == "smith":
		smith_extra = _open_workshop(face, name)
	elif kind == "hostel":
		_module_house(at, size, face, "shell_base.glb", "roof_red.glb", "door_wood.glb", true)
	elif kind == "stables":
		_module_house(at, size, face, "shell_base.glb", "roof_straw.glb", "door_wood.glb", false)
	elif kind == "shop":
		var roof := "roof_blue.glb" if pos.z > 8.0 else "roof_red.glb"
		_module_house(at, size, face, "shell_plaster.glb", roof, "door_wood.glb", false)
	else:
		_module_house(at, size, face, "shell_plaster.glb", "roof_straw.glb", "door_wood.glb", false)
	var fx := at.x
	var fz := at.z
	if face == "e":
		fx = at.x + size.x * 0.5
	elif face == "w":
		fx = at.x - size.x * 0.5
	elif face == "s":
		fz = at.z + size.z * 0.5
	else:
		fz = at.z - size.z * 0.5
	if kind != "smith":
		var along_sign := -1.45
		var along_lamp := 0.85
		var out := 0.55
		var lamp_out := 0.36
		var sign_yaw := 0.0
		var sign_at := Vector3.ZERO
		var lamp_at := Vector3.ZERO
		if face == "e":
			sign_yaw = PI * 0.5
			sign_at = Vector3(fx + out, 2.4, along_sign)
			lamp_at = Vector3(fx + lamp_out, 2.05, along_lamp)
		elif face == "w":
			sign_yaw = -PI * 0.5
			sign_at = Vector3(fx - out, 2.4, along_sign)
			lamp_at = Vector3(fx - lamp_out, 2.05, along_lamp)
		elif face == "s":
			sign_yaw = 0.0
			sign_at = Vector3(along_sign, 2.4, fz + out)
			lamp_at = Vector3(along_lamp, 2.05, fz + lamp_out)
		else:
			sign_yaw = PI
			sign_at = Vector3(along_sign, 2.4, fz - out)
			lamp_at = Vector3(along_lamp, 2.05, fz - lamp_out)
		_sign(sign_at, name, sign_yaw)
		_wall_lantern(lamp_at, sign_yaw)
	_lot_root = null
	var lot := {
		"pos": pos,
		"size": size,
		"yaw": street_yaw,
		"face": face,
		"kind": kind,
		"name": name,
	}
	for key in smith_extra.keys():
		lot[key] = smith_extra[key]
	_lots.append(lot)

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
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
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
	_tint_ground()

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
	blurb.text = "The cinematic opens later. After it, you wake in the mud.\nThe cobbles run an S through Harth to the king's gate. A marsh fairy has four ways in."
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
		var scale := 1.0
		if bool(f.get("lamp", false)) and is_day:
			scale = 0.2
		f["light"].light_energy = float(f["base"]) * flick * scale
		if f.get("pool") != null:
			var pool_mat: StandardMaterial3D = f["pool"]
			var a := float(f["pool_a"]) * flick
			if bool(f.get("lamp", false)) and is_day:
				a *= 0.08
			var tint := pool_mat.albedo_color
			tint.a = a
			pool_mat.albedo_color = tint
		if f.get("glow") != null:
			var glow_mat: StandardMaterial3D = f["glow"]
			glow_mat.emission_energy_multiplier = float(f["glow_base"]) * flick

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
		var freeze: bool = (hob_node != "" and str(n["id"]) == "hob") or (dog_node != "" and str(n["id"]) == "bramble") or (n.get("kind", "") == "hound" and float(n.get("sit", 0.0)) > 0.0)
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
		var moving: bool = (not freeze) and d.length() > 0.2
		if bool(n.get("station", false)):
			n["node"].global_position = home
			n["node"].rotation.y = float(n["work_yaw"])
			var hand: Node3D = n.get("hammer") as Node3D
			if hand != null:
				var phase := fposmod(fairy_t * 1.25, 1.0)
				var swing := -0.2
				if phase < 0.62:
					swing = lerpf(-0.2, -1.45, phase / 0.62)
				elif phase < 0.78:
					swing = lerpf(-1.45, 0.95, (phase - 0.62) / 0.16)
				else:
					swing = lerpf(0.95, -0.2, (phase - 0.78) / 0.22)
				hand.rotation.x = swing
				if n.get("body"):
					var smith_body: Node3D = n["body"]
					smith_body.position.y = float(n.get("body_y", 0.0))
					var strike := clampf((swing + 1.45) / 2.4, 0.0, 1.0)
					smith_body.rotation.x = lerpf(0.0, 0.22, strike)
					smith_body.rotation.z = 0.0
			continue
		if moving:
			var sp := 3.0 if n.get("kind", "") == "critter" else (0.7 if n.get("kind", "") == "hound" else 1.2)
			n["node"].global_position = pos + d.normalized() * sp * delta
		if n.get("kind", "") == "hound":
			var sitting: bool = freeze or float(n.get("sit", 0.0)) > 0.0
			if n.get("sitSpr"):
				n["sitSpr"].visible = sitting
			if n.get("walkSpr"):
				n["walkSpr"].visible = not sitting
		# Rig +Z is the face: character meshes are turned 180° inside the rig, and
		# sprites already face +Z. atan2(x, z) aims that axis at the player.
		# look_at() would aim -Z and show every back.
		var to_cam: Vector3 = player.global_position - n["node"].global_position
		if to_cam.length_squared() > 0.0001:
			n["node"].rotation.y = atan2(to_cam.x, to_cam.z)
		var t := fairy_t * (9.0 if moving else 2.4) + home.x
		if n.get("body"):
			var body: Node3D = n["body"]
			var base_y: float = float(n.get("body_y", 0.0))
			body.position.y = base_y + sin(t) * (0.045 if moving else 0.012)
			body.rotation.z = sin(t * 0.5) * (0.05 if moving else 0.018)

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
			"line": "Marta keeps the fist. She'll shoe a horse or a grievance, and she bills both. Pell keeps a key she shouldn't. Ralf is already Cousin-of-a-Baron, drunk. Me? I hate the paperwork. The king is a very tall form.",
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
			"line": "He smells the ditch on you. Then the forge. Then pity. No wife in that nose. Only coal, and a rat he has already forgiven.",
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