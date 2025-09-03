extends Node3D

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner


func _ready() -> void:
	# Connect signals
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	# Define custom spawner
	spawner.spawn_function = spawn_level
	# Check for command line arguments
	check_command_line()
	# Populate the lobby list
	_on_open_lobby_list_pressed()


## Called every frame. '_delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Check if multiplayer peer is disconnected (client side)
	var current_peer = multiplayer.get_multiplayer_peer()
	if current_peer != null:
		# Check if the owner is still connected
		if $SteamLobby.lobby_id > 0 and not multiplayer.is_server():
			var owner_id = Steam.getLobbyOwner($SteamLobby.lobby_id)
			if owner_id != Steam.getSteamID():  # We're not the owner
				# Check if we're actually disconnected (not just connecting)
				var peer_state = current_peer.get_connection_status()
				if peer_state == MultiplayerPeer.CONNECTION_DISCONNECTED:
					print("Multiplayer peer is no longer active. Disconnecting gracefully...")
					# Leave the lobby on Steam
					$SteamLobby.leave_lobby()
					# Clean up multiplayer peer
					multiplayer.set_multiplayer_peer(null)
					# Show lobby UI again
					if $GUI:
						$GUI.show()
					# Reset lobby info
					$SteamLobby.lobby_id = 0
					$SteamLobby.lobby_members.clear()
					$SteamLobby.pending_owner_id = 0


## Connected to the Signal: $CreateLobby.pressed()
func _on_create_lobby_pressed() -> void:
	if $SteamLobby.lobby_id == 0:
		$SteamLobby.create_lobby()


## Connected to the Signal: $GetLobbyLists.pressed()
func _on_open_lobby_list_pressed() -> void:
	$SteamLobby.update_lobby_list()


# https://godotsteam.com/tutorials/lobbies/#get-lobby-lists
func _on_lobby_match_list(lobbies: Array) -> void:
	for child in $"GUI/LobbyContainer/Lobbies".get_children():
		child.queue_free()
	for lobby in lobbies:
		# Pull lobby data from Steam, these are specific to our example
		var lobby_name: String = Steam.getLobbyData(lobby, "name")
		var lobby_mode: String = Steam.getLobbyData(lobby, "mode")
		# Get the current number of members
		var lobby_num_members: int = Steam.getNumLobbyMembers(lobby)
		# Create a button for the lobby
		var lobby_button: Button = Button.new()
		lobby_button.set_text("Lobby %s: %s [%s] - %s Player(s)" % [lobby, lobby_name, lobby_mode, lobby_num_members])
		lobby_button.set_size(Vector2(800, 50))
		lobby_button.set_name("lobby_%s" % lobby)
		lobby_button.connect("pressed", Callable(self, "join_lobby").bind(lobby))
		# Add the new lobby to the list
		$"GUI/LobbyContainer/Lobbies".add_child(lobby_button)
	print("└── Lobby list updated.")


# https://godotsteam.com/tutorials/lobbies/#the-_ready-function
func check_command_line() -> void:
	var these_arguments: Array = OS.get_cmdline_args()
	# There are arguments to process
	if these_arguments.size() > 0:
		# A Steam connection argument exists
		if these_arguments[0] == "+connect_lobby":
			# Lobby invite exists so try to connect to it
			if int(these_arguments[1]) > 0:
				# At this point, you'll probably want to change scenes
				# Something like a loading into lobby screen
				print("Command line lobby ID: %s" % these_arguments[1])
				join_lobby(int(these_arguments[1]))


# https://godotsteam.com/tutorials/lobbies/#joining-lobbies
func join_lobby(this_lobby_id: int) -> void:
	print("Joining lobby ", this_lobby_id, "...")
	# Clear any previous lobby members lists, if you were in a previous lobby
	$SteamLobby.lobby_members.clear()
	# Make the lobby join request to Steam
	Steam.joinLobby(this_lobby_id)
	# Hide the Lobby GUI
	$"GUI".hide()


# https://youtu.be/fUBdnocrc3Y?t=322
func spawn_level(data):
	# Instantiate and then return the loaded scene
	return (load(data) as PackedScene).instantiate()
