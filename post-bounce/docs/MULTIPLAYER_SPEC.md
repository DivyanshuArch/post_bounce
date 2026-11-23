# Moonlit Ricochet / Post Bounce: Local Wi-Fi & Mobile Hotspot Multiplayer Architecture Specification

> **Document Type:** Technical Architecture & Game Design Document (GDD)  
> **Status:** Approved / Specification v1.0  
> **Target Engine:** Godot Engine 4.x  
> **Target Platforms:** Mobile (Android, iOS) & Desktop (PC / Mac / Linux)  
> **Networking Scope:** Local Area Network (Wi-Fi) & Cellular Mobile Hotspot (Offline / Router-less)

---

## 1. Executive Summary & Vision

**Moonlit Ricochet (Post Bounce)** is a precision slingshot ricochet game built on tactile squash-and-stretch physics, geometric bank shots, and atmospheric audiovisual feedback.

While single-player focuses on meditative course mastery and high scores, **Local Multiplayer** introduces high-stakes couch competition and on-the-go social gaming. Players can challenge friends in the same room, on long commutes, during flights, or at outdoor gatherings **without needing an active internet connection or external game servers**.

### Core Tenets
1. **Photon Fusion Room-Based Matchmaking:** Players enter a room name or code, or browse active rooms.
2. **Instant Auto-Start:** The moment two players enter the same room, the match starts automatically with zero extra clicks.
3. **Multi-Backend Resilience:** Uses the native Photon Fusion GDExtension (`addons/fusion`) with WebRTC native and local ENet fallbacks for 100% offline and cross-platform compatibility.
4. **High-Speed Responsive Physics:** Shots feel immediate; visual interpolation and client prediction prevent perceived lag.

---

## 2. Network Topology & Hardware Fundamentals

```
                  ┌──────────────────────────────────────────────┐
                  │           LOCAL NETWORK / HOTSPOT            │
                  └───────┬──────────────────────────────┬───────┘
                          │                              │
             ┌────────────▼───────────┐      ┌───────────▼────────────┐
             │       HOST DEVICE      │      │      CLIENT DEVICE     │
             │   (Server + Player 1)  │      │       (Player 2)       │
             ├────────────────────────┤      ├────────────────────────┤
             │ • ENet Server (7777)   │◄────►│ • ENet Client (7777)   │
             │ • UDP Beacon (7778)    │──────► • UDP Listener (7778) │
             │ • Game Authority       │      │ • Client Prediction    │
             └────────────────────────┘      └────────────────────────┘
```

### 2.1 The Two Connection Environments

#### Environment A: Standard Home / Campus / Office Wi-Fi
* Both devices are connected to the same wireless router.
* Router assigns IP addresses dynamically via DHCP (e.g., `192.168.1.45` and `192.168.1.82`).
* Subnet broadcast address (e.g., `192.168.1.255` or `255.255.255.255`) is normally permitted by default.

#### Environment B: Mobile Wi-Fi Hotspot (Router-less / Off-Grid)
* One player activates **Personal Hotspot / Portable Wi-Fi** on their smartphone (Android or iOS).
* The second player joins this Wi-Fi network from their device.
* **Standard Hotspot IP Allocations:**
  * **Android Hotspot Gateway:** Commonly `192.168.43.1` (Clients receive `192.168.43.x`).
  * **iOS Personal Hotspot Gateway:** Commonly `172.20.10.1` (Clients receive `172.20.10.x`).
* **The "AP Isolation / Broadcast Filter" Challenge:**
  * Some mobile operating systems throttle or drop generic UDP broadcast packets (`255.255.255.255`) across hotspot interfaces to preserve cellular battery life.
  * **Solution (Dual Discovery Engine):**
    1. **Broadcast Beacon (Primary):** Host broadcasts JSON packet to UDP port `7778`.
    2. **Gateway Unicast Ping (Secondary):** When client scans for rooms, it automatically sends a direct ping to the default gateway (`192.168.43.1` or `172.20.10.1`). If the host is the hotspot provider, this bypasses broadcast filters entirely.
    3. **Direct IP Display (Fallback):** The Host UI prominently displays its IP (e.g. `192.168.43.1:7777`), allowing 1-tap manual connect.

---

## 3. Multiplayer Game Modes

### Mode 1: Turn-Based Golf Duel (Stroke Play)
* **Players:** 2 players (Head-to-Head).
* **Match Format:** 3 to 5 courses in succession.
* **Gameplay Loop:**
  1. Player 1 takes aim. Both players see Player 1's real-time aim line and slingshot power meter.
  2. Player 1 launches their ball. The camera tracks Player 1's ball as it ricochets.
  3. When Player 1's ball stops or clears the hole, turn token passes to Player 2.
  4. Player 2 shoots from the tee.
  5. The player who clears the course in fewer strokes wins the hole. Lowest cumulative strokes at the end of the match wins the trophy.

### Mode 2: Simultaneous Ghost Race (Speedrun)
* **Players:** 2 to 4 players.
* **Match Format:** Real-time speed race across each level.
* **Gameplay Loop:**
  1. Both players start at the tee simultaneously (3.. 2.. 1.. GO!).
  2. Players can aim and shoot freely at their own pace without waiting.
  3. Opponent balls are rendered as **glowing translucent "ghosts"** in distinct player colors (e.g. Neon Cyan vs. Warm Gold) with a trailing light ribbon and player nametag.
  4. First player to cross the finish line triggers a 10-second countdown for remaining players to finish.
  5. **Scoring:** Points awarded for placement (1st = 1000pts, 2nd = 700pts), minus 50pts per extra shot, plus 100pts per diamond collected.

### Mode 3: Ricochet Sumo (Versus Bumper Bounce)
* **Players:** 2 players on an arena course.
* **Mechanics:**
  * Physical collision enabled between player balls!
  * Colliding with an opponent transfers kinetic energy using elastic 2D momentum (`m1*v1 + m2*v2`).
  * Knock your opponent into wall traps or steal diamonds out from under their trajectory!

---

## 4. Technical Protocol & Port Specification

The game utilizes the **Godot WebRTC Native GDExtension (`addons/webrtc_native`)** providing hardware-optimized P2P data channels with built-in NAT traversal (STUN + local host ICE candidates) and automatic ENet fallback:

| Protocol | Port | Direction | Purpose | Reliability |
|---|---|---|---|---|
| **WebRTC DataChannel** | Dynamic (ICE) | Host ↔ Client | Gameplay State & RPCs (Reliable & Unreliable) | DTLS / SCTP |
| **TCP** | `7779` | Client ➔ Host | Local WebRTC SDP Offer/Answer & ICE Signaling | Reliable TCP |
| **UDP** | `7778` | Host ➔ Subnet | LAN Room Discovery Beacon | Unreliable Broadcast |
| **UDP (Fallback)** | `7777` | Host ↔ Client | ENet Multiplayer Fallback Backend | Reliable + Unreliable |

### 4.1 Discovery Beacon Packet (JSON)
Broadcasted by the host every 0.8 seconds:
```json
{
  "app": "post_bounce",
  "version": "1.0",
  "name": "Alex's Match",
  "players": "1/2",
  "port": 7777,
  "webrtc": true
}
```

### 4.2 WebRTC Local Signaling Protocol (Port 7779)
1. **Join Handshake:** Client connects to Host's TCP signaling server and sends `{"type": "join", "id": 2, "name": "Player 2"}`.
2. **SDP Offer/Answer:** Host initializes `WebRTCPeerConnection`, adds peer to `WebRTCMultiplayerPeer`, creates an SDP offer, and sends `{"type": "offer", "sdp": "..."}`. Client receives offer, sets remote description, and returns `{"type": "answer", "sdp": "..."}`.
3. **ICE Candidates:** Both peers exchange candidate packets `{"type": "candidate", "media": ..., "index": ..., "name": ...}`.
4. **DataChannel Activation:** Once WebRTC connects, `multiplayer.multiplayer_peer` seamlessly drives all `@rpc` calls without further signaling.

---

## 5. State Synchronization & Physics Architecture

### 5.1 Deterministic Simulation vs. Periodic Correction
Since Moonlit Ricochet features deterministic physics constants (`PhysicsConstants.gd`), transmitting raw 60 Hz position packets is wasteful and jittery over Wi-Fi. Instead, we use an **Event-Driven Simulation with 20 Hz Transform Smoothing**:

1. **Launch Event (Reliable RPC):**
   ```gdscript
   @rpc("any_peer", "call_local", "reliable")
   func rpc_launch_ball(peer_id: int, origin: Vector2, dir: Vector2, speed: float, timestamp: int)
   ```
   Both the local and remote clients spawn/launch the ball with the identical trajectory.

2. **Periodic Drift Correction (Unreliable RPC, 20 Hz while moving):**
   ```gdscript
   @rpc("authority", "call_remote", "unreliable_ordered")
   func rpc_sync_ball_transform(peer_id: int, pos: Vector2, vel: Vector2)
   ```
   If a client's ball position differs by more than 4 pixels due to float precision or timing differences, it smoothly lerps to the authoritative position.

3. **Collision & Diamond Pickup Events (Reliable RPC):**
   Authority peer validates finish line crossings and diamond pickups to prevent race conditions.

---

## 6. Implementation Architecture & Script Layout

```
post-bounce/
├── scripts/
│   ├── network/
│   │   ├── network_manager.gd     # Autoload: ENet server/client lifecycle & player roster
│   │   ├── lan_discovery.gd       # UDP broadcast beacon & gateway scanner
│   │   └── mp_game_controller.gd  # Turn manager & score synchronizer
│   ├── prefabs/
│   │   └── ghost_ball.gd          # Opponent ball representation with nameplate & trail
└── scenes/
    ├── multiplayer_lobby.tscn     # Room creation, LAN browser & direct IP entry
    └── multiplayer_match.tscn     # Arena wrapper instantiating course + sync balls
```

### 6.1 `NetworkManager.gd` Core Contract (GDScript Reference)

```gdscript
extends Node

signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal server_disconnected()
signal match_started()

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4

var peer: ENetMultiplayerPeer
var players: Dictionary = {} # peer_id -> {name, color, score, shots}

func host_game(player_name: String, port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	players[1] = {"name": player_name, "color": Color("#88ddaa"), "ready": true}
	return OK

func join_game(ip: String, player_name: String, port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
		
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func():
		rpc_id(1, "register_player", player_name)
	)
	multiplayer.server_disconnected.connect(func():
		server_disconnected.emit()
	)
	return OK

@rpc("any_peer", "reliable")
func register_player(player_name: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	players[id] = {"name": player_name, "color": Color("#fae366"), "ready": false}
	# Broadcast updated roster to all clients
	rpc("sync_player_roster", players)

@rpc("authority", "call_local", "reliable")
func sync_player_roster(roster: Dictionary) -> void:
	players = roster
```

---

## 7. Edge Cases & UX Guidelines

1. **Host Departure / Disconnect:**
   * If the host disconnects, the match displays a polite popup: *"Host has ended the match"* and returns players to the Lobby.
2. **Wi-Fi Dropouts & Reconnect:**
   * If packets stall for > 3.0 seconds, HUD displays an amber *"Reconnecting..."* badge while maintaining physics state.
3. **Cross-Platform Compatibility:**
   * A mobile player (Android/iOS) can play against a PC/Laptop player seamlessly since ENet uses standard BSD UDP sockets.
4. **QR Code Quick Join (Recommended Mobile Polish):**
   * Host screen displays a generated QR Code containing `postbounce://join?ip=192.168.43.1&port=7777`. Joining player scans it with their phone camera to connect in one second.

---

## 8. Implementation Roadmap

| Phase | Milestone | Deliverables |
|---|---|---|
| **Phase 1** | **Discovery & Handshake** | `LanDiscovery` UDP broadcaster & scanner; Direct IP fallback |
| **Phase 2** | **Lobby & Roster** | In-lobby chat/readiness; customizable ball hues and avatars |
| **Phase 3** | **Turn & Race Sync** | Golf duel stroke engine & ghost ball simultaneous interpolation |
| **Phase 4** | **Mobile Optimization** | Hotspot AP isolation test, battery-conscious sleep modes |
