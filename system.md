# Network Architecture Overview

## Goals

- Keep the server authoritative.
- Preserve smooth local movement through client prediction.
- Avoid server rollback for movement.
- Keep the movement testbed extremely small and debuggable.
- Allow movement and abilities to use different transports later.

---

# Tick Rate

Client and server both run movement simulation at 50ms ticks.

No global tick synchronization is required.

Movement ordering is based on client-authored movement sequence numbers, not shared tick numbers.

---

# Movement Input

## Client

Each client movement tick generates a movement input frame with a monotonically increasing sequence number (`seq`).

The client decides the sequence number.

### Input Frame

```text
seq
movement held state (input_x, input_z, jump_down, etc.)
edge inputs (jump_pressed, etc.)
```

The client immediately simulates local movement with this input.

Input is sent to the server over UDP ENet using the shared binary movement input codec.

For redundancy, each movement packet contains:

```text
previous_input
current_input
```

The previous input is processed before the current input when received.

---

## Server

The server maintains a per-player movement input buffer keyed by sequence number.

The server accepts a movement input only if:

```text
input.seq > last_seen_seq
```

This means duplicate packets, reordered older packets, and late packets with sequence numbers lower than or equal to the latest accepted input are discarded.

Accepted inputs are stored in the player's movement input buffer.

On each server tick, the server processes at most one movement input per player:

1. If any buffered input exists, process the lowest buffered sequence number.
2. If no buffered input exists, synthesize movement from the last held input state.

The server does **not** wait for missing sequence numbers.

Example:

```text
last_seen_seq = 10
seq 11 is lost
seq 12 arrives
server accepts 12
server may process 12 as the next real authoritative input
```

No server rollback is performed if a missing or older input arrives later.

---

# Missing Input Handling

If no newer client input is buffered for a player on a server tick:

- Repeat the last known held movement state.
- Do not repeat edge-triggered actions.
- Mark the frame as synthetic.
- Do not advance the client movement sequence number.

Synthetic input is server-side filler only. It does not claim that the client sent a new movement sequence.

Synthetic movement becomes authoritative once simulated.

---

# Server Tick Order

The server runs systems in phases rather than fully updating one entity at a time.

Current movement tick order:

```text
gather player inputs into tick context
apply movement for all players
run other systems placeholder
broadcast movement snapshot
```

The tick context is a per-peer scratchpad used by server systems during one tick.

---

# Client Prediction

## Local Player

The client immediately simulates local movement using its own input.

Unacknowledged movement frames are stored in a fixed-size prediction ring buffer.

The current ring buffer stores:

```text
seq
input state
predicted position for debug/reconciliation
```

The current ring size is 30.

---

## Reconciliation

Movement snapshots include `last_processed_movement_seq`.

This is the acknowledgement for client prediction.

Full reconciliation is not implemented yet. The intended flow is:

1. Receive authoritative movement snapshot.
2. Read `last_processed_movement_seq`.
3. Remove or ignore acknowledged prediction frames.
4. Restore authoritative movement state if the correction is meaningful.
5. Replay remaining buffered inputs after the acknowledged sequence.
6. Continue prediction.

Current debug behavior:

```text
client compares predicted position at last_processed_movement_seq
against server authoritative position
logs the diff if it is >= 0.01m
```

---

# Authoritative Movement State

Authoritative movement state must contain enough data to reproduce movement accurately.

Current server movement snapshots include:

```text
entity_id
last_processed_movement_seq
position
velocity
rotation
is_on_floor
```

Position alone is insufficient.

Future movement state may need additional fields such as:

```text
movement mode
other movement-relevant state
```

---

# Movement Snapshot Encoding

Movement snapshots are sent server-to-client over UDP ENet.

Snapshots use a custom binary codec, not protobuf, because they are sent frequently.

Current snapshot encoding:

```text
packet header
entity records
```

Each entity record contains:

```text
u32 entity_id
u32 last_processed_movement_seq
i32 quantized_position_x
i32 quantized_position_y
i32 quantized_position_z
i16 quantized_velocity_x
i16 quantized_velocity_y
i16 quantized_velocity_z
quantized smallest-three quaternion rotation
u8 flags
```

Current entity record size is 34 bytes, plus a 4-byte packet header.

Current quantization:

```text
position: millimeters
velocity: centimeters per second
rotation: smallest-three quantized quaternion
```

---

# Entity Lifecycle

Entity lifecycle is authoritative and reliable.

The server sends batched lifecycle packets over a reliable ENet channel:

```text
controlled_entity_id optional
entities_spawned[]
entities_despawned[]
```

Spawn records include:

```text
entity_id
entity_kind
initial position
initial rotation
```

Despawn records include:

```text
entity_id
reason optional
```

Movement snapshots do not create or remove entities. They only update entities that already exist on the client.

---

# Remote Player Movement

Remote players are not predicted.

Clients spawn and despawn remote players from authoritative lifecycle messages.

Clients interpolate remote players between authoritative movement snapshots.

Optional short-duration extrapolation may be used when updates are temporarily missing.

Remote player extrapolation is not implemented yet.

---

# Abilities

Abilities are not implemented yet.

The intended direction is still:

```text
reliable ordered transport
unique command id
ability id
target information
movement_seq_anchor
```

Every ability should reference the most recent movement sequence known to the client when the ability was issued.

The server should not evaluate the ability until the referenced movement sequence has become authoritative.

The server validates:

- Cooldowns
- Resources
- Range
- Line of sight
- Target validity
- Cast state
- Ability timing

The server remains fully authoritative over ability outcomes.

---

# Rollback Policy

## Client

Client-side replay and reconciliation are allowed.

## Server

No movement rollback is performed.

Once a real or synthetic movement frame has been simulated, that movement becomes authoritative.

Older or duplicate movement input is discarded.

This keeps the server simple, deterministic, and scalable.

---

# Current Missing Pieces

- Client reconciliation beyond debug diff logging.
- Remote optional extrapolation.
- Full authoritative movement state if movement grows beyond position/velocity/rotation/grounded.
- Ability transport, anchoring, validation, and combat snapshots.
- Snapshot interest management and per-client filtering.
- Automated tests for input buffering, prediction ring wraparound, snapshot codec, and reconciliation.
