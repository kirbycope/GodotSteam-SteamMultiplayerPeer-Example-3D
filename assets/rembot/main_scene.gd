## CREATED BY REMBOT GAMES
extends Node3D

@onready var lobbies_list: VBoxContainer = $MultiplayerUI/VBoxContainer/LobbiesScrollContainer/LobbiesList
@onready var multiplayer_ui: Control = $MultiplayerUI
@onready var player_spawner: MultiplayerSpawner = $Players/PlayerSpawner

var lobby_id = 0

var lobby_created:bool = false

var peer = SteamMultiplayerPeer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	peer = SteamManager.peer
	
	peer.lobby_created.connect(_on_lobby_created)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_host_btn_pressed() -> void:
	if lobby_created:
		return
	
	peer.create_lobby(SteamMultiplayerPeer.LOBBY_TYPE_PUBLIC)
	multiplayer.multiplayer_peer = peer

func _on_join_btn_pressed() -> void:
	var lobbies_btns = lobbies_list.get_children()
	for i in lobbies_btns:
		i.queue_free()
	
	open_lobby_list()

func open_lobby_list():
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()

func _on_lobby_created(connect: int, _lobby_id: int):
	if connect:
		lobby_id = _lobby_id
		Steam.setLobbyData(lobby_id,"name", str(SteamManager.STEAM_USERNAME+"'s Lobby"))
		Steam.setLobbyJoinable(lobby_id, true)
		
		SteamManager.lobby_id = lobby_id
		SteamManager.is_lobby_host = true
		
		hide_menu()
		
		player_spawner.spawn_host()
		

func _on_lobby_match_list(lobbies: Array):
	for lobby in lobbies:
		var lobby_name = Steam.getLobbyData(lobby,"name")
		var member_count = Steam.getNumLobbyMembers(lobby)
		var max_players = Steam.getLobbyMemberLimit(lobby)
		
		var but := Button.new()
		but.set_text("{0} | {1}/{2}".format([lobby_name,member_count,max_players]))
		but.set_size(Vector2(400,50))
		
		but.pressed.connect(join_lobby.bind(lobby))
		lobbies_list.add_child(but)

func join_lobby(_lobby_id):
	peer.connect_lobby(_lobby_id)
	multiplayer.multiplayer_peer = peer
	lobby_id =  _lobby_id
	hide_menu()

func hide_menu():
	multiplayer_ui.hide()
