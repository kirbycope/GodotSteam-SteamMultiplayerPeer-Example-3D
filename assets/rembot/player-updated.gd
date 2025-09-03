## CREATED BY REMBOT GAMES
extends CharacterBody3D

@onready var camera_3d: Camera3D = $Camera3D
@onready var player_name_label: Label3D = $PlayerNameLabel

var current_sample_rate: int = 48000
var has_loopback: bool = false
var local_playback: AudioStreamGeneratorPlayback = null
var local_voice_buffer: PackedByteArray = PackedByteArray()
var network_playback: AudioStreamGeneratorPlayback = null
var network_voice_buffer: PackedByteArray = PackedByteArray()
var packet_read_limit: int = 5

@export var player_name:String = "Larry"
@export var steam_id:int = 0

@onready var prox_network: AudioStreamPlayer3D = $ProxNetwork
@onready var prox_local: AudioStreamPlayer3D = $ProxLocal

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _ready() -> void:
	prox_local.stream.mix_rate = current_sample_rate
	prox_local.play()
	local_playback = prox_local.get_stream_playback()
	
	prox_network.stream.mix_rate = current_sample_rate
	prox_network.play()
	network_playback = prox_network.get_stream_playback()
	
	add_to_group("players")
	
	if is_multiplayer_authority():
		camera_3d.set_current(true)
		player_name = SteamManager.STEAM_USERNAME
		steam_id = SteamManager.STEAM_ID
	else:
		steam_id = multiplayer.multiplayer_peer.get_steam64_from_peer_id(get_multiplayer_authority())
		player_name = Steam.getFriendPersonaName(steam_id)
		
		player_name_label.text = player_name
	


func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _input(event: InputEvent) -> void:
	if !is_multiplayer_authority():
		return
	
	## prox chat
	if Input.is_action_just_pressed("voice_record"):
		record_voice(true)
	elif Input.is_action_just_released("voice_record"):
		record_voice(false)

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		check_for_voice()


	
func record_voice(is_recording:bool) -> void:
	Steam.setInGameVoiceSpeaking(SteamManager.STEAM_ID, is_recording)
	
	if is_recording:
		Steam.startVoiceRecording()
	else:
		Steam.stopVoiceRecording()

func check_for_voice() -> void:
	var available_voice: Dictionary = Steam.getAvailableVoice()
	if available_voice['result'] == Steam.VOICE_RESULT_OK and available_voice['buffer'] > 0:
		var voice_data:Dictionary = Steam.getVoice()
		if voice_data['result'] == Steam.VOICE_RESULT_OK:
			SteamManager.send_voice_data(voice_data['buffer'])
			
			if has_loopback:
				process_voice_data(voice_data, "local")


func get_sample_rate(is_toggled:bool = true) -> void:
	if is_toggled:
		current_sample_rate = Steam.getVoiceOptimalSampleRate()
	else:
		current_sample_rate = 48000
	
	prox_network.stream.mix_rate = current_sample_rate
	prox_local.stream.mix_rate = current_sample_rate
	
	
func process_voice_data(voice_data:Dictionary, voice_source:String) -> void:
	get_sample_rate()
	
	var decompressed_voice:Dictionary
	if voice_source == "local":
		decompressed_voice = Steam.decompressVoice(voice_data['buffer'], current_sample_rate)
	elif voice_source == "network":
		decompressed_voice = Steam.decompressVoice(voice_data['voice_data'], current_sample_rate)
	
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
	

	## old code for debugging
'''func process_voice_data(voice_data:Dictionary, voice_source:String) -> void:
	get_sample_rate()
	var decompressed_voice:Dictionary
	if voice_source == "local":
		decompressed_voice = Steam.decompressVoice(voice_data['buffer'], current_sample_rate)
	elif voice_source == "network":
		decompressed_voice = Steam.decompressVoice(voice_data['voice_data'], current_sample_rate)
	
	if decompressed_voice['result'] == Steam.VOICE_RESULT_OK and decompressed_voice['uncompressed'].size() > 0:
		if voice_source == "local":
			local_voice_buffer = decompressed_voice['uncompressed']
			local_voice_buffer.resize(decompressed_voice['uncompressed'].size())
			for i:int in range(0, mini(local_playback.get_frames_available() * 2, local_voice_buffer.size()), 2):
				var raw_value: int = local_voice_buffer[0] | (local_voice_buffer[1] << 8)
				raw_value = (raw_value + 32768) & 0xffff
				var amplitude: float = float(raw_value - 32768) / 32768.0
				local_playback.push_frame(Vector2(amplitude, amplitude))
				
				local_voice_buffer.remove_at(0)
				local_voice_buffer.remove_at(0)
		elif voice_source == "network":
			network_voice_buffer = decompressed_voice['uncompressed']
			network_voice_buffer.resize(decompressed_voice['uncompressed'].size())
			for i:int in range(0, mini(network_playback.get_frames_available() * 2, network_voice_buffer.size()), 2):
				var raw_value: int = network_voice_buffer[0] | (network_voice_buffer[1] << 8)
				raw_value = (raw_value + 32768) & 0xffff
				var amplitude: float = float(raw_value - 32768) / 32768.0
				network_playback.push_frame(Vector2(amplitude, amplitude))
				
				network_voice_buffer.remove_at(0)
				network_voice_buffer.remove_at(0)'''


