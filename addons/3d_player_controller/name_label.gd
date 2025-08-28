extends Label3D


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set playername
	text = str(Steam.getPersonaName())
