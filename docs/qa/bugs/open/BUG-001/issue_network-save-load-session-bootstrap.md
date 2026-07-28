# NOTE-001 – Network Save/Load Session Bootstrap Investigation

**Status:** Open
**Priority:** Medium (deferred until current Slice 8A gameplay fix is complete)

## Summary

A potential defect was observed when starting a **network game from a saved game**.

The restored session appears to behave as if it were a **Hot Seat** game rather than an active network session.

This investigation is intentionally deferred while completing the current Slice 8A presentation ownership fix.

---

## Observed Symptoms

After loading a saved game and continuing in network mode:

- The game log identifies the session as **Hot Seat**.
- Only a single game log is generated.
- Dedicated **host** and **client** logs are not created.
- No replay file is generated.
- The session may not have fully restored its network runtime context.

---

## Initial Hypothesis

The gameplay state may restore correctly, but the **network session bootstrap** does not.

Possible missing restoration includes one or more of:

- Network session mode
- Host/client role
- Logging initialization
- Replay recording initialization
- Network-specific runtime services
- Session metadata

This appears independent of the current presentation ownership bug.

---

## Open Questions

1. Is the session actually running in Hot Seat mode, or is only the logging/replay infrastructure initialized incorrectly?

2. Are host/client networking services fully restored after loading?

3. Is replay recording intentionally disabled after loading, or is initialization skipped?

4. Does loading bypass the normal network game startup path?

5. Which subsystem should own restoration of:
   - network mode
   - replay recording
   - logging configuration
   - session metadata

---

## Deferred Investigation

Perform a dedicated forensic audit after the current Slice 8A presentation ownership correction has been completed and validated.

Suggested investigation order:

1. SaveGameManager
2. GameManager session restoration
3. NetworkManager initialization
4. ReplayDriver initialization
5. Logging initialization
6. Network startup sequence versus load-from-save sequence

---

## Expected Behaviour

Loading a saved network game should restore a session that is operationally equivalent to one started normally.

Specifically:

- Network mode remains active.
- Host/client roles are preserved.
- Host and client logs are generated.
- Replay recording resumes correctly.
- Diagnostic output identifies the session as a network game.
