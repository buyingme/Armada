# Setting Up a Network Game — Two Macs on the Same Home Router

This guide walks two players through hosting and joining an *Armada*
network game on a home network. Both Macs must already have the app
installed (either the exported `Armada.app` or a development build run
from the Godot editor).

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
  Protocol v1*. Peers will increase to 1 once the client connects.

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
2. The host clicks **Start Game** (or **Load Game** to resume a
   previous network save).
3. The board scene loads on both Macs and play begins.

---

## 8. During the Game

- Each player only controls their own ships and squadrons; modal
  prompts appear only on the player who needs to act.
- The host's machine is the source of truth. If it crashes or quits,
  the session ends. (Reconnect is a planned feature; not yet
  available.)
- All commands are deterministic: a replay file is written on both
  Macs and they should match.

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

---

## 10. Quick Reference

| Item | Value |
|---|---|
| Default port | `7350` |
| Required ports open on host | `7350/UDP` (or your custom port) |
| Network protocol | ENet over UDP |
| Required machines | 2 Macs on the same LAN subnet |
| Session save | Host machine only, under `saves/` |

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
