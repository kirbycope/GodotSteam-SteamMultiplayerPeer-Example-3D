# GodotSteam-SteamMultiplayerPeer-Example-3D
A 3D example for the [GodotSteam](https://godotsteam.com/) GDExtension and [Steam Multiplayer Peer](https://godotengine.org/asset-library/asset/2258) GDExtensions. The alternative would be to use the [SteamMultiplayerPeer](https://godotsteam.com/getting_started/what_are_you_making/#multiplayer-using-godots-multiplayerpeer-nodes) custom Godot Build. See the [godotsteam-multiplayerpeer-example](https://github.com/kirbycope/godotsteam-multiplayerpeer-example) example project if you're interested. I just wanted a single editor on my multiple machines, so this example was created.

## How It Works
[GodotSteam](https://godotsteam.com/) handles the Steam API initialization and lobbies.</br>
[Steam Multiplayer Peer](https://godotengine.org/asset-library/asset/2258) handles the P2P communication between the lobby host and clients.</br>
Proximity Voice Chat is enabled through the GodotSteam API and Steam-Multiplayer-Peer.

## How It is Implemented
This example uses the [Godot 3D Player Controller](https://github.com/kirbycope/godot-3d-player-controller). The idea is that you could use any CharacterBody3D (`.tscn/.gd`) with minimal modifications.

### Using Voice Chat
Press and hold [Tab] while in game to talk, release to mute.

### Changes to Make for Steam
1. Open "Project" > "Project Settings" and enable "Advanced Settings"
1. Enable "Audio" > "Driver" > "Enable Input"
1. Restart Godot
1. Change [Player_3d.gd](/scenes/main/player_3d.gd) to extend your Player script
1. Add the following to the beginning of any `_input()`, `_process()`, `_physics_process()`, or anything else that would affect the player state, for all related scripts
    ```
    # Do nothing if not the authority
    if !is_multiplayer_authority():
        return
    ```
1. Add a [MultiplayerSynchronizer](https://docs.godotengine.org/en/4.4/classes/class_multiplayersynchronizer.html) node to your `Player` sceen
1. Add a [Label3D](https://docs.godotengine.org/en/4.4/classes/class_label3d.html) node to your `Player` sceen
1. Move the Label3D above your player's head
1. Add the following Properties to the synchronizer (based on[Godot 3D Player Controller](https://github.com/kirbycope/godot-3d-player-controller))
    - Player:current_state
        - The 3D Player Controller uses a [Finite-state Machine (FSM)](https://en.wikipedia.org/wiki/Finite-state_machine)
    - `Player:position` | Replicate: Always
    - `Player:rotation` | Replicate: Always
    - `AnimationPlayer:current_animation` | Replicate: Always
    - `AuxScene:position` | Replicate: Always
        - The 3D Player Controller moves the Visuals (Skeleton and Meshes) independently of the player's position
    - `AuxScene:rotation` | Replicate: Always
        - The 3D Player Controller moves the Visuals (Skeleton and Meshes) independently of the player's position
    - `NameLabel:text` | Replicate: On Change
    - `Player:steam_id` | Replicate: On Change
    - `Player:steam_username` | Replicate: On Change

### Changes to Make for Steam Proximity Voice Chat
1. Add two [AudioStreamPlayer3D](https://docs.godotengine.org/en/4.4/classes/class_audiostreamplayer3d.html) nodes to your `Player` scene named `ProximityChatLocal` and `ProximityChatNetwork`
1. Set the "stream" property to [AudioStreamGenerator](https://docs.godotengine.org/en/4.4/classes/class_audiostreamgenerator.html)
1. Move the AudioStreamPlayer3Ds' position near your player's mouth

## FAQ
Q: Why doesn't my controller work?
A: If using AppId 480 (Space War), you need to disable Steam Input remapping, https://github.com/godotengine/godot/issues/75551#issuecomment-2107916120
