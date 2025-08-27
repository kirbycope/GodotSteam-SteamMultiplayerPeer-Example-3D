extends MultiplayerSpawner

var players = {}

@export var player_scene: PackedScene


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Define custom spawner
	spawn_function = spawn_player
	# Check if local system is the multiplayer authority (host)
	if is_multiplayer_authority():
		# Spawn the host player (ID = 1)
		spawn(1)
		# Connect "peer_connected" event to `spawn()`
		multiplayer.peer_connected.connect(spawn)
		# Connect "peer_disconnected" event to `remove_player()`
		multiplayer.peer_disconnected.connect(remove_player)


## Creates a new player in the scene.
func spawn_player(data):
	print("data: ", data)
	# Instantiate a new player
	var player = player_scene.instantiate()
	# Set the node's multiplayer authority to the given peer
	player.set_multiplayer_authority(data)
	# Set player's initial transform
	#player.position = Vector3(-30.25, 5.8, 47.5)
	#player.rotation = Vector3(0.0, 45.0, 0.0)
	#player.velocity = Vector3.ZERO
	# Store the player data
	players[data] = player
	# Return the player
	return player


## Removes a player from the scene.
func remove_player(data):
	# Remove the player from the scene
	players[data].queue_free()
	# Remove the player data
	players.erase(data)
