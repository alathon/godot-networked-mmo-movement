---
name: gdscript
description: Write GDScript code
disable-model-invocation: false
---

# References to other components

- If a script needs to reference another node that it knows will be part of the same scene,
use an `@onready var` pointing to a `%`-unique name. For example: `@onready var body: CharacterBody3D = %Body`. Otherwise use an @export var that can be set in the editor.
- Do not instantiate scene/service nodes with `new()` in production code when they can be added to a stable `.tscn` scene.
  Add them to the scene and reference them with `@onready var _service: ServiceType = %ServiceName` instead.
- Don't use `setup()` or `bind()` methods to accomplish the above.

# Preloads

- Do not preload(), except to reference the `Proto` messages, e.g., `const Proto = preload("res://projects/common/src/proto/packets.gd")`.
- You can use references to any class_name in the whole project, without preload()'ing it.

# Separation of concerns
Keep logic in .gd files, data in .tres files:

```
src/
  spells/
    spell_resource.gd      # Class definition + logic
    spell_effect.gd        # Effect logic
resources/
  spells/
    fireball.tres          # Data only, references scripts
    ice_spike.tres         # Data only
```

# Component-Based Architecture
Break functionality into focused components:

Player (CharacterBody3D)
├─ Attributes (Node)           # Component
├─ Inventory (Node)            # Component
└─ StateMachine (Node)         # Component
    ├─ IdleState (Node)
    ├─ MoveState (Node)
    └─ AttackState (Node)

Benefits:

- Each component is a small, focused file
- Easy to understand and modify
- Clear responsibilities
- Reusable across different entities of similar types

# Signal-driven communication
Use signals for loose coupling:

```
signal health_changed(current, max)
signal death()

# Parent connects to signals
func _ready():
    $HealthAttribute.health_changed.connect(_on_health_changed)
    $HealthAttribute.death.connect(_on_death)
```

Benefits:

- No tight coupling between systems
- Easy to add new listeners
- Self-documenting (signals show available events)
- UI can connect without modifying game logic

# Godot resource files (.tres, .tscn)
- NEVER manually assign or generate uid:// fields—Godot fills these in automatically

# Connecting @exports in scene files
When a script uses @export var some_node: SomeNodeType, you can assign it via a .tscn file:

```
[node name="MyNode" type="Node3D" parent="." node_paths=PackedStringArray("player", "camera")]
script = ExtResource("1_abc123")
player = NodePath("../Player")
camera = NodePath("CameraPivot/Camera3D")
```

# Import new files with Godot CLI

After creating a new file, run the Godot CLI with `--import` to help them get picked up by the editor:
```
godot --headless --import
```
This should be run in `main/`, the Godot project root directory where `project.godot` is located. From the repo root, use `godot --headless --path main --import`. Remember that any folder containing .gdignore will be skipped during import.

# Duck-type or strongly type

- NEVER do `var a := b`. Either do:
  - Strongly typed: `var a: Type = b` OR
  - Duck-typed: `var a = b`

If casting with `var a: Type = b`doesn't seem to work, it is usually a sign that a .gdscript file is not compiling successfully.

# Dont look up the scene tree if you can avoid it

- Don't look *upward* in the scene tree. But its okay to look into *children*, use unique accessors and use globals:
	- Bad: @onready var _zone = get_owner()
	- Bad: @onready var _otherThing = $"../../Something"
	- Good: @onready var _unique = %UniqueAccessorInScene
	- Good: @onready var _downward = $MyThing/MyOtherThing
	- Good: 
		@export var _zone
		
		_ready():
			if _zone != null: ...

	- Good: const thing = Globals.GCD_COOLDOWN

- Don't look for nodes every frame or when you can avoid it.
	- Bad:
		var thing: int = 0:
			set(v):
				thing = v
				$MyThing.text = str(v)
	
	- Good:
		@onready var label = $MyThing
		
		var thing: int = 0:
			set(v):
				thing = v
				label.text = str(v)
