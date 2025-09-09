extends "res://addons/3d_player_controller/player_3d.gd"
## This script extends the 3D Player Controller addon to add custom functionality for GodotSteam.

# Note: `@export` variables are available for editing in the property editor.
@export var has_loopback: bool = false ## Does the player have Steam voice chat loopback enabled?
@export var steam_id: int = 0 ## The Steam ID of the player
@export var steam_username: String = "" ## The Steam username of the player
@export var is_using_x_bot: bool = false : set = _set_is_using_x_bot ## Is the player using the X_Bot model (false = Y_Bot, true = X_Bot)

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


## Setter for is_using_x_bot that triggers model swap when value changes
func _set_is_using_x_bot(value: bool) -> void:
	if is_using_x_bot != value:
		is_using_x_bot = value
		# Only perform the swap if we're not the authority (to avoid double-swapping)
		# The authority will have already swapped via the RPC call
		if not is_multiplayer_authority():
			_perform_bot_model_swap()


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


## Swaps between Y_Bot and X_Bot models across the network
@rpc("any_peer", "call_local")
func swap_bot_model_network(use_x_bot: bool) -> void:
	# Update the exported variable that will be replicated
	is_using_x_bot = use_x_bot
	# Call the actual model swapping function
	_perform_bot_model_swap()


## Performs the actual bot model swap locally
func _perform_bot_model_swap() -> void:
	# Preload the bot scenes
	const X_BOT_SCENE = preload("uid://dsp7vcraux38l")
	const Y_BOT_SCENE = preload("uid://c714y0011rxmt")
	
	# Get the current AuxScene
	var current_aux_scene = get_node("Visuals/AuxScene")
	# Get the current AuxScene's animation
	var current_animation = current_aux_scene.get_node("AnimationPlayer").current_animation
	# Preserve the full global transform (position + rotation + scale) before removal
	var saved_transform: Transform3D = current_aux_scene.global_transform
	# Remove the current AuxScene immediately
	get_node("Visuals").remove_child(current_aux_scene)
	current_aux_scene.free()
	# Instantiate the new bot scene
	var new_scene
	if is_using_x_bot:
		new_scene = X_BOT_SCENE.instantiate()
	else:
		new_scene = Y_BOT_SCENE.instantiate()
	# Set the scene name
	new_scene.name = "AuxScene"
	# Ensure the new AuxScene is top-level so it ignores parent transforms (matches original setup)
	new_scene.top_level = true
	# Add the new scene to the Visuals node first
	get_node("Visuals").add_child(new_scene)
	# Restore the saved global transform to retain exact orientation & position
	new_scene.global_transform = saved_transform
	# Update all the player's references to the new AuxScene and its children
	visuals_aux_scene = new_scene
	visuals_aux_scene_position = new_scene.position
	animation_player = new_scene.get_node("AnimationPlayer")
	# Update skeleton and bone attachment references
	var new_skeleton = new_scene.get_node("GeneralSkeleton")
	player_skeleton = new_skeleton
	bone_attachment_left_foot = new_skeleton.get_node("BoneAttachment3D_LeftFoot")
	bone_attachment_right_foot = new_skeleton.get_node("BoneAttachment3D_RightFoot")
	bone_attachment_left_hand = new_skeleton.get_node("BoneAttachment3D_LeftHand")
	bone_attachment_right_hand = new_skeleton.get_node("BoneAttachment3D_RightHand")
	look_at_modifier = new_skeleton.get_node("LookAtModifier3D")
	physical_bone_simulator = new_skeleton.get_node_or_null("PhysicalBoneSimulator3D")
	# Restore animation if there was one playing
	if current_animation != "" and animation_player != null:
		animation_player.play(current_animation)
