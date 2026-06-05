# Movement Test Architecture

This document describes the current implementation and what is still missing for the full system.

## Current Implementation

### Shared

#### `scripts/shared/ticker.gd`

`Ticker` emits a fixed 50ms tick lifecycle:

```text
before_tick
tick
after_tick
```

Both client and server scenes use this as their simulation clock.

#### `scripts/shared/physics_body.gd`

`PhysicsBody` is the shared movement simulation body. It extends `CharacterBody3D` and exposes:

```gdscript
simulate(input: MovementInputMsg.InputFrame, delta: float)
```

The input frame currently contains:

```text
seq
input_x
input_z
jump_pressed
jump_down
synthetic optional
```

#### `scripts/shared/protocol/movement_input_msg.gd`

Client-to-server movement input uses a hand-written binary message.
Each packet begins with the movement input magic byte from `scripts/shared/protocol/message_headers.gd`.

Each packet contains:

```text
previous_input
current_input
```

This gives one-frame UDP redundancy while keeping the packet fixed-size and easy to inspect.

#### `scripts/shared/protocol/movement_snapshot_msg.gd`

Server-to-client movement snapshots use a hand-written binary message instead of protobuf.
Each packet begins with the movement snapshot magic byte from `scripts/shared/protocol/message_headers.gd`.

Each packet has a small header and then one fixed-size entity record per entity. Each entity record contains:

```text
entity_id
last_processed_movement_seq
quantized position
quantized velocity
quantized rotation
flags
```

Position is quantized to millimeters. Velocity is quantized to centimeters per second. Rotation uses a smallest-three quantized quaternion. The current entity record is 34 bytes, plus an 8-byte packet header.

#### `scripts/shared/protocol/entity_lifecycle_msg.gd`

Server-to-client entity lifecycle uses a hand-written binary message on a reliable channel.
Each packet begins with the entity lifecycle magic byte from `scripts/shared/protocol/message_headers.gd`.

Each lifecycle packet contains:

```text
controlled_entity_id optional
entities_spawned[]
entities_despawned[]
```

Spawn records contain entity id, entity kind, initial position, and initial rotation. Despawn records contain entity id and an optional reason.

### Client

#### `scripts/client/client_scene.tscn`

The client scene contains:

```text
Ticker
GameSystems
GameSystems/API
Entities
Entities/PlayerEntity
Terrain, lighting, environment
```

The client has the local player, camera, visual smoothing, and networking API.

#### `scripts/client/game_systems.gd`

`GameSystems` owns the client tick order:

```text
gather local player input
assign client movement seq
store prediction frame
simulate local player immediately
store predicted position for that seq
tick remote entities placeholder
send current + previous input to server
```

It also listens for movement snapshots and currently logs prediction drift only. It does not reconcile yet.

Movement snapshots only update entities that already exist from authoritative lifecycle messages.

#### `scripts/client/player_input.gd`

Reads local WASD/space input and produces movement input dictionaries. Movement is camera-relative.

#### `scripts/client/prediction_ring_buffer.gd`

Stores predicted input frames in a fixed-size ring buffer.

The buffer preallocates 30 frame objects. Storing a frame overwrites fields on the existing ring item selected by:

```text
seq % size
```

Each frame stores:

```text
seq
input_x
input_z
jump_pressed
jump_down
predicted_position
```

The predicted position is used for manual drift logging when an authoritative server snapshot acknowledges the same sequence.

#### `scripts/client/api.gd`

`API` is a normal node instance under `GameSystems`.

It owns the ENet client connection and has three channels:

```text
channel 0: movement input to server
channel 1: movement snapshots from server
channel 2: entity lifecycle from server
```

It sends movement input packets using the binary movement input codec. It emits `movement_snapshot_received` after decoding binary movement snapshots and `entity_lifecycle_received` after decoding reliable lifecycle packets.

#### `scripts/client/player_spawner.gd`

`ClientPlayerSpawner` owns client-side entity lifetime.

The local player and remote players are spawned from authoritative lifecycle spawn records. The optional `controlled_entity_id` marks which spawned entity is the local player.

Lifecycle despawn records remove matching local or remote entities.

#### `scripts/client/smoothed_movement.gd`

Smooths the visual model between fixed movement ticks by listening directly to `Ticker.before_tick` and `Ticker.after_tick`.

#### `scripts/client/remote_entity.gd`

Remote entities receive movement snapshots from `GameSystems` and push them into `RemoteInterpolationBuffer`.

#### `scripts/client/remote_interpolation_buffer.gd`

Buffers remote movement snapshots and interpolates position/rotation with a short render delay. It does not extrapolate yet.

### Server

#### `scripts/server/server_scene.tscn`

The server scene contains:

```text
Ticker
ServerNetwork
PlayerSpawner
PlayerInputHandler
ServerGameSystems
Entities
DebugCamera3D
Terrain, lighting, environment
```

The server can be run as a normal debug scene or as a headless scene.

#### `scripts/server/server_network.gd`

Owns the ENet server connection.

It listens on:

```text
0.0.0.0:4242
```

It emits:

```gdscript
player_connected(peer_id)
player_disconnected(peer_id)
player_input_received(peer_id, input)
```

It decodes binary client movement input packets and emits each contained input frame. It also broadcasts binary movement snapshots on channel 1.

Peer ids are currently assigned locally by incrementing an integer. Peer lookup is currently based on ENet remote address and port.

#### `scripts/server/player_spawner.gd`

Owns server-side player lifetime.

On connect, it instantiates:

```text
scripts/server/server_player_entity.tscn
```

On disconnect, it removes the corresponding server player.

It sends authoritative lifecycle packets:

```text
new client: controlled_entity_id + spawn records for all current players
existing clients: spawn record for the newly connected player
remaining clients: despawn record for a disconnected player
```

It exposes:

```gdscript
get_player(peer_id)
get_players()
get_peer_ids()
```

#### `scripts/server/player_input_handler.gd`

Owns per-player movement input buffers.

Each peer has a `PeerBuffer` containing:

```text
peer_id
last_seen_seq
last_processed_seq
last_held_input
inputs_by_seq
```

When input is received, the server accepts it only if:

```text
input.seq > last_seen_seq
```

Accepted inputs are stored by sequence number.

`get_next_input(peer_id)` returns the lowest buffered input if one exists. If no input is available, it returns synthetic input based on the last held movement state. Synthetic input clears edge-triggered input like `jump_pressed` and does not advance the movement sequence.

`get_last_processed_seq(peer_id)` is used for snapshot acknowledgement.

#### `scripts/server/server_game_systems.gd`

Owns server tick ordering.

Each server tick currently runs:

```text
gather player inputs into _tick_context
simulate movement for all players
run other systems placeholder
broadcast movement snapshot
```

`_tick_context` is a per-peer scratchpad:

```gdscript
Dictionary[int, Dictionary]
```

Currently it only stores:

```text
input
```

Future systems can add more per-peer/per-tick data there.

## Current Differences From `system.md`

### Input Redundancy

`system.md` says movement frames include several previous frames for redundancy.

Current implementation sends only:

```text
previous_input
current_input
```

This is intentional for the current testbed.

### Server Sequence Handling

`system.md` says movement frames are processed strictly in sequence order and missing frames synthesize the next expected sequence.

Current implementation is looser:

```text
accept only seq > last_seen_seq
buffer accepted inputs
process the lowest buffered input each server tick
if none are buffered, synthesize without advancing seq
```

This means the server does not wait for a missing sequence. If packet `10` is lost and packet `11` arrives, `11` can become authoritative. Synthetic frames are server-side filler and do not claim a client sequence number.

If this behavior is now desired, `system.md` should be updated.

### Authoritative Snapshot Format

`system.md` describes snapshot contents but does not specify transport encoding.

Current implementation uses a custom binary codec for movement snapshots rather than protobuf.

### Client Reconciliation

`system.md` says the client should restore authoritative state, remove acknowledged inputs, replay remaining inputs, and continue prediction.

Current implementation does not reconcile yet.

It only:

```text
decodes movement snapshots
finds last_processed_movement_seq
looks up the predicted local position for that seq
prints the position diff when diff >= 0.01m
```

### Remote Player Movement

`system.md` says remote players interpolate between authoritative snapshots.

Current implementation spawns and despawns remote players from reliable lifecycle messages, and interpolates their movement snapshots. Optional extrapolation is not implemented yet.

### Abilities

The ability transport, command ids, movement anchors, and validation rules from `system.md` are not implemented.

## Missing For The Full System

### Client Reconciliation

Needed:

```text
store enough predicted movement state per seq
ack/prune prediction frames <= last_processed_movement_seq
restore authoritative state when correction is meaningful
replay unacknowledged inputs
avoid unnecessary correction for tiny quantization drift
```

The current prediction buffer stores input and predicted position only. Full replay will need enough stored input frames and a way to restore authoritative body state.

### Authoritative Movement State Completeness

The binary snapshot currently includes:

```text
position
velocity
rotation
is_on_floor
last_processed_movement_seq
```

`system.md` also calls out movement mode and other movement-relevant state. Those do not exist yet.

### Snapshot Consumption

Client receives and decodes movement snapshots, updates known remote players, and logs local prediction drift.

Needed:

```text
local-player reconciliation
optional short extrapolation
```

### Server Input Semantics Decision

The original document and current code disagree on missing-sequence behavior.

We should decide whether the final rule is:

```text
strict contiguous sequence processing
```

or:

```text
accept any increasing client sequence, synthesize only when no newer client input is buffered
```

The current implementation uses the second rule.

### Server Snapshot Policy

The server currently broadcasts snapshots every tick if any entities exist.

Still missing:

```text
snapshot priority/filtering
interest management
per-client visibility
packet loss behavior
snapshot sequence/timestamp if needed
```

### Ability System

No ability system exists yet.

Missing:

```text
reliable ordered transport
ability command protocol
command ids
movement_seq_anchor
server-side validation
delayed evaluation until movement anchor is authoritative
combat snapshots
```

### Transport Separation

Movement uses ENet UDP-style packets. Abilities are not implemented, so the reliable ordered channel described in `system.md` does not exist yet.

### Testing And Tooling

Current verification is mostly smoke testing.

Useful future tests:

```text
snapshot codec round-trip tests
prediction buffer wraparound tests
input buffer duplicate/out-of-order/loss tests
client/server drift tests
reconciliation replay tests
```
