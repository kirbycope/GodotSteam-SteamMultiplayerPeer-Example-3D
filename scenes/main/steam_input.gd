extends Node

## Steam Input Type enum based on ESteamInputType from Steam API
enum SteamInputType {
	UNKNOWN = 0,
	STEAM_CONTROLLER = 1,
	XBOX_360_CONTROLLER = 2,
	XBOX_ONE_CONTROLLER = 3,
	GENERIC_XINPUT = 4,
	PS4_CONTROLLER = 5,
	APPLE_MFI_CONTROLLER = 6,
	ANDROID_CONTROLLER = 7,
	SWITCH_JOYCON_PAIR = 8,
	SWITCH_JOYCON_SINGLE = 9,
	SWITCH_PRO_CONTROLLER = 10,
	MOBILE_TOUCH = 11,
	PS3_CONTROLLER = 12
}

var input_initialized := false ## Is the Steam Input API initialized?


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize Steam Input
	print("Initializing Steam Input...")
	input_initialized = Steam.inputInit()
	if input_initialized:
		print("└── Steam Input initialized successfully.")
	else:
		push_warning("└── [STEAM] Steam Input failed to initialize.")
		return
	# Get connected controllers
	enumerate_controllers()


## Called when the node is about to leave the SceneTree.
func _exit_tree() -> void:
	# Clean shutdown
	if input_initialized:
		Steam.inputShutdown()


## Gets the controller type name from the enum.
func _get_controller_type_name(controller_type: SteamInputType) -> String:
	match controller_type:
		SteamInputType.UNKNOWN:
			return "Unknown Controller"
		SteamInputType.STEAM_CONTROLLER:
			return "Steam Controller"
		SteamInputType.XBOX_360_CONTROLLER:
			return "Xbox 360 Controller"
		SteamInputType.XBOX_ONE_CONTROLLER:
			return "Xbox One Controller"
		SteamInputType.GENERIC_XINPUT:
			return "Generic XInput Controller"
		SteamInputType.PS4_CONTROLLER:
			return "PlayStation 4 Controller"
		SteamInputType.APPLE_MFI_CONTROLLER:
			return "Apple MFi Controller"
		SteamInputType.ANDROID_CONTROLLER:
			return "Android Controller"
		SteamInputType.SWITCH_JOYCON_PAIR:
			return "Nintendo Switch Joy-Con Pair"
		SteamInputType.SWITCH_JOYCON_SINGLE:
			return "Nintendo Switch Joy-Con (Single)"
		SteamInputType.SWITCH_PRO_CONTROLLER:
			return "Nintendo Switch Pro Controller"
		SteamInputType.MOBILE_TOUCH:
			return "Mobile Touch Controller"
		SteamInputType.PS3_CONTROLLER:
			return "PlayStation 3 Controller"
		_:
			return "Unknown Controller Type (%d)" % controller_type


## List the connected controllers.
func enumerate_controllers() -> void:
	Steam.run_callbacks()
	print("Getting connected controllers...")
	var controllers: Array = []
	if input_initialized:
		controllers = Steam.getConnectedControllers()
	if controllers.size() == 0:
		print("└── No Steam Input controllers connected.")
	else:
		for handle in controllers:
			var controller_type := SteamInputType.UNKNOWN
			var type_name := "Unknown"
			if Steam.has_method("getInputTypeForHandle"):
				var steam_type = Steam.call("getInputTypeForHandle", handle)
				controller_type = steam_type as SteamInputType
				type_name = _get_controller_type_name(controller_type)
			print("└── Steam Input controller handle: %s, type: %s (%d)" % [handle, type_name, controller_type])
