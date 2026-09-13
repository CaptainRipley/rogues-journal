extends Node3D

enum Phase { TITLE, WAKE, GIFT, PLAY }
enum PathId { NONE, STEEL, SONG, SPARK, FEATHER }

const SPEED := 5.4
const JUMP_V := 6.2
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
	env.background_color = Color(0.55, 0.18, 0.12)
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
	add_child(fairy)

	_add_gift("steel", Vector3(-1.7, 0.55, 25.4), Color(0.72, 0.75, 0.78), Vector3(0.08, 1.2, 0.06), "E — take the sword. Fight the party.")
	_add_gift("song", Vector3(0.05, 0.28, 24.6), Color(0.54, 0.38, 0.19), Vector3(0.42, 0.22, 0.7), "E — take the lute. Get invited.")
	_add_gift("spark", Vector3(1.75, 0.18, 25.5), Color(0.22, 0.12, 0.16), Vector3(0.32, 0.1, 0.42), "E — take the spellbook. Blast the party.")

func _add_gift(id: String, pos: Vector3, color: Color, size: Vector3, hint: String) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	if id == "spark":
		mat.emission_enabled = true
		mat.emission = Color(0.7, 0.3, 0.1)
		mat.emission_energy_multiplier = 1.4
	mi.material_override = mat
	mi.position = pos
	if id == "steel":
		mi.rotation_degrees = Vector3(18, 20, 24)
	add_child(mi)
	var light := OmniLight3D.new()
	light.light_energy = 1.4
	light.omni_range = 5.0
	light.light_color = color.lightened(0.3)
	mi.add_child(light)
	gifts.append({ "id": id, "node": mi, "hint": hint })

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

func _update_prompt() -> void:
	if path == PathId.NONE:
		var g := _nearest_gift()
		if not g.is_empty():
			prompt = g["hint"]
		elif _near_fairy():
			prompt = "E talk with Nix   ·   F pickpocket her for Feather Hands"
		else:
			prompt = "Sword · lute · spellbook in the mud. Or her pockets."
	else:
		prompt = "WASD move  ·  mouse look  ·  click swing  ·  R cast  ·  F pocket"

func _interact() -> void:
	if path == PathId.NONE:
		var g := _nearest_gift()
		if not g.is_empty():
			_take(g["id"])
			return
		if _near_fairy():
			fairy_talk = "Steel, song, or spark. Pick a gift. Or pick a pocket — I am not your mother."
			return
	fairy_talk = ""

func _take(id: String) -> void:
	match id:
		"steel":
			path = PathId.STEEL
			fairy_talk = "Try not to die in the first sentence."
			log_line = "The sword is wet. It does not mind."
		"song":
			path = PathId.SONG
			fairy_talk = "Smile when you lie. It's cheaper than a seal."
			log_line = "The lute smells like someone else's feast."
		"spark":
			path = PathId.SPARK
			fairy_talk = "The book bites. Point it at problems."
			log_line = "The pages are already warm."
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
		coin += 1
		log_line = "A purse that was not watching you."

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