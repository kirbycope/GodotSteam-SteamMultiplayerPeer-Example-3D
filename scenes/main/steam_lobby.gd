extends Node

# https://godotsteam.com/tutorials/lobbies/#set-up
const PACKET_READ_LIMIT: int = 32
var lobby_data
var lobby_id: int = 0
var lobby_members: Array = []
var lobby_members_max: int = 10
var lobby_vote_kick: bool = false

# https://michaelmacha.wordpress.com/2024/04/08/godotsteam-and-steammultiplayerpeer/
const CONNECTION_TIMEOUT: float = 10.0
var connection_timeout_timer: Timer = null
var peer: SteamMultiplayerPeer
var pending_owner_id: int = 0

var steam_id: int
var steam_username: String


# https://godotsteam.com/tutorials/lobbies/#the-_ready-function
func _ready() -> void:
	Steam.join_requested.connect(_on_lobby_join_requested)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_created.connect(_on_lobby_created)
	#Steam.lobby_data_update.connect(_on_lobby_data_update)
	#Steam.lobby_invite.connect(_on_lobby_invite)
	Steam.lobby_joined.connect(_on_lobby_joined)
	#Steam.lobby_match_list.connect(_on_lobby_match_list) # moved to `main.gd`
	#Steam.lobby_message.connect(_on_lobby_message)
	Steam.persona_state_change.connect(_on_persona_change)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connection_success)
	# Cache Steam info for logged in user
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()
	# Connect the signal
	Steam.p2p_session_request.connect(_on_p2p_session_request)


# https://godotsteam.com/tutorials/lobbies/#creating-lobbies
func create_lobby() -> void:
	# Make sure a lobby is not already set
	if lobby_id == 0:
		print("Creating a lobby...")
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, lobby_members_max)

		# https://michaelmacha.wordpress.com/2024/04/08/godotsteam-and-steammultiplayerpeer/
		peer = SteamMultiplayerPeer.new()
		# Create the server
		peer.create_host(0)
		# Set the new peer to handle the RPC system
		multiplayer.set_multiplayer_peer(peer)

		# https://youtu.be/fUBdnocrc3Y?t=360
		# Spawn the new scene
		$"..".spawner.spawn("res://scenes/level_0/level_0.tscn")
		# Hide the Lobby GUI
		$"../GUI".hide()


# https://godotsteam.com/tutorials/lobbies/#creating-lobbies
func _on_lobby_created(connection: int, this_lobby_id: int) -> void:
	if connection == 1:
		print("└── Created lobby: ", this_lobby_id)
		# Set the lobby ID
		lobby_id = this_lobby_id
		# Set this lobby as joinable, just in case, though this should be done by default
		Steam.setLobbyJoinable(lobby_id, true)
		# Set some lobby data
		Steam.setLobbyData(lobby_id, "name", str(Steam.getPersonaName() + "'s lobby"))
		Steam.setLobbyData(lobby_id, "mode", "GodotSteam test")
		# Allow P2P connections to fallback to being relayed through Steam if needed
		#print("Allowing Steam to be relay backup: %s" % set_relay)
		#var set_relay: bool = Steam.allowP2PPacketRelay(true)


# https://godotsteam.com/tutorials/lobbies/#get-lobby-lists
func update_lobby_list() -> void:
	print("Updating lobby list...")
	# Set distance to worldwide
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	# Request the current lobby list from Steam
	Steam.requestLobbyList()


# https://godotsteam.com/tutorials/lobbies/#joining-lobbies
func _on_lobby_join_requested(this_lobby_id: int, friend_id: int) -> void:
	# Get the lobby owner's name
	var owner_name: String = Steam.getFriendPersonaName(friend_id)
	print("Joining %s's lobby..." % owner_name)
	# Attempt to join the lobby
	$".".join_lobby(this_lobby_id)


# https://godotsteam.com/tutorials/lobbies/#joining-lobbies
func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	print("└── Joined lobby: ", this_lobby_id)
	# If joining was successful
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		# Set this lobby ID as your lobby ID
		lobby_id = this_lobby_id
		# Get the lobby members
		get_lobby_members()
		# Make the initial handshake
		make_p2p_handshake()
		# Set the current Lobby ID
		lobby_id = this_lobby_id
		# If we're not the lobby owner, create the Steam client peer to the owner
		var owner_id := Steam.getLobbyOwner(this_lobby_id)
		if owner_id != Steam.getSteamID():
			peer = SteamMultiplayerPeer.new()
			# Use the owner's Steam ID so we attempt to connect to them
			peer.create_client(owner_id, 0)
			multiplayer.set_multiplayer_peer(peer)
			print("Created Steam client to owner %s; waiting for connection...." % owner_id)
			# Start a timeout in case the P2P connection never completes
			_start_connection_timeout(owner_id)
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
		$".."._on_open_lobby_list_pressed()


# https://godotsteam.com/tutorials/lobbies/#p2p-handshakes
#func make_p2p_handshake() -> void:
#	print("Sending P2P handshake to the lobby")
#	send_p2p_packet(0, {"message": "handshake", "from": steam_id})


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
	print_rich("[color=Dimgray][INFO] Current lobby members: %s[/color]" % [lobby_members])


# https://godotsteam.com/tutorials/lobbies/#persona-changes-avatars-names
func _on_persona_change(this_steam_id: int, _flag: int) -> void:
	# Make sure you're in a lobby and this user is valid or Steam might spam your console log
	if lobby_id > 0:
		print_rich("[color=Dimgray][INFO] A user (%s) had information change, updating the lobby list...[/color]" % this_steam_id)
		# Update the player list
		get_lobby_members()


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


#region Connection timeout helpers


func _start_connection_timeout(owner_id: int) -> void:
	# Save pending owner so we can cleanup on timeout
	pending_owner_id = owner_id
	# Create timer if not present
	if connection_timeout_timer == null:
		connection_timeout_timer = Timer.new()
		connection_timeout_timer.one_shot = true
		connection_timeout_timer.wait_time = CONNECTION_TIMEOUT
		connection_timeout_timer.connect("timeout", Callable(self, "_on_connection_timeout"))
		add_child(connection_timeout_timer)
	# Start/restart the timer
	connection_timeout_timer.start()
	print("Started connection timeout (%ss) for owner %s" % [CONNECTION_TIMEOUT, owner_id])


func _stop_connection_timeout() -> void:
	if connection_timeout_timer != null and connection_timeout_timer.is_inside_tree():
		connection_timeout_timer.stop()
		connection_timeout_timer.queue_free()
	connection_timeout_timer = null
	pending_owner_id = 0


func _on_connection_failed():
	print("Connection failed.")
	# Cleanup any pending connection attempt
	if pending_owner_id != 0:
		Steam.closeP2PSessionWithUser(pending_owner_id)
		pending_owner_id = 0
	_stop_connection_timeout()


func _on_connection_success():
	print("Connection success!")
	# Stop any connection timeout timer
	_stop_connection_timeout()


func _on_connection_timeout() -> void:
	print("Connection to owner %s timed out after %s seconds." % [pending_owner_id, CONNECTION_TIMEOUT])
	# Close any open P2P session to the owner
	if pending_owner_id != 0:
		Steam.closeP2PSessionWithUser(pending_owner_id)
		pending_owner_id = 0
	# Reset multiplayer peer if set
	if multiplayer.get_multiplayer_peer() != null:
		multiplayer.set_multiplayer_peer(null)

#endregion


#region Proximity Voice Chat


func _process(_delta: float) -> void:
	if lobby_id > 0:
		read_all_p2p_msg_packets()
		read_all_p2p_voice_packets()


func _on_p2p_session_request(remote_id: int):
	print("[P2P] session request from %s..." % remote_id)
	var success = Steam.acceptP2PSessionWithUser(remote_id)
	if success:
		print("└── [P2P] session accepted.")
	else:
		push_warning("└── [P2P] session failed to accept.")


func make_p2p_handshake() -> void:
	send_p2p_packet(0, {"message": "handshake", "steam_id": steam_id, "username": steam_username})


func send_voice_data(voice_data: PackedByteArray):
	send_p2p_packet(1, {"voice_data": voice_data, "steam_id": steam_id, "username": steam_username})


func send_p2p_packet(this_target: int, packet_data: Dictionary, send_type: int = 0):
	
	var channel: int = 0
	var this_data: PackedByteArray
	this_data.append_array(var_to_bytes(packet_data))
	if this_target == 0:
		if lobby_members.size() > 1:
			for member in lobby_members:
				if member["steam_id"] != steam_id:
					print("[P2P] Sending message packet to remote steam id %s: " % member["steam_id"])
					var success = Steam.sendP2PPacket(member["steam_id"], this_data, send_type, channel)
					if success:
						print("└── [P2P] Packet sent.")
					else:
						push_warning("└── [P2P] Packet failed to send.")
	elif this_target == 1:
		if lobby_members.size() > 1:
			for member in lobby_members:
				if member["steam_id"] != steam_id:
					print("[P2P] Sending voice packet to remote steam id %s: " % member["steam_id"])
					var success = Steam.sendP2PPacket(member["steam_id"], this_data, send_type, 1)
					if success:
						print("└── [P2P] Packet sent.")
					else:
						push_warning("└── [P2P] Packet failed to send.")
	else:
		print("[P2P] Sending packet to _this_ target %s..." % this_target)
		var success = Steam.sendP2PPacket(this_target, this_data, send_type, channel)
		if success:
			print("└── [P2P] Packet sent.")
		else:
			push_warning("└── [P2P] Packet failed to send.")


func read_all_p2p_msg_packets(read_count: int = 0):
	if read_count >= PACKET_READ_LIMIT:
		return
	if Steam.getAvailableP2PPacketSize() > 0:
		read_p2p_msg_packet()
		read_all_p2p_msg_packets(read_count + 1)


func read_all_p2p_voice_packets(read_count: int = 0):
	if read_count >= PACKET_READ_LIMIT:
		return
	if Steam.getAvailableP2PPacketSize(1) > 0:
		read_p2p_voice_packet()
		read_all_p2p_msg_packets(read_count + 1)


func read_p2p_msg_packet():
	var packet_size: int = Steam.getAvailableP2PPacketSize(0)
	if packet_size > 0:
		var this_packet: Dictionary = Steam.readP2PPacket(packet_size, 0)
		var packet_sender: int = this_packet["remote_steam_id"]
		var packet_code: PackedByteArray = this_packet["data"]
		var readable_data: Dictionary = bytes_to_var(packet_code)
		if readable_data.has("message"):
			match readable_data["message"]:
				"handshake":
					print("PLAYER: ", readable_data["username"], " has joined!")
					get_lobby_members()


func read_p2p_voice_packet():
	var packet_size: int = Steam.getAvailableP2PPacketSize(1)
	if packet_size > 0:
		var this_packet: Dictionary = Steam.readP2PPacket(packet_size, 1)
		var packet_sender: int = this_packet["remote_steam_id"]
		print("reading voice packet from %s" % packet_sender)
		var packet_code: PackedByteArray = this_packet["data"]
		var readable_data: Dictionary = bytes_to_var(packet_code)
		if readable_data.has("voice_data"):
			print("reading ", readable_data["username"], "'s voice data.")
			#var players_in_scene: Array = get_tree().get_nodes_in_group("players")
			var players_in_scene: Array = get_tree().get_nodes_in_group("Player")
			for player in players_in_scene:
				if player.steam_id == packet_sender:
					player.process_voice_data(readable_data, "network")
				else:
					pass


#endregion
