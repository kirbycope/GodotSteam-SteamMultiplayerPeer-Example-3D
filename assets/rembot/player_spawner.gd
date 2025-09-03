## CREATED BY REMBOT GAMES
extends MultiplayerSpawner

@export var player_scene:PackedScene

var players = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawn_function = spawn_player
	if is_multiplayer_authority():
		multiplayer.peer_connected.connect(spawn)
		multiplayer.peer_disconnected.connect(remove_player)
		#call_deferred("spawn_host")

func spawn_host():
	# spawn host (defer me)
	if is_multiplayer_authority():
		spawn(1)

func spawn_player(data):
	var p = player_scene.instantiate()
	p.set_multiplayer_authority(data)
	players[data] = p
	return p

func remove_player(data):
	players[data].queue_free()
	players.erase(data)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
