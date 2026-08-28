# Setting Up a Network Game

This guide walks two players through hosting and joining an *Armada*
network game. Both Macs must already have the app installed (either the
exported `Armada.app` or a development build run from the Godot editor).

- **Same home network (LAN)?** Follow §1–§11 below.
- **Different locations over the internet?** Follow
  [§12 — Playing Over the Internet with Tailscale](#12-playing-over-the-internet-with-tailscale)
  first to create a private virtual network, then use §5–§9 as normal.

For build, export, and release packaging, see
[release_ops.md](release_ops.md).

---

## 1. Before You Start

Confirm all of the following on **both** Macs:

- The same version of the app is installed (matching commit / DMG).
- Both Macs are connected to the **same Wi-Fi or Ethernet network**.
  - Tip: a 5 GHz Wi-Fi network and a 2.4 GHz network on the same router
    usually share a subnet, but some routers separate "Guest" networks —
    avoid the guest SSID.
- Router **client isolation / AP isolation** is **off**. (Most home
  routers ship with this off.)
- macOS **Personal Hotspot** is off on both machines (it overrides the
  Wi-Fi route).
- Decide who hosts. The **host** runs the game server in-process; the
  **client** connects to it. Either Mac can be host.

---

## 2. Pick a Port

The default ENet port is **`7350`**. Use it unless something else on
your network already uses it. If you need to change it, both players
must use the same number, in the range **1–65535** (avoid 0–1023).

---

## 3. Find the Host's LAN IP

On the **host** Mac, open **Terminal** and run **one** of these:

```bash
ipconfig getifaddr en0   # Wi-Fi on most Apple Silicon Macs
ipconfig getifaddr en1   # Wi-Fi on some Intel Macs / wired-then-wifi setups
```

You should see something like `192.168.1.42` or `10.0.0.7`.

If both commands return nothing, run:

```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

and pick the address that matches your home subnet
(`192.168.x.x`, `10.x.x.x`, or `172.16–31.x.x`).

Write down the host's IP — the client will type it in.

> The host can also see this IP inside the app: it is shown as
> *“Hosting on `<IP>`:`<port>`”* on the lobby screen once the host has
> created a lobby.

---

## 4. Allow Incoming Connections on the Host

macOS blocks unknown incoming connections by default.

1. **System Settings → Network → Firewall**.
2. If the firewall is **off**, you can skip the rest of this section.
3. If it is **on**:
   - Open **Firewall Options…** (or **Options…**).
   - Either:
     - Add `Armada.app` to the list and set it to **Allow incoming connections**, or
     - Launch the app and click **Allow** on the first prompt that appears.

The client Mac does **not** need a firewall change — it only initiates
outgoing connections.

---

## 5. Host the Game

On the **host** Mac:

1. Launch *Armada*.
2. From the main menu, click **Host Game**.
3. Fill in:
   - **Your Name**
   - **Lobby Name** (optional)
   - **Password** (optional — leave blank for an open lobby)
   - **Port** — defaults to `7350`; change only if you picked a
     different port in §2.
4. Click **Host**.

The lobby screen opens with:

- *“Hosting on `<your LAN IP>`:`<port>`”* — share this line with the
  other player.
- A diagnostics row: *State: LOBBY | Role: SERVER | Peers: 0 |
  Protocol v4*. Peers will increase to 1 once the client connects.

---

## 6. Join the Game

On the **client** Mac:

1. Launch *Armada*.
2. From the main menu, click **Join Game**.
3. Fill in:
   - **Your Name**
   - **Server IP** — the host's LAN IP from §3.
   - **Password** — only if the host set one.
   - **Port** — must match the host's port (default `7350`).
4. Click **Connect**.

On success the client lands in the same lobby screen as the host. The
diagnostics row shows *Role: CLIENT | Peers: 1*. The host's diagnostics
row updates to *Peers: 1* as well.

---

## 7. Start Playing

1. Both players click **Ready** in the lobby.
2. For a new match, the host clicks **Start Game**.
3. The board scene loads on both Macs and play begins.

---

## 8. During the Game

- Each player only controls their own ships and squadrons; modal
  prompts appear only on the player who needs to act.
- The host's machine is the source of truth.
- All commands are deterministic: a replay file is written on both
  Macs and they should match.

### Save and resume a Network match

> **Architecture update (2026-08-27):** Fresh-session Network resume no
> longer requires a resume credential or proof that the same human returned.
> Credential-based MATCH-002 controls still present in the current working tree
> are transitional implementation evidence, not the accepted product workflow.
> Treat fresh-session resume as unavailable until the replacement assignment
> flow is implemented and accepted.

#### Save while the match is live

Only the host sees **Save Game** and **Load Game** in the in-game menu. The
host opens the menu, chooses **Save Game**, enters a name, and clicks **Save**.
The host can also use the Network **Resume Last Checkpoint** entry later. The
save stays on the host; the other player receives a save notification but does
not receive a copy of the save file.

#### Load in the same live match versus resume in a new session

**Same live match.** While the original Network match is still running, the
host may use **Load Game** to load an earlier save/checkpoint from that same
match. This retains the existing association rules: the saved player binding
must exactly match the live match and its existing players must still be
associated. It is not a new-session resume and does not reassign players.

**Fresh session.** Once the Network session has ended, the accepted requirement
is to stage the save and explicitly assign the connected humans to the two
saved player sides before the board becomes live. Either human may control
either saved side. The assignment must not be inferred from host/client role,
lobby order, player name, profile, or peer ID.

#### Accepted fresh-session resume flow

1. The host creates a lobby and the other participant joins.
2. The host selects the Network save or checkpoint. The restored game remains
   staged and is not yet playable.
3. The host explicitly assigns itself and the connected participant to the two
   saved player sides. The host can choose either side.
4. The game checks that every saved side and every participating endpoint
   appears exactly once. Missing, duplicate, or competing assignments block
   publication.
5. Each endpoint receives only the view allowed for its assigned side and
   acknowledges the restored state.
6. Only then does the board become live. The canonical player identities and
   saved player-to-principal binding are unchanged; only the current-session
   human controllers are new.

A different person may take either saved side. No credential transfer or proof
of being the original player is required by the accepted architecture.

#### Reconnect to a still-live match

If a player disconnects but the host remains live, reconnect to that same host
with **Join Game**. The host waits for the old association to be confirmed
gone, explicitly assigns the now-unoccupied side to the connected endpoint,
and sends that side's filtered current state. The host does not reload the save
or restart the match. Input for that side remains unavailable until the
reconnecting device has installed and acknowledged the current state.

Do not try to reconnect before the disconnect has been confirmed. If two
endpoints would be assigned to the same side while one is still associated,
the new assignment is rejected and the incumbent stays in control.

#### Two-player example

1. Ada hosts, Bo joins, both press **Ready**, and Ada presses **Start Game**.
2. Ada and Bo play. Ada opens the in-game menu, chooses **Save Game**, names
   the save, and presses **Save**.
3. They both close the Network session.
4. Later, Ada starts **Host Game** and Bo uses **Join Game**.
5. Ada chooses **Load Game**, selects the Network save, and presses **Load**.
6. Before publication, Ada explicitly chooses which saved side she will
   control and assigns Bo to the other side. They may swap the sides they
   controlled in the original session.
7. Once both installations acknowledge their correctly filtered restored
   state, they continue from the saved next decision.

#### Restrictions and compatibility

- Save portability is separate from side assignment. Removing credentials does
  not make a copied save valid on another installation. Until portability is
  separately decided and implemented, use the original save-owning
  installation.
- Missing, duplicate, incomplete, or competing assignments fail closed: no
  partial board is published, no side is inferred, and no saved player mapping
  changes.
- Hot-Seat saving/loading is unchanged. It can still be loaded from the main
  menu; it cannot be loaded from a Network lobby or during a Network session.
- Cross-host/cloud save portability, active-controller takeover,
  absent-player continuation, shared control, and bot substitution are not
  part of this decision.

#### Current UI limits

The accepted assignment workflow is not implemented or manually accepted yet.
The current working tree may still show credential-related controls and status
such as **Resume Capabilities**, **Import Capability**, or **Waiting for
entitlement**. Those belong to the superseded MATCH-002 design and should not be
treated as the final fresh-resume UX.

---

## 9. Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Client cannot connect, error toast appears immediately | Wrong IP or port, or host not listening | Re-check the host's lobby line "Hosting on …"; make sure ports match. |
| Client hangs on "Connecting…" | macOS firewall blocking host, or different subnets | Allow `Armada.app` in System Settings → Network → Firewall on host; verify both Macs are on the same Wi-Fi SSID (not the Guest one). |
| Both Macs on same Wi-Fi but still no connection | Router AP / client isolation, or VPN active on one Mac | Disable AP isolation in the router admin page; turn off any VPN on either Mac. |
| Lobby connects but "Peers: 0" persists | Heartbeat lost (sleep / Wi-Fi handoff) | Wake the host Mac; if Wi-Fi roamed, leave and rejoin from the client. |
| Host sees "(no LAN IP)" in lobby | No active LAN interface (Wi-Fi off, Ethernet unplugged) | Connect to Wi-Fi or plug in Ethernet, then re-host. |
| "Invalid port (1–65535)" toast | Empty or out-of-range port field | Re-enter a valid number; default is `7350`. |
| Both connect but ships look out of sync | Mixed app versions | Re-install identical builds on both Macs. |
| Network save is shown as not resumable | The accepted explicit-assignment flow is not implemented, the save is unsupported, or the save is on a foreign installation | Use same-live-match load where applicable. Treat fresh-session resume as unavailable until the replacement flow is implemented and accepted. |
| **Waiting for entitlement** / capability controls appear | The current working tree still contains the superseded MATCH-002 credential workflow | Do not rely on that workflow as the accepted product behavior. No credential is required by the amended architecture. |
| Reconnect assignment is rejected | The old endpoint is still associated, disconnect is not confirmed, or the side already has a controller | Keep the incumbent or wait for confirmed association loss before explicit reassignment. |

---

## 10. Quick Reference

| Item | Value |
|---|---|
| Default port | `7350` |
| Required ports open on host | `7350/UDP` (or your custom port) |
| Network protocol | ENet over UDP, protocol 4 |
| Required machines | 2 Macs on the same LAN subnet |
| Session save | Host machine only, under `saves/` |
| Fresh-resume authority | Explicit host assignment of each connected human to one saved side before publication; implementation pending |

---

## 11. Where Are My Saves and Logs?

The location depends on whether you run the IDE build or a packaged
`.app`:

| Build | Saves | Replays | Logs |
|---|---|---|---|
| Godot editor / source | `<project>/saves/` | `<project>/replays/` | `<project>/logs/` |
| Packaged `.app` (DMG) | `~/Library/Application Support/Armada/saves/` | `~/Library/Application Support/Armada/replays/` | `~/Library/Application Support/Armada/logs/` |

The packaged build cannot write inside the `.app` bundle (it is
read-only and signed), so the app automatically falls back to the
per-user folder above. Open it in Finder with
**Go → Go to Folder…** and paste the path.

To enable file logging on a packaged build, launch the app from
Terminal so you can pass the flag:

```bash
open -a "/Applications/Armada.app" --args -- --logging
```

The log file will appear in `~/Library/Application Support/Armada/logs/`.

---

## 12. Playing Over the Internet with Tailscale

Tailscale is a free mesh VPN built on WireGuard. It lets two Macs on
different home networks (or different continents) appear on the same
private subnet — so the normal LAN host/join flow works without port
forwarding or exposing any ports to the public internet.

Tailscale requires **macOS Monterey 12.0 or later**.

### 12.1 Why Tailscale?

- **No router configuration.** Tailscale handles NAT traversal
  automatically. Neither player needs to touch their router settings.
- **Encrypted traffic.** All game traffic travels through an encrypted
  WireGuard tunnel, not over the open internet.
- **Stable addresses.** Each device gets a permanent `100.x.y.z`
  Tailscale IP that doesn't change when the device switches networks.
- **Free for personal use.** The Personal plan is free for a single user with up to 100 devices.

### 12.2 One-Time Setup (both players, ~5 minutes each)

Do this once. You only need to repeat it if you get a new computer.

#### Step 1 — Install Tailscale

On each Mac, download the **Standalone variant** (recommended) from:

```
https://pkgs.tailscale.com/stable/#macos
```

Alternatively, search for **Tailscale** in the Mac App Store (free).

Minimum requirement: macOS Monterey 12.0.

After installation, Tailscale appears as a menu bar icon (a white or
grey icon that looks like a wireframe cube).

#### Step 2 — Create or sign into a Tailscale account

One player (the **tailnet owner**) creates a free Personal account at
`https://tailscale.com`. They can log in with Google, GitHub, Apple ID,
or another supported identity provider. No credit card required.

The other player can use their own separate Tailscale account — they
do **not** need to join the owner's tailnet. Both players simply need
Tailscale installed and signed in to any account.

#### Step 3 — Turn on Tailscale

Click the Tailscale menu bar icon and select **Connect** (or it
connects automatically on launch).

The icon turns blue (or solid) when connected. Your Tailscale IP
(`100.x.y.z`) appears in the menu.

To see your IP at any time:

```bash
tailscale ip -4
```

### 12.3 Before Every Play Session

Both players must have Tailscale running and connected before launching
*Armada*. Confirm with:

```bash
tailscale status
```

You should see both your own device and be able to ping the other player's
Tailscale IP:

```bash
ping -c 3 <other-player-tailscale-ip>
```

A response with round-trip times under ~200 ms means the tunnel is healthy.

### 12.4 Find the Host's Tailscale IP

The **host** player finds their Tailscale IP in one of three ways:

1. **Menu bar** — Click the Tailscale icon; your `100.x.y.z` IP is
   shown at the top of the menu.
2. **Terminal:**
   ```bash
   tailscale ip -4
   ```
3. **Admin console** — Visit `https://login.tailscale.com/admin/machines`
   and look for your machine name.

Share this `100.x.y.z` IP with the other player via chat, message, or
voice. Keep it private — only share it with your intended opponent.

### 12.5 Host the Game

Hosting over Tailscale is identical to the LAN flow:

1. Launch *Armada*.
2. From the main menu, click **Host Game**.
3. Fill in your name, optional lobby name and password, and confirm the
   port (default `7350`).
4. Click **Host**.

The lobby screen shows *"Hosting on `<Tailscale IP>`:`7350`"*.
Share that line with the other player.

> **Firewall note:** macOS may prompt to allow incoming connections
> when the first internet client connects via Tailscale. Click **Allow**
> (or pre-allow `Armada.app` in System Settings → Network → Firewall).
> The client Mac does not need any firewall change.

### 12.6 Join the Game

On the **client** Mac:

1. Launch *Armada*.
2. From the main menu, click **Join Game**.
3. Fill in:
   - **Your Name**
   - **Server IP** — the host's Tailscale IP (`100.x.y.z`).
   - **Password** — only if the host set one.
   - **Port** — default `7350`.
4. Click **Connect**.

On success the lobby screen appears and both diagnostics rows show
*Peers: 1*.

### 12.7 Quick Reference — Tailscale Internet Play

| Item | Value |
|---|---|
| Host's address to share | Tailscale IP, e.g. `100.64.0.1` |
| Default port | `7350/UDP` |
| Port forwarding required | **No** |
| Router changes required | **No** |
| Encryption | WireGuard (end-to-end) |
| Tailscale free plan | Free for personal use, 1 user, 100 devices |
| macOS requirement | Monterey 12.0+ |
| Download | `https://tailscale.com/download/macos` |

### 12.8 Troubleshooting — Tailscale

| Symptom | Likely Cause | Fix |
|---|---|---|
| `tailscale status` shows no peers | Tailscale not connected on one Mac | Click the menu bar icon and select **Connect**; check that you are signed in. |
| `ping 100.x.y.z` times out | Tailscale not connected on the target Mac | Confirm both Macs show a blue/active Tailscale icon before launching Armada. |
| Client gets "Connecting…" forever | Firewall blocking the host | On host: System Settings → Network → Firewall → allow `Armada.app` for incoming connections. |
| Tailscale icon shows "Logged out" | Session expired | Click the icon, select **Log in**, and reauthenticate. |
| Ping works but game fails to connect | Wrong IP entered | Double-check the host's Tailscale IP with `tailscale ip -4`; it must start with `100.`. |
| High latency / lag during play | Long relay route | Both players close and reopen Tailscale to re-attempt a direct peer connection; run `tailscale netcheck` for diagnostics. |
| "Both Macs on same Wi-Fi but still no connection" note in §9 | Active Tailscale interferes with LAN detection | For LAN play: turn Tailscale off on both Macs and follow §1–§9 with the LAN IP instead. |
