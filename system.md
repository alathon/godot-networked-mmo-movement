# Network Architecture Overview

## Goals

- Remove the artificial "client runs N ticks ahead of server" latency.
- Keep the server authoritative.
- Preserve smooth local movement through client prediction.
- Avoid server rollback for movement.
- Allow movement and abilities to use different transports.

---

# Movement Input

## Client

The client runs movement simulation at 50ms ticks. Each movement tick generates a movement input frame with a monotonically increasing sequence number (`seq`).

Input frames are sent over UDP and include several previous frames for redundancy.

### Input Frame

```text
seq
movement state (forward/back/strafe/etc.)
edge inputs (jump pressed, jump released, etc.)
```

---

## Server

The server maintains a per-player movement input buffer keyed by sequence number.

Movement frames are processed strictly in sequence order. The server processes at most one movement frame per player per server tick.

Late movement frames for already-processed sequence numbers are discarded.

---

## Missing Input Handling

If the next expected movement sequence is unavailable:

- Repeat the last known held movement state.
- Do not repeat edge-triggered actions.
- Mark the frame as synthetic.

Synthetic frames become authoritative once simulated.

No server rollback is performed when the real input later arrives.

---

# Client Prediction

## Local Player

The client immediately simulates local movement using its own input.

Unacknowledged movement frames are stored in a prediction buffer.

### Prediction Buffer

```text
seq
input
```

---

## Reconciliation

Server movement snapshots include the last processed movement sequence.

When a snapshot is received:

1. Restore the authoritative state.
2. Remove acknowledged inputs.
3. Replay remaining buffered inputs.
4. Continue prediction.

---

# Authoritative Movement State

Movement corrections contain enough state to reproduce movement accurately.

### State

```text
position
velocity
grounded state
movement mode
other movement-relevant state
last_processed_seq
```

Position alone is insufficient.

---

# Remote Player Movement

Remote players are not predicted.

Clients interpolate between authoritative snapshots.

Optional short-duration extrapolation (dead reckoning) may be used when updates are temporarily missing.

---

# Abilities

## Transport

Abilities are sent over a reliable ordered channel (TCP or equivalent).

Each ability command has a unique command identifier.

### Ability Command

```text
command_id
ability_id
target information
movement_seq_anchor
```

---

## Movement Anchoring

Every ability references the most recent movement sequence known to the client when the ability was issued.

The server does not evaluate the ability until the referenced movement sequence has become authoritative.

This ensures abilities execute from the expected authoritative movement state.

---

## Ability Validation

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

# Server Tick

## Fixed Tick Rate

Client and server both run at 50ms ticks.

No global tick synchronization is required.

Movement ordering is based on movement sequence numbers rather than shared tick numbers.

---

# Snapshot Contents

Movement snapshots include:

```text
authoritative movement state
last_processed_movement_seq
```

Combat snapshots include any additional authoritative combat state as required.

---

# Rollback Policy

## Client

Client-side replay and reconciliation are allowed.

## Server

No movement rollback is performed.

Once a movement frame (real or synthetic) has been simulated, it becomes authoritative.

Late-arriving movement input is discarded.

This keeps the server simple, deterministic, and scalable.
