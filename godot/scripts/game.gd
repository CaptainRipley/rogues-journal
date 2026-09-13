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
	nix_tex = load("res://assets/nix.png")
	mud_tex = load("res://assets/mud.png")
	stone_tex = load("res://assets/stone.png")
	_build_world()
	_build_player()
	_build_ditch()
	_build_hud()
	_set_phase_title()
	camera.current = true
