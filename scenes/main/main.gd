extends Node3D

# https://godotsteam.com/tutorials/lobbies/#set-up
const PACKET_READ_LIMIT: int = 32
var lobby_data
var lobby_id: int = 0
var lobby_members: Array = []
var lobby_members_max: int = 10
var lobby_vote_kick: bool = false
var steam_id: int = 0
var steam_username: String = ""

# https://michaelmacha.wordpress.com/2024/04/08/godotsteam-and-steammultiplayerpeer/
var peer: MultiplayerPeer
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner


# https://godotsteam.com/tutorials/lobbies/#the-_ready-function
func _ready() -> void:
	Steam.join_requested.connect(_on_lobby_join_requested)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_created.connect(_on_lobby_created)
	#Steam.lobby_data_update.connect(_on_lobby_data_update)
	#Steam.lobby_invite.connect(_on_lobby_invite)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	#Steam.lobby_message.connect(_on_lobby_message)
	Steam.persona_state_change.connect(_on_persona_change)
	# Check for command line arguments
	check_command_line()
	# Define custom spawner
	spawner.spawn_function = spawn_level
	# Get a list of lobbies from Steam
	Steam.requestLobbyList()


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


# https://godotsteam.com/tutorials/lobbies/#creating-lobbies
func create_lobby() -> void:
	# Make sure a lobby is not already set
	if lobby_id == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, lobby_members_max)

		# https://michaelmacha.wordpress.com/2024/04/08/godotsteam-and-steammultiplayerpeer/
		# Create a new Steam multiplayer peer
		peer = SteamMultiplayerPeer.new()
		# Create the server
		peer.create_host(0)
		# Set the new peer to handle the RPC system
		multiplayer.multiplayer_peer = peer

		# https://youtu.be/fUBdnocrc3Y?t=360
		# Spawn the new scene
		spawner.spawn("res://scenes/level_0/level_0.tscn")
		$GUI.hide()


# https://godotsteam.com/tutorials/lobbies/#creating-lobbies
func _on_lobby_created(connection: int, this_lobby_id: int) -> void:
	if connection == 1:
		# Set the lobby ID
		lobby_id = this_lobby_id
		print("Created a lobby: %s" % lobby_id)
		# Set this lobby as joinable, just in case, though this should be done by default
		Steam.setLobbyJoinable(lobby_id, true)
		# Set some lobby data
		Steam.setLobbyData(lobby_id, "name", str(Steam.getPersonaName() + "'s lobby"))
		Steam.setLobbyData(lobby_id, "mode", "GodotSteam test")
		# Allow P2P connections to fallback to being relayed through Steam if needed
		var set_relay: bool = Steam.allowP2PPacketRelay(true)
		print("Allowing Steam to be relay backup: %s" % set_relay)


# https://godotsteam.com/tutorials/lobbies/#get-lobby-lists
func _on_open_lobby_list_pressed() -> void:
	# Set distance to worldwide
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	print("Requesting a lobby list")
	Steam.requestLobbyList()


# https://godotsteam.com/tutorials/lobbies/#get-lobby-lists
func _on_lobby_match_list(lobbies: Array) -> void:
	for child in $GUI/LobbyContainer/Lobbies.get_children():
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
		$GUI/LobbyContainer/Lobbies.add_child(lobby_button)


# https://godotsteam.com/tutorials/lobbies/#joining-lobbies
func join_lobby(this_lobby_id: int) -> void:
	print("Attempting to join lobby %s" % lobby_id)
	# Clear any previous lobby members lists, if you were in a previous lobby
	lobby_members.clear()
	# Make the lobby join request to Steam
	Steam.joinLobby(this_lobby_id)


# https://godotsteam.com/tutorials/lobbies/#joining-lobbies
func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	print("Joined lobby %s with response code %s" % [this_lobby_id, response])
	# If joining was successful
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		# Set this lobby ID as your lobby ID
		lobby_id = this_lobby_id
		# Get the lobby members
		get_lobby_members()
		# Make the initial handshake
		make_p2p_handshake()
	# Else it failed for some reason
	else:
		# Get the failure reason
		var fail_reason: String
		match response:
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: fail_reason = "This lobby no longer exists."
			Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: fail_reason = "You don't have permission to join this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: fail_reason = "The lobby is now full."
			Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR: fail_reason = "Uh... something unexpected happened!"
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: fail_reason = "You are banned from this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: fail_reason = "You cannot join due to having a limited account."
			Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: fail_reason = "This lobby is locked or disabled."
			Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: fail_reason = "This lobby is community locked."
			Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU: fail_reason = "A user in the lobby has blocked you from joining."
			Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER: fail_reason = "A user you have blocked is in the lobby."
		print("Failed to join this chat room: %s" % fail_reason)
		# Reopen the lobby list
		_on_open_lobby_list_pressed()


# https://godotsteam.com/tutorials/lobbies/#joining-lobbies
func _on_lobby_join_requested(this_lobby_id: int, friend_id: int) -> void:
	# Get the lobby owner's name
	var owner_name: String = Steam.getFriendPersonaName(friend_id)
	print("Joining %s's lobby..." % owner_name)
	# Attempt to join the lobby
	join_lobby(this_lobby_id)


# https://godotsteam.com/tutorials/lobbies/#getting-lobby-members
func get_lobby_members() -> void:
	# Clear your previous lobby list
	lobby_members.clear()
	# Get the number of members from this lobby from Steam
	var num_of_members: int = Steam.getNumLobbyMembers(lobby_id)
	# Get the data of these players from Steam
	for this_member in range(0, num_of_members):
		# Get the member's Steam ID
		var member_steam_id: int = Steam.getLobbyMemberByIndex(lobby_id, this_member)
		# Get the member's Steam name
		var member_steam_name: String = Steam.getFriendPersonaName(member_steam_id)
		# Add them to the list
		lobby_members.append({"steam_id": member_steam_id, "steam_name": member_steam_name})


# https://godotsteam.com/tutorials/lobbies/#persona-changes-avatars-names
func _on_persona_change(this_steam_id: int, _flag: int) -> void:
	# Make sure you're in a lobby and this user is valid or Steam might spam your console log
	if lobby_id > 0:
		print("A user (%s) had information change, update the lobby list" % this_steam_id)
		# Update the player list
		get_lobby_members()


# https://godotsteam.com/tutorials/lobbies/#p2p-handshakes
func make_p2p_handshake() -> void:
	print("Sending P2P handshake to the lobby")
	#send_p2p_packet(0, {"message": "handshake", "from": steam_id})


# https://godotsteam.com/tutorials/lobbies/#lobby-updates-changes
func _on_lobby_chat_update(_this_lobby_id: int, change_id: int, _making_change_id: int, chat_state: int) -> void:
	# Get the user who has made the lobby change
	var changer_name: String = Steam.getFriendPersonaName(change_id)
	# If a player has joined the lobby
	if chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		print("%s has joined the lobby." % changer_name)
	# Else if a player has left the lobby
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
		print("%s has left the lobby." % changer_name)
	# Else if a player has been kicked
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_KICKED:
		print("%s has been kicked from the lobby." % changer_name)
	# Else if a player has been banned
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_BANNED:
		print("%s has been banned from the lobby." % changer_name)
	# Else there was some unknown change
	else:
		print("%s did... something." % changer_name)
	# Update the lobby now that a change has occurred
	get_lobby_members()


# https://godotsteam.com/tutorials/lobbies/#lobby-chat-messages
func _on_send_chat_pressed() -> void:
	# Get the entered chat message
	var this_message: String = $Chat.get_text()
	# If there is even a message
	if this_message.length() > 0:
		# Pass the message to Steam
		var was_sent: bool = Steam.sendLobbyChatMsg(lobby_id, this_message)
		# Was it sent successfully?
		if not was_sent:
			print("ERROR: Chat message failed to send.")
	# Clear the chat input
	$Chat.clear()


# https://godotsteam.com/tutorials/lobbies/#leaving-a-lobby
func leave_lobby() -> void:
	# If in a lobby, leave it
	if lobby_id != 0:
		# Send leave request to Steam
		Steam.leaveLobby(lobby_id)
		# Wipe the Steam lobby ID then display the default lobby ID and player list title
		lobby_id = 0
		# Close session with all users
		for this_member in lobby_members:
			# Make sure this isn't your Steam ID
			if this_member['steam_id'] != steam_id:
				# Close the P2P session using the Networking class
				Steam.closeP2PSessionWithUser(this_member['steam_id'])
		# Clear the local lobby list
		lobby_members.clear()


# https://youtu.be/fUBdnocrc3Y?t=322
func spawn_level(data):
	# Instantiate and then return the loaded scene
	return (load(data) as PackedScene).instantiate()
