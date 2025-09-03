extends Node

var steam_initialized := false ## Is the Steam API initialized?


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# `AppId: 480` is 'Spacewar'
	OS.set_environment("SteamAppId", str(480))
	OS.set_environment("SteamGameId", str(480))
	# Initialize Steam API first
	print("Initializing Steam API...")
	steam_initialized = Steam.steamInit()
	if steam_initialized:
		print("└── Steam API initialized successfully.")
	else:
		push_warning("└── [STEAM] steamInit failed; Steam features disabled.")
		return


## Called on each idle frame, prior to rendering, and after physics ticks have been processed.
func _process(_delta: float) -> void:
	# Required to pump Steam callbacks each frame
	if steam_initialized:
		Steam.run_callbacks()


## Called when the node is about to leave the SceneTree.
func _exit_tree() -> void:
	# Clean shutdown
	if steam_initialized:
		Steam.steamShutdown()
