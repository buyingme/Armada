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
