extends MultiplayerSpawner

var players = {}

@export var player_scene: PackedScene


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Define custom spawner
	spawn_function = spawn_player
	# Debug and setup
	print("[MultiplayerSpawner] _ready - is_multiplayer_authority: %s" % is_multiplayer_authority())
	# Check if local system is the multiplayer authority (host)
	if is_multiplayer_authority():
		# Spawn the host player (ID = 1)
		print("[MultiplayerSpawner] Spawning host player (1)")
		spawn(1)
		# Connect peer connect/disconnect signals to our handlers
		multiplayer.peer_connected.connect(Callable(self, "_on_peer_connected"))
		multiplayer.peer_disconnected.connect(Callable(self, "_on_peer_disconnected"))

	# If this spawner is created on a client, we still want to be able to
	# respond to peer disconnections (host might disconnect later).
	if not is_multiplayer_authority():
		print("[MultiplayerSpawner] Running on client")
		multiplayer.peer_disconnected.connect(Callable(self, "_on_peer_disconnected"))


## Creates a new player in the scene.
func spawn_player(data):
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


## Called when another peer connects (host-only)
func _on_peer_connected(id: int) -> void:
	print("[MultiplayerSpawner] peer_connected: %s" % id)
	# Spawn the player for the connected peer
	spawn(id)


## Called when a peer disconnects
func _on_peer_disconnected(id: int) -> void:
	print("[MultiplayerSpawner] peer_disconnected: %s" % id)
	remove_player(id)


## Removes a player from the scene.
func remove_player(data):
	# Safely remove the player from the scene
	if players.has(data):
		players[data].queue_free()
		players.erase(data)
	else:
		print("[MultiplayerSpawner] remove_player: no player for id %s" % data)
