extends "res://addons/3d_player_controller/player_3d.gd"
## This script extends the 3D Player Controller addon to add custom functionality for GodotSteam.

# Note: `@export` variables are available for editing in the property editor.
@export var has_loopback: bool = false ## Does the player have Steam voice chat loopback enabled?
@export var steam_id: int = 0 ## The Steam ID of the player
@export var steam_username: String = "" ## The Steam username of the player

var current_sample_rate: int = 48000
var local_playback: AudioStreamGeneratorPlayback = null
var local_voice_buffer: PackedByteArray = PackedByteArray()
var network_playback: AudioStreamGeneratorPlayback = null
var network_voice_buffer: PackedByteArray = PackedByteArray()
var packet_read_limit: int = 5

# Note: `@onready` variables are set when the scene is loaded.
@onready var proximity_chat_indicator: MeshInstance3D = $ProximityChatIndicator
@onready var proximity_chat_local: AudioStreamPlayer3D = $ProximityChatLocal
@onready var proximity_chat_network: AudioStreamPlayer3D = $ProximityChatNetwork


## @override Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set the canvas layer behind all other Control nodes
	$Controls.layer = -1
	# Start "standing"
	$States/Standing.start()
	# Uncomment the next line(s) if using GodotSteam	
	proximity_chat_local.stream.mix_rate = current_sample_rate
	proximity_chat_local.play()
	local_playback = proximity_chat_local.get_stream_playback()
	proximity_chat_network.stream.mix_rate = current_sample_rate
	proximity_chat_network.play()
	network_playback = proximity_chat_network.get_stream_playback()
	if !is_multiplayer_authority():
		# For non-authority players, ensure the correct bot model is loaded based on replicated state
		if is_using_x_bot:
			_perform_bot_model_swap()
		return
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()
	print("steam username: %s" % steam_username)


## Called when there is an input event.
func _input(_event: InputEvent) -> void:
	if !is_multiplayer_authority():
		return
	if Input.is_action_just_pressed("button_12"):
		record_voice(true)
	elif Input.is_action_just_released("button_12"):
		record_voice(false)


## Called every frame. '_delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Do nothing if not the authority
	if !is_multiplayer_authority(): return
	# Check for voice input
	check_for_voice()


## Checks for available voice data [input] and processes it if found.
func check_for_voice() -> void:
	var available_voice: Dictionary = Steam.getAvailableVoice()
	if available_voice['result'] == Steam.VOICE_RESULT_OK and available_voice['buffer'] > 0:
		var voice_data: Dictionary = Steam.getVoice()
		if voice_data['result'] == Steam.VOICE_RESULT_OK:
			$"/root/Main/SteamLobby".send_voice_data(voice_data['buffer'])
			if has_loopback:
				process_voice_data(voice_data, "local")


## Gets the optimal sample rate for voice processing.
func get_sample_rate(is_toggled: bool = true) -> void:
	if is_toggled:
		current_sample_rate = Steam.getVoiceOptimalSampleRate()
	else:
		current_sample_rate = 48000
	proximity_chat_local.stream.mix_rate = current_sample_rate
	proximity_chat_network.stream.mix_rate = current_sample_rate


## @override Getter for the player's username.
func get_username() -> String:
	var username = steam_username
	if username.is_empty():
		username = OS.get_environment("USERNAME")
	if username.is_empty():
		username = OS.get_environment("USER")
	return username


## Processes and plays back the decompressed voice data.
func process_voice_data(voice_data: Dictionary, voice_source: String) -> void:
	get_sample_rate()
	var decompressed_voice: Dictionary
	if voice_source == "local":
		decompressed_voice = Steam.decompressVoice(voice_data['buffer'], current_sample_rate)
		print_rich("[color=Dimgray][INFO] Decompressed local voice data.[/color]")
	elif voice_source == "network":
		decompressed_voice = Steam.decompressVoice(voice_data['voice_data'], current_sample_rate)
		print_rich("[color=Dimgray][INFO] Decompressed network voice data.[/color]")
	if decompressed_voice['result'] == Steam.VOICE_RESULT_OK and decompressed_voice['uncompressed'].size() > 0:
		var playback_to_use = local_playback if voice_source == "local" else network_playback
		var voice_buffer = decompressed_voice['uncompressed']
		voice_buffer.resize(decompressed_voice['size'])
		var frames_available = playback_to_use.get_frames_available()
		# Process in chunks of 2 bytes (16-bit samples)
		for i in range(0, min(frames_available * 2, voice_buffer.size() - 1), 2):
			if i + 1 >= voice_buffer.size():
				break
			# Extract 16-bit sample from two bytes
			var raw_value: int = voice_buffer[i] | (voice_buffer[i + 1] << 8)
			raw_value = (raw_value + 32768) & 0xffff
			var amplitude: float = float(raw_value - 32768) / 32768.0
			# Push frame to audio buffer
			playback_to_use.push_frame(Vector2(amplitude, amplitude))


## Toggles [local] voice recording on or off.
func record_voice(is_recording: bool) -> void:
	Steam.setInGameVoiceSpeaking($"/root/Main/SteamLobby".steam_id, is_recording)
	if is_recording:
		print("Recording %s's voice..." % Steam.getFriendPersonaName($"/root/Main/SteamLobby".steam_id))
		Steam.startVoiceRecording()
	else:
		Steam.stopVoiceRecording()
		print("└── Recording stopped.")
	proximity_chat_indicator.visible = is_recording
