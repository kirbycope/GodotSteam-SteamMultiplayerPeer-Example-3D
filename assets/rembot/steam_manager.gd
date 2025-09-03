## CREATED BY REMBOT GAMES
extends Node

const PACKET_READ_LIMIT: int = 32

var STEAM_APP_ID:int = 480
var STEAM_USERNAME:String = ""
var STEAM_ID:int = 0

var is_lobby_host:bool
var lobby_id:int
var lobby_members: Array
 
var peer:SteamMultiplayerPeer = SteamMultiplayerPeer.new()

func _init() -> void:
	OS.set_environment("SteamAppID", str(STEAM_APP_ID))
	OS.set_environment("SteamGameID", str(STEAM_APP_ID))

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Steam.steamInit()
	
	STEAM_ID = Steam.getSteamID()
	#print(STEAM_ID)
	
	STEAM_USERNAME = Steam.getPersonaName()
	print(STEAM_USERNAME)
	
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.p2p_session_request.connect(_on_p2p_session_request)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if lobby_id > 0:
		read_all_p2p_msg_packets()
		read_all_p2p_voice_packets()
	
	Steam.run_callbacks()

func _on_lobby_joined(this_lobby_id:int, _persmissions:int, _locked:bool, response:int):
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_id = this_lobby_id
		
		get_lobby_members()
		make_p2p_handshake()
		
		
		
func _on_p2p_session_request(remote_id: int):
	Steam.acceptP2PSessionWithUser(remote_id)
	

func make_p2p_handshake():
	send_p2p_packet(0, {"message": "handshake", "steam_id": STEAM_ID, "username": STEAM_USERNAME})

func send_voice_data(voice_data:PackedByteArray):
	send_p2p_packet(1, {"voice_data": voice_data, "steam_id": STEAM_ID, "username": STEAM_USERNAME})
	
func send_p2p_packet(this_target:int, packet_data:Dictionary, send_type:int = 0):
	var channel:int = 0
	var this_data: PackedByteArray
	this_data.append_array(var_to_bytes(packet_data))
	if this_target == 0:
		if lobby_members.size() > 1:
			for member in lobby_members:
				if member["steam_id"] != STEAM_ID:
					Steam.sendP2PPacket(member["steam_id"], this_data, send_type, channel)
	elif this_target == 1:
		if lobby_members.size() > 1:
			for member in lobby_members:
				if member["steam_id"] != STEAM_ID:
					Steam.sendP2PPacket(member["steam_id"], this_data, send_type, 1)
	else:
		Steam.sendP2PPacket(this_target, this_data, send_type, channel)
	
	
func get_lobby_members():
	lobby_members.clear()
	
	var num_of_lobby_members: int = Steam.getNumLobbyMembers(lobby_id)
	
	for member in range(0, num_of_lobby_members):
		var member_steam_id:int = Steam.getLobbyMemberByIndex(lobby_id,member)
		var member_steam_name:String = Steam.getFriendPersonaName(member_steam_id)
		
		lobby_members.append({
			"steam_id": member_steam_id,
			"steam_name": member_steam_name,
		})
	
func read_all_p2p_msg_packets(read_count:int = 0):
	if read_count >= PACKET_READ_LIMIT:
		return
	
	if Steam.getAvailableP2PPacketSize() > 0:
		read_p2p_msg_packet()
		read_all_p2p_msg_packets(read_count + 1)
		
func read_all_p2p_voice_packets(read_count:int = 0):
	if read_count >= PACKET_READ_LIMIT:
		return
	
	if Steam.getAvailableP2PPacketSize(1) > 0:
		read_p2p_voice_packet()
		read_all_p2p_msg_packets(read_count + 1)
		
func read_p2p_msg_packet():
	var packet_size: int = Steam.getAvailableP2PPacketSize(0)
	if packet_size > 0:
		var this_packet:Dictionary = Steam.readP2PPacket(packet_size,0)
		var packet_sender:int = this_packet["remote_steam_id"]
		var packet_code: PackedByteArray = this_packet["data"]
		var readable_data:Dictionary = bytes_to_var(packet_code)
		
		if readable_data.has("message"):
			match readable_data["message"]:
				"handshake":
					print("PLAYER: ", readable_data["username"], " has joined!")
					get_lobby_members()

func read_p2p_voice_packet():
	var packet_size: int = Steam.getAvailableP2PPacketSize(1)
	if packet_size > 0:
		var this_packet:Dictionary = Steam.readP2PPacket(packet_size, 1)
		var packet_sender:int = this_packet["remote_steam_id"]
		var packet_code: PackedByteArray = this_packet["data"]
		var readable_data:Dictionary = bytes_to_var(packet_code)
		
		if readable_data.has("voice_data"):
			print("reading ",readable_data["username"], "'s voice data.")
			var players_in_scene:Array = get_tree().get_nodes_in_group("players")
			for player in players_in_scene:
				if player.steam_id == packet_sender:
					player.process_voice_data(readable_data, "network")
				else:
					pass
		
		
