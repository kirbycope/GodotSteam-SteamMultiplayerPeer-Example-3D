extends Label3D


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set the username for this user only
	if is_multiplayer_authority():
		# Set playername
		text = str(Steam.getPersonaName())
