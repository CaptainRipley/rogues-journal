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

func _ready() -> void:
	DisplayServer.window_set_title("RJ-READY")
	nix_tex = load("res://assets/nix.png")
	mud_tex = load("res://assets/mud.png")
	stone_tex = load("res://assets/stone.png")
	_build_world()
	_build_player()
	_build_ditch()
	_build_hud()
	_set_phase_title()
	camera.current = true

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.045, 0.05, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.68)
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.09, 0.07, 0.06)
	env.fog_density = 0.018
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.77, 0.82, 0.88)
	sun.light_energy = 0.7
	sun.rotation_degrees = Vector3(-50, 40, 0)
	add_child(sun)

	_box(Vector3(160, 1, 160), Vector3(0, -0.5, 0), Color(0.72, 0.66, 0.52), mud_tex, true, 24.0)
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(200, 2, 200)
	floor_col.shape = floor_shape
	floor_body.position.y = -1
	floor_body.add_child(floor_col)
	add_child(floor_body)
	_box(Vector3(6, 0.06, 44), Vector3(0, 0.03, 8), Color(0.35, 0.28, 0.2), mud_tex, false, 8.0)
	_box(Vector3(14, 6, 10), Vector3(16, 3, 6), Color(0.42, 0.28, 0.18), null, true, 2.0)
	_box(Vector3(6, 0.4, 8), Vector3(16, 6.2, 6), Color(0.22, 0.14, 0.1), null, true, 1.0)
	_box(Vector3(1.6, 2.6, 0.3), Vector3(10.9, 1.3, 6), Color(0.1, 0.07, 0.06), null, false, 1.0)
	_box(Vector3(70, 12, 3), Vector3(0, 6, -22), Color(1, 1, 1), stone_tex, true, 3.0)
	_box(Vector3(8, 16, 4), Vector3(-22, 8, -22), Color(1, 1, 1), stone_tex, true, 2.0)
	_box(Vector3(8, 16, 4), Vector3(22, 8, -22), Color(1, 1, 1), stone_tex, true, 2.0)
	_box(Vector3(5, 8, 1.2), Vector3(0, 4, -20.4), Color(0.1, 0.09, 0.07), null, true, 1.0)
	_torch(Vector3(10.6, 2.6, 4.2), Color(0.83, 0.54, 0.23), 2.6)
	_torch(Vector3(10.6, 2.6, 7.8), Color(0.83, 0.54, 0.23), 2.6)
	_torch(Vector3(-6, 4.5, -20), Color(0.83, 0.54, 0.23), 3.0)
	_torch(Vector3(6, 4.5, -20), Color(0.83, 0.54, 0.23), 3.0)

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
	_torch(Vector3(-2.2, 2.1, 27.4), Color(0.83, 0.54, 0.23), 3.2)
	_torch(Vector3(2.8, 1.9, 26.2), Color(0.72, 0.82, 0.5), 2.4)
	_torch(Vector3(0.2, 2.4, 24.8), Color(0.77, 0.64, 0.35), 2.2)
	_torch(Vector3(0, 2.8, 29.2), Color(0.83, 0.54, 0.23), 2.0)

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
	glow.light_energy = 5.0
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

func _make_sword() -> Node3D:
	var g := Node3D.new()
	var loaded = load("res://assets/models/Sword.obj")
	if loaded is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = loaded
		g.add_child(mi)
		g.scale = Vector3(0.55, 0.55, 0.55)
		g.rotation_degrees = Vector3(12, 35, 18)
	else:
		var blade := BoxMesh.new()
		blade.size = Vector3(0.06, 1.15, 0.04)
		g.add_child(_mesh_part(blade, _mat(Color(0.72, 0.76, 0.8), 0.28, 0.75), Vector3(0, 0.7, 0)))
		var guard := BoxMesh.new()
		guard.size = Vector3(0.32, 0.05, 0.08)
		g.add_child(_mesh_part(guard, _mat(Color(0.55, 0.42, 0.2), 0.4, 0.5), Vector3(0, 0.16, 0)))
		var hilt := BoxMesh.new()
		hilt.size = Vector3(0.07, 0.22, 0.07)
		g.add_child(_mesh_part(hilt, _mat(Color(0.22, 0.14, 0.08), 0.85), Vector3(0, 0.02, 0)))
	_tag(g, "Sword", 1.35)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.7, 0.75, 0.82)
	glow.light_energy = 1.4
	glow.omni_range = 5.0
	g.add_child(glow)
	return g

func _make_lute() -> Node3D:
	var g := Node3D.new()
	var bowl := SphereMesh.new()
	bowl.radius = 0.2
	bowl.height = 0.28
	g.add_child(_mesh_part(bowl, _mat(Color(0.48, 0.28, 0.12), 0.55, 0.08), Vector3.ZERO, Vector3.ZERO, Vector3(1.2, 0.55, 1.05)))
	var hole := CylinderMesh.new()
	hole.top_radius = 0.055
	hole.bottom_radius = 0.055
	hole.height = 0.02
	g.add_child(_mesh_part(hole, _mat(Color(0.08, 0.05, 0.03)), Vector3(0, 0.08, 0.02), Vector3(90, 0, 0)))
	var neck := BoxMesh.new()
	neck.size = Vector3(0.055, 0.05, 0.62)
	g.add_child(_mesh_part(neck, _mat(Color(0.28, 0.16, 0.07), 0.8), Vector3(0, 0.04, -0.46)))
	var head := BoxMesh.new()
	head.size = Vector3(0.1, 0.04, 0.14)
	g.add_child(_mesh_part(head, _mat(Color(0.22, 0.12, 0.05)), Vector3(0, 0.06, -0.8)))
	for i in 4:
		var peg := SphereMesh.new()
		peg.radius = 0.018
		peg.height = 0.036
		g.add_child(_mesh_part(peg, _mat(Color(0.7, 0.62, 0.4), 0.4, 0.3), Vector3(-0.03 + i * 0.02, 0.09, -0.78)))
		var string := CylinderMesh.new()
		string.top_radius = 0.004
		string.bottom_radius = 0.004
		string.height = 0.72
		g.add_child(_mesh_part(string, _mat(Color(0.85, 0.8, 0.65)), Vector3(-0.03 + i * 0.02, 0.09, -0.38), Vector3(90, 0, 0)))
	g.rotation_degrees = Vector3(-8, 40, 12)
	_tag(g, "Lute", 0.7)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.77, 0.64, 0.35)
	glow.light_energy = 1.3
	glow.omni_range = 5.0
	g.add_child(glow)
	return g

func _make_book() -> Node3D:
	var g := Node3D.new()
	var cover := BoxMesh.new()
	cover.size = Vector3(0.34, 0.06, 0.46)
	g.add_child(_mesh_part(cover, _mat(Color(0.28, 0.08, 0.1), 0.7, 0.05, Color(0.45, 0.12, 0.05, 1)), Vector3(0, 0.03, 0)))
	var pages := BoxMesh.new()
	pages.size = Vector3(0.3, 0.045, 0.42)
	g.add_child(_mesh_part(pages, _mat(Color(0.85, 0.78, 0.62), 0.95), Vector3(0.01, 0.05, 0)))
	var spine := BoxMesh.new()
	spine.size = Vector3(0.05, 0.08, 0.46)
	g.add_child(_mesh_part(spine, _mat(Color(0.18, 0.06, 0.07), 0.65, 0.1), Vector3(-0.16, 0.04, 0)))
	var clasp := BoxMesh.new()
	clasp.size = Vector3(0.06, 0.02, 0.08)
	g.add_child(_mesh_part(clasp, _mat(Color(0.72, 0.58, 0.28), 0.35, 0.7), Vector3(0.16, 0.08, 0)))
	g.rotation_degrees = Vector3(0, -28, 0)
	_tag(g, "Spellbook", 0.55)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.83, 0.4, 0.18)
	glow.light_energy = 1.8
	glow.omni_range = 5.5
	g.add_child(glow)
	return g

func _add_gift_node(id: String, node: Node3D, pos: Vector3, hint: String) -> void:
	node.position = pos
	add_child(node)
	gifts.append({ "id": id, "node": node, "hint": hint })

func _build_npcs() -> void:
	_add_npc("hob", "Hob", Color(0.29, 0.23, 0.16), Vector3(1.8, 0, 3.4), 0.4, false, [
		"Road tax. Feast night. Double, unless you're expected.",
		"If anyone asks, you were a priest. I'm a businessman.",
	])
	_add_npc("marta", "Marta", Color(0.42, 0.16, 0.16), Vector3(11.6, 0, 6.2), -1.2, false, [
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
	_add_npc("pell", "Sister Pell", Color(0.16, 0.16, 0.22), Vector3(-12, 0, 8), 1.1, false, [
		"I keep a key because I do not trust doors that belong to kings.",
		"Mara Venn has a spine. Try not to rescue her like furniture.",
	])
	_add_npc("ralf", "Drunk Ralf", Color(0.29, 0.29, 0.16), Vector3(18.5, 0, 12), 2.0, false, [
		"I am Cousin Ralf of the eastern orchards. Ask anyone. Don't.",
		"If you need a name at the gate, mine is already ruined. Be my guest.",
	])

func _add_npc(id: String, npc_name: String, tunic: Color, pos: Vector3, rot: float, guard: bool, lines: Array) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot
	var skin := _mat(Color(0.76, 0.58, 0.42), 0.9)
	var cloth := _mat(tunic, 0.92)
	var dark := _mat(Color(0.16, 0.13, 0.09), 0.95)
	var torso := BoxMesh.new()
	torso.size = Vector3(0.48, 0.72, 0.28)
	g.add_child(_mesh_part(torso, cloth, Vector3(0, 1.05, 0)))
	var hips := BoxMesh.new()
	hips.size = Vector3(0.44, 0.22, 0.26)
	g.add_child(_mesh_part(hips, dark, Vector3(0, 0.62, 0)))
	var leg := BoxMesh.new()
	leg.size = Vector3(0.16, 0.55, 0.16)
	g.add_child(_mesh_part(leg, dark, Vector3(-0.12, 0.28, 0)))
	g.add_child(_mesh_part(leg, dark, Vector3(0.12, 0.28, 0)))
	var arm := BoxMesh.new()
	arm.size = Vector3(0.12, 0.55, 0.12)
	g.add_child(_mesh_part(arm, cloth, Vector3(-0.32, 1.0, 0)))
	g.add_child(_mesh_part(arm, cloth, Vector3(0.32, 1.0, 0)))
	var head := BoxMesh.new()
	head.size = Vector3(0.26, 0.3, 0.24)
	g.add_child(_mesh_part(head, skin, Vector3(0, 1.55, 0)))
	if guard:
		var helm := BoxMesh.new()
		helm.size = Vector3(0.3, 0.16, 0.3)
		g.add_child(_mesh_part(helm, _mat(Color(0.35, 0.38, 0.42), 0.4, 0.6), Vector3(0, 1.74, 0)))
		var spear := CylinderMesh.new()
		spear.top_radius = 0.02
		spear.bottom_radius = 0.025
		spear.height = 1.8
		g.add_child(_mesh_part(spear, _mat(Color(0.4, 0.3, 0.18)), Vector3(0.38, 1.1, 0.05)))
	if id == "pell":
		var veil := BoxMesh.new()
		veil.size = Vector3(0.32, 0.28, 0.08)
		g.add_child(_mesh_part(veil, _mat(Color(0.1, 0.1, 0.14)), Vector3(0, 1.58, -0.12)))
	if id == "ralf":
		var jug := CylinderMesh.new()
		jug.top_radius = 0.05
		jug.bottom_radius = 0.06
		jug.height = 0.18
		g.add_child(_mesh_part(jug, _mat(Color(0.29, 0.22, 0.13)), Vector3(0.28, 0.95, 0.12)))
	if id == "hob":
		var bag := BoxMesh.new()
		bag.size = Vector3(0.18, 0.16, 0.1)
		g.add_child(_mesh_part(bag, _mat(Color(0.22, 0.16, 0.09)), Vector3(0.3, 0.9, 0)))
	_tag(g, npc_name, 2.05)
	add_child(g)
	npcs.append({ "id": id, "name": npc_name, "node": g, "lines": lines, "purse": 4, "picked": false, "i": 0 })

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

func _torch(pos: Vector3, color: Color, energy: float) -> void:
	var stick := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.7, 0.08)
	stick.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.12, 0.08)
	stick.material_override = mat
	stick.position = pos
	add_child(stick)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 10.0
	light.position = Vector3(0, 0.45, 0)
	stick.add_child(light)

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
	wake_btn.text = "Wake in the mud"
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
	_refresh_hud()

func _ink(label: Label, size: int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.91, 0.84, 0.72))

func _set_phase_title() -> void:
	phase = Phase.TITLE
	title_box.visible = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_wake() -> void:
	phase = Phase.WAKE
	wake_t = 0.0
	title_box.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	log_line = "Mud in your teeth. A light that does not belong to Harth."
	_refresh_hud()

func _input(event: InputEvent) -> void:
	if phase == Phase.TITLE:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * look_sens
		pitch -= event.relative.y * look_sens
		pitch = clampf(pitch, -1.35, 1.35)
		_apply_look()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if event.physical_keycode == KEY_E:
			_interact()
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
	if phase == Phase.TITLE:
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
	if spell_cd > 0.0:
		spell_cd -= delta
	_bob_fairy(delta)
	_update_prompt()
	_refresh_hud()

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
	sword_view = _make_sword()
	for c in sword_view.get_children():
		if c is Label3D or c is OmniLight3D:
			c.queue_free()
	sword_view.position = Vector3(0.38, -0.28, -0.55)
	sword_view.rotation_degrees = Vector3(12, 18, -28)
	sword_view.scale = Vector3(0.35, 0.35, 0.35)
	sword_view.visible = false
	camera.add_child(sword_view)
	lute_view = _make_lute()
	for c in lute_view.get_children():
		if c is Label3D or c is OmniLight3D:
			c.queue_free()
	lute_view.position = Vector3(0.32, -0.28, -0.5)
	lute_view.scale = Vector3(0.55, 0.55, 0.55)
	lute_view.visible = false
	camera.add_child(lute_view)
	book_view = _make_book()
	for c in book_view.get_children():
		if c is Label3D or c is OmniLight3D:
			c.queue_free()
	book_view.position = Vector3(0.28, -0.22, -0.48)
	book_view.scale = Vector3(0.7, 0.7, 0.7)
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
	swinging = 0.28
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
	talk_label.text = ("Nix\n" + fairy_talk) if fairy_talk != "" and not fairy_gone else log_line