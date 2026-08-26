# MATCH-002: Network Match Resume and Principal Reassociation Implementation Workbook

Status: Accepted; implementation-ready
Accepted by: Project Owner
Accepted date: 2026-07-26

before implementation

Date: 2026-08-26

Purpose: define the smallest coherent implementation cutover that restores a
current-format Network save in a fresh Network session on the original
save-owning host installation and reassociates entitled endpoints with the
unchanged saved HUMAN principals.

This workbook changes no production code, tests, accepted architecture, or
requirements. It authorizes no implementation until accepted.

## 1. Classification, Authority, And Entry Result

Classification: **Bounded Architecture**. Accepted ADR-011 fixes entitlement,
participation, exclusivity, portability, and publication behavior. The current
repository contains the canonical binding, save/load, Network admission,
association, state-filtering, installation, and decision-recovery seams needed
for the bounded MVP. No new Owner decision or general session/identity owner is
required.

Normative authority, in precedence order:

- accepted [ADR-011](../adr/ADR-011-network-match-resume-and-principal-entitlement.md);
- accepted [ADR-008](../adr/ADR-008-durable-match-lifetime-player-principal-binding.md)
  and accepted [MATCH-001](MATCH-001-player-principal-binding-implementation-workbook.md);
- accepted [ADR-010](../adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md);
- the accepted authorities that already own canonical gameplay facts,
  command application, save integrity, filtering, reconstruction, and
  presentation recovery; and
- repository governance in [DOCUMENT_AUTHORITY](../DOCUMENT_AUTHORITY.md),
  [CODEX_WORKFLOW](../CODEX_WORKFLOW.md), and the
  [Architecture Roadmap](../ARCHITECTURE_ROADMAP.md).

[ODR-003](../decision_workbooks/ODR-003-network-match-resume-and-replacement-principal-entitlement.md)
was consulted only for historical Owner rationale and its implementation-evidence
inventory. All downstream requirements in this workbook derive from ADR-011
and the other accepted authority above.

ADR-011 records Accepted status, Project Owner acceptance, and an acceptance
date of 2026-08-26. Its stale Draft Note was corrected as a separate governance
metadata change before this workbook refinement. This workbook treats ADR-011's
settled decision text as governing and does not reopen, reinterpret, or redesign
it. MATCH-002 remains Draft and requires separate Project Owner acceptance.

Applicable roadmap traceability:

- `BC-006` / `RG-007`: no new `GameManager` responsibility category;
- `BC-007` / `AT-008` / `RG-013`: Network distribution and reconnect evidence;
- `BC-008` / `AT-009` / `RG-016`: save/load, compatibility, and documentation
  evidence.

### 1.1 Entry gates

| Gate | Result | Evidence and required posture |
| --- | --- | --- |
| Exact canonical reconstruction exists | **PASS** | `SaveGameManager.load_game*()` verifies current format and installation-local HMAC, deserializes `GameState`, restores the command cursor, and reconciles timing state before returning a candidate. `GameManager.start_new_game_from_state()` repeats live validation before publication. Reuse both; entitlement never repairs canonical state. |
| Durable identity is already canonical | **PASS** | `GameState` owns `match_player_control_binding`; `MatchPlayerControlBinding` is immutable and serialized. No MATCH-002 path may create, replace, or rebind a saved principal. |
| Transient associations already have the correct owner | **PASS** | `NetworkManager` stores `_host_match_principal_id` and peer `match_principal_id`, removes peer records on confirmed disconnect, and checks the association before remote or host player-originated command admission. Extend this owner; do not create a participant aggregate. |
| Existing same-live-match load can remain intact | **PASS** | `NetworkManager.can_install_loaded_binding()` and `LobbyManager.host_load_save()` already permit only `IN_GAME`, exact-binding, still-associated loads. Preserve this path as a separate branch. |
| Fresh-session state can be staged without publication | **PASS** | The load UI already returns a fully validated candidate before `host_load_save()`. `LobbyManager` already orchestrates host/client load distribution. Hold a purpose-specific pending resume candidate there; do not call `GameManager.start_new_game_from_state()` until the complete entitlement/distribution gate passes. |
| Filtered client reconstruction exists | **PASS** | `StateFilter.filter_for_player()` -> `GameState.deserialize()` -> `UIProjector.project()` is covered today. Use per-associated-player filtered staging snapshots instead of treating the current full-state load broadcast as the new resume pattern. |
| Decision-equivalent recovery exists at canonical seams | **PASS** | Current save/load and production-resume tests restore command cursor, timing/current-attack/activation facts, and re-derive presentation. MATCH-002 must prove those same seams after entitlement, without originating gameplay commands on passive peers or replay. |
| A secure-enough bounded capability mechanism is selectable downstream | **PASS** | Godot supplies local key generation, public-key signing/verification, secure random bytes, and the repository already supplies HMAC integrity helpers and local per-install storage patterns. A match-scoped key capability avoids transmitting a reusable bearer secret and does not require accounts, identity providers, or cross-host trust. |
| Ordinary reconnect has a production snapshot transport | **GAP CLOSED BY MATCH-002 SCOPE** | The current transport accepts handshakes and drops associations on disconnect, but has no production reassociation/snapshot RPC. Adding one entitlement-gated, filtered snapshot path to `NetworkManager` is necessary and bounded. |

**Overall entry result: PASS.** The missing behavior is authorized
implementation work, not an unresolved architecture decision. Section 14
remains a mandatory stop gate during implementation.

## 2. Selected MVP Strategy

Implement MATCH-002 as a narrow extension of the current Network load and
command-admission boundaries:

1. Give each newly created Network HUMAN principal one independently generated,
   match-scoped asymmetric key capability.
2. Keep the private key only in the capability holder's local protected
   credential store or in a deliberate user export. Persist only that
   principal's public verifier in the original host installation's protected
   resume registry.
3. Identify one match's entitlement set by a deterministic, non-secret
   fingerprint of the complete canonical serialized
   `match_player_control_binding`. The fingerprint is a lookup/correlation key,
   never proof.
4. Prove possession by signing a fresh host nonce bound to the operation,
   match fingerprint, existing principal ID, and current endpoint/attempt. The
   host validates the signature against its stored public verifier.
5. Route both fresh-session resume and ordinary reconnect through one validator
   and one exclusive-association operation.
6. For fresh resume, stage the candidate, claims, per-peer filtered snapshots,
   and client readiness before installing or publishing any live state.
7. Commit the complete association set with command admission closed, install
   canonical host state at the publication linearization point, then require
   every client installation acknowledgement before enabling admission. Any
   pre-linearization failure discards the attempt and leaves the prior live
   state and associations unchanged.
8. After every publishing endpoint has acknowledged installation, enable the
   existing association-aware player-originated command admission and preserve
   existing canonical gameplay validators unchanged.

This is a capability system, not physical-person authentication. Deliberately
transferring the private-key export lets its recipient assume the same saved
principal. It does not modify `GameState`, the binding, principal kind, or the
gameplay player mapping.

### 2.1 Why asymmetric proof is selected

The selected implementation choice uses one 2048-bit RSA key pair per principal,
generated through Godot's built-in `Crypto.generate_rsa(2048)` API. It SHALL use
the exact SHA-256 hashing and signature contract in Section 4.1, including the
engine requirement that `Crypto.sign()` and `Crypto.verify()` receive the
already-computed SHA-256 digest rather than unhashed challenge bytes. A
repository-local Godot 4.5.1 probe confirmed private-key generation,
public-only key export/import, signing, and public-key verification; the probe
was not retained as a production or test file. Section 12 requires persistence,
freshness, replay-resistance, restart, reassociation, and real transport evidence
in addition to this isolated primitive probe.

This choice is downstream implementation detail permitted by ADR-011. It is
preferred over a pasted bearer token on the wire because:

- the reusable private capability never crosses the Network transport;
- the original host needs only non-secret verifier material;
- public verifier distribution cannot authorize a claimant;
- nonce-bound proof is not replayable in another attempt or session; and
- capability transfer remains possible by deliberate private-key export.

Do not implement certificate authorities, accounts, identity providers,
password recovery, key rotation, revocation, expiry, or portable host trust.
If the target Godot version cannot produce and verify the selected proof using
its built-in APIs without an external key-management framework, stop under
Section 14 rather than falling back to a bearer secret, lobby identity, or host
choice.

## 3. Ownership And Responsibility Map

| Responsibility | Existing/selected owner | Required MATCH-002 behavior | Explicit non-owner |
| --- | --- | --- | --- |
| Canonical gameplay state and immutable player-principal binding | `GameState` / `MatchPlayerControlBinding` | Restore and validate byte/semantic equality through existing serialization and installation APIs. No new field or mutator. | Credential store, lobby, peer record, UI |
| Save envelope, installation-local integrity, cursor, timing reconciliation | `SaveGameManager` / `SaveGameMetadata` | Keep current version-5 payload and verification order. Return the validated candidate; expose a read-only resumability result derived from the separate host registry where the UI needs it. | Entitlement validator, `GameManager` |
| Local capability and host verifier persistence | New narrow `MatchPrincipalEntitlementStore`, owned as a helper by `NetworkManager` | Generate/import/export private capabilities; persist local private keys; persist the original host's exact binding fingerprint and per-principal public verifiers; HMAC-protect local records; fail closed on corruption. All UI/bootstrap access is through narrow `NetworkManager` façade methods. | `GameState`, save body/header, replay, `PlayerProfile`, UI |
| Entitlement challenge validation and exclusivity | `NetworkManager` | Issue one-use challenges, validate proof, stage/commit peer-to-existing-principal associations, reject competition, clear associations on confirmed disconnect, and enforce them at command admission. | Claimant, UI, lobby slot, `GameManager` |
| Fresh-resume candidate and two-phase publication orchestration | `LobbyManager` | Hold one purpose-specific pending candidate/metadata/cursor, coordinate claims, staging and installation acknowledgements through `NetworkManager`, call existing live installation only at commit, and discard pre-publication attempts on failure/cancel. | `GameState`, generic session framework |
| Live canonical installation | `GameManager.start_new_game_from_state()` | Reuse unchanged. Repository evidence shows that it validates before mutation, installs through the existing canonical seam, restores the cursor, and emits the existing publication event. | `LobbyManager` staging fields, UI |
| Per-client canonical distribution | `NetworkManager` with unchanged `StateFilter` | Send each associated peer only its authorized filtered candidate, with scenario/cursor and non-secret association assignment; receive staging acknowledgement before publication and installation acknowledgement before command-admission enablement. | Capability store, presentation callbacks |
| Viewer presentation and bootstrap | `GameBoard`, `UIProjector`, existing preloaded-state flow | Rebuild from the installed state and reassociated local player. No presentation-driven claim, legality, or progression. | Capability dialog, lobby labels |
| Resume/load/capability UI | `LoadGameDialog`, `LobbyRoom`, `MainMenu`, `GameMenuModal`, new narrow capability dialog | Call narrow `NetworkManager` façade methods to stage a Network resume, show entitlement status/errors, import a transferred capability, and deliberately reveal/copy only the local principal capability. UI never constructs or owns the store. | Canonical owner, entitlement validator, entitlement store owner |
| Gameplay legality and progression | Existing `CommandProcessor`, commands, applicability, state owners | Unchanged. A valid association only admits the command to existing validation. | Entitlement proof or association alone |

The helper class is not an autoload, account database, identity service, or
general session owner. `NetworkManager` remains the authoritative host owner of
the helper, validation, current associations, and all UI/bootstrap-facing
entitlement operations. `LobbyManager` remains the existing Network
load/bootstrap coordinator. `GameManager` gains no new responsibility category.

## 4. Capability And Verifier Lifecycle

### 4.1 Representation

Use these purpose-specific concepts:

- `match_fingerprint`: lowercase SHA-256 of canonical JSON for the complete
  serialized `MatchPlayerControlBinding`. It is non-secret and proves nothing.
- `principal_id`: the existing canonical principal label. It is non-secret and
  proves nothing.
- `private_capability`: the RSA private key held by the current capability
  holder. It is the reusable secret and must never enter public state or logs.
- `public_verifier`: the matching public key stored by the original host. It is
  verifier material, not canonical gameplay state.
- `verifier_fingerprint`: SHA-256 of the canonical public-key representation,
  used only for deterministic record comparison and diagnostics that do not
  expose private material.
- `challenge`: at least 256 random bits generated by the authoritative host,
  single-use, and bound to exactly one operation/attempt, match fingerprint,
  principal ID, and endpoint.
- `proof`: the signature over a versioned, domain-separated canonical challenge
  payload. It is transient, is never logged, and is discarded after validation.

The proof contract SHALL be exact and versioned independently of save format:

1. Generate `attempt_id` and `nonce` independently with
   `Crypto.generate_random_bytes(32)` and represent each as exactly 64 lowercase
   hexadecimal characters.
2. Construct a dictionary with exactly these string-valued keys and no others:

   ```text
   domain            = "armada.match-principal-entitlement-proof"
   proof_version     = "1"
   operation         = "fresh_session_resume" | "reconnect"
   attempt_id        = <64 lowercase hexadecimal characters>
   nonce             = <64 lowercase hexadecimal characters>
   match_fingerprint = <64 lowercase hexadecimal characters>
   principal_id      = <39-character canonical existing MATCH-001 principal ID>
   endpoint_id       = <base-10 ENet sender ID in 1..2147483647>
   ```

3. Serialize that exact dictionary with `CanonicalJson.stringify(payload)`.
   The resulting string's UTF-8 bytes are the signing bytes; compute
   `challenge_digest = canonical_json.sha256_buffer()` so Godot hashes that
   UTF-8 representation exactly once.
4. Produce `signature_bytes = Crypto.sign(HashingContext.HASH_SHA256,
   challenge_digest, private_capability)`. Represent the RSA-2048 signature on
   the wire as exactly 512 lowercase hexadecimal characters. The host decodes
   it to exactly 256 bytes and calls
   `Crypto.verify(HashingContext.HASH_SHA256, challenge_digest,
   signature_bytes, public_verifier)`.
5. The challenge response RPC repeats exactly `proof_version`, `operation`,
   `attempt_id`, `nonce`, `match_fingerprint`, `principal_id`, `endpoint_id`, and
   `signature`. The host reconstructs the canonical payload from its own pending
   challenge and rejects any mismatch; client-supplied echoed fields never
   replace host-held values.

Reject before cryptographic work any unknown/missing field, wrong type, invalid
UTF-8, uppercase/non-hex/odd-length encoding, non-canonical endpoint string,
unexpected operation/version, out-of-phase attempt, or field outside its exact
length. `principal_id` must match the existing 39-character canonical
`mp-xxxxxxxx-xxxx-4xxx-[89ab]xxx-xxxxxxxxxxxx` form. `endpoint_id` must match
`[1-9][0-9]{0,9}`, parse without overflow, and be in `1..2147483647`; its parsed
value must equal the transport sender. The fixed domain/version/operation and
the 64-character attempt, nonce, and match-fingerprint fields admit no padding
or alternate representation. Bound public-verifier PEM to 4096 UTF-8 bytes and
a complete private export envelope to 8192 UTF-8 bytes; reject larger RPC,
import, or persisted values. Normalize a public verifier through
`save_to_string(true)` with LF line endings before hashing it, and require
import followed by public-only re-export to reproduce that canonical
representation. These limits are protocol input validation, not entitlement
authority.

The persisted formats SHALL be versioned independently of save format. Strictly
reject unknown versions, unknown fields, duplicate principal records, malformed
keys, binding/verifier mismatch, invalid HMAC, and partial records.

### 4.2 Protected persistence boundary

Add an explicit `PathConfig` location under `user://`, never `res://`, for
Network resume credential data. Tests inject paths under their temporary test
root. Keep these records out of the save directory's public JSON listing and
out of repository fixtures:

1. a local capability vault containing only private capabilities held by this
   installation, keyed by match fingerprint and principal ID; and
2. on a save-owning host, a verifier registry containing the exact serialized
   binding fingerprint and one public verifier for every HUMAN principal.

Protect each persisted envelope with a dedicated installation-local 32-byte
HMAC key, distinct from the save-signing key and generated by
`Crypto.generate_random_bytes(32)`, using the existing
`IntegritySigner` canonicalization/comparison pattern. Do not copy the current
save-signing-key generator, which is an integrity convenience rather than the
cryptographic random source selected here. Use temp-file, flush/close,
validation, and same-directory rename/replace behavior so an interrupted write
leaves either the prior complete record or the new complete record. A missing,
truncated, invalidly signed, malformed, or binding-inconsistent registry is
unavailable entitlement, never an empty or repairable registry. Do not reuse the
save signature or its key as entitlement proof.

For MATCH-002, "protected" means integrity-checked, application-local, excluded
from public saves/replays/logs/UI, and stored under the operating-system user's
private application-data boundary. HMAC does not encrypt the private PEM and
does not protect it from the same OS user, malware running as that user, a
modified executable, or an attacker who copies the complete application trust
directory including its HMAC keys. Copying only a save, registry, or public
verifier does not transfer trust; copying every installation secret is an
installation clone and is outside this MVP's resistance claim. If implementation
or release policy requires same-user extraction resistance, hardware-backed
keys, OS keychain storage, or clone-resistant installation identity, stop under
Section 14 rather than describing this HMAC boundary as confidentiality.

The private capability may be exported only by an explicit user action. The
export is a versioned text envelope containing the match fingerprint, existing
principal ID, public verifier fingerprint, and private key. Import validates
syntax and public/private consistency locally; only the original host's live
challenge verification establishes entitlement. Never include the export in
display labels, clipboard automatically, save metadata, diagnostics, or logs.

Deleting a save, checkpoint, lobby, or transient association SHALL NOT delete,
rotate, revoke, or replace match-scoped capability/verifier records. Automated
credential cleanup, revocation, rotation, expiry, and proof-loss recovery are
deferred. Corrupt or deliberately removed records fail closed.

### 4.3 Initial Network match establishment

Every new non-replay two-human Network match created after MATCH-002 activates
must establish future-resume capability before live publication:

1. Each endpoint independently generates and durably stores one pending private
   capability. The client submits only its public verifier to the host.
2. The host creates the existing two-HUMAN binding through MATCH-001.
3. Initial lobby slots may be used only at this new-match construction boundary
   to pair each endpoint's independently supplied verifier with the newly
   created principal, exactly as MATCH-001 already uses slots for initial
   association. They are not proof for any saved/existing principal.
4. The host persists the exact complete verifier registry, then returns to each
   endpoint its assigned principal ID, match fingerprint, and the exact
   fingerprint of the public verifier stored for that endpoint.
5. Each endpoint recomputes its public verifier from its pending private key and
   rejects unless the returned verifier fingerprint exactly matches both its
   submitted verifier and the host's persisted record. Only then does it finalize
   its private-capability record under the received binding fingerprint and
   principal ID.
6. Each endpoint acknowledges local persistence with that exact verifier
   fingerprint. The host accepts the acknowledgement only from the registering
   sender and only when it equals the persisted registry entry. Only after every
   endpoint has confirmed this end-to-end equality does initial association,
   state creation, config distribution, and `game_started` publication proceed.
7. Missing, duplicated, invalid, mismatched, substituted, or unpersisted material
   aborts new-match startup and clears all pending capability/association state.

Network replay bootstrap is excluded. Replay restores the recorded canonical
binding and accepted command history but creates no live entitlement registry,
private capability, or HUMAN association merely for playback.

### 4.4 Proof validation shared by resume and reconnect

One `NetworkManager` validation operation SHALL serve both flows:

```text
existing canonical binding + original-host verifier registry
  -> host issues fresh endpoint-bound challenge
  -> claimant signs with private capability
  -> host validates challenge freshness/domain/binding/principal/signature
  -> host verifies no active or staged competing association
  -> association is staged or committed for that existing principal
```

The claimant never authorizes itself. A valid signature is insufficient if the
principal is absent from the exact candidate binding, is not HUMAN, the verifier
registry does not match the exact binding, the challenge is stale/reused/wrong
endpoint/wrong attempt, or another endpoint already holds an active/staged
association.

Proof validation does not call gameplay validation and does not mutate
`GameState`. Command admission continues to require both a valid active
association and the existing canonical `principal_controls_player()` check.

## 5. Fresh-Session Resume Lifecycle And Publication Gate

### 5.1 Entry and staging

Reuse the existing host-lobby load UI. A host creates a normal Network lobby on
the original save-owning installation, a second endpoint connects, and the host
selects a Network save. Lobby readiness may permit opening the attempt; it does
not establish any saved-principal entitlement.

`SaveGameManager` performs its complete existing load pipeline first:

```text
current save format
  -> installation-local save HMAC
  -> GameState.deserialize()
  -> exact binding and live-state validation
  -> reconstruction cursor validation
  -> timing-window reconciliation
  -> validated candidate returned, still not live
```

`LobbyManager` then creates one purpose-specific pending resume attempt holding
only the validated candidate, metadata, command cursor, match fingerprint,
expected HUMAN principal IDs, and attempt state. It SHALL NOT replace
`GameManager.current_game_state`, set `is_game_active`, alter active
associations, call `NetworkManager.start_game()`, change scene, emit
`game_started`/`game_starting`, or accept principal-dependent input.

For the current MVP, a resumable Network candidate must have the currently
supported normal Network shape: exactly two distinct HUMAN principals, one per
gameplay player. Structurally valid AUTOMATED shapes remain representable under
ADR-008, but production bot execution and HUMAN/AUTOMATED substitution are not
authorized by ADR-011; such a Network resume remains unsupported rather than
synthesizing a controller.

### 5.2 Claim collection

The host loads the verifier registry for the exact binding and opens one claim
challenge per connected endpoint, including its own local endpoint. Each
endpoint may use a matching local capability or an explicitly imported
transferred capability.

- Claim selection derives from successful proof, never lobby slot, player
  index, peer ID, display name, profile/client ID, readiness, password, save
  possession, or the save signature.
- The host proves its local principal through the same challenge verifier used
  for the remote claimant.
- Each principal and each endpoint appears at most once in staged claims.
- A second valid claim for an already staged/active principal rejects the whole
  attempt; it never evicts, overwrites, or asks the host to choose.
- Missing proof leaves the attempt non-publishable. Invalid, duplicate,
  ambiguous, or competing proof aborts and discards it without altering the
  live match or association map.
- MATCH-002 selects no automatic timeout or retry policy. The user may cancel a
  waiting attempt. After a failed attempt, starting a new explicit attempt is
  the only retry; challenges from the old attempt remain invalid.

### 5.3 Client staging and two-phase commit

After every saved HUMAN principal has exactly one entitled endpoint, map each
endpoint to the gameplay player already controlled by that principal. This is
transient reassociation; do not rewrite the binding or retain the lobby slot as
authority.

Before publication, player-originated command admission is closed for every
staged endpoint and for the host-local principal:

1. The host builds one `StateFilter.filter_for_player()` candidate per remote
   association and sends it with the scenario ID, command cursor, attempt ID,
   match fingerprint, and assigned existing principal ID.
2. Each client deserializes and validates its candidate, verifies the exact
   binding fingerprint and that the assigned principal controls its derived
   local player, stages it without installing it, and acknowledges readiness.
3. A disconnect, rejection, malformed snapshot, fingerprint/cursor mismatch,
   or negative acknowledgement before commit aborts the attempt and clears all
   staged claims/snapshots.
4. Once all current endpoints acknowledge, the coordinator enters `COMMITTING`
   and immediately revalidates, in one compare-and-commit operation, that the
   attempt/registry/candidate fingerprints and cursor are unchanged; every
   expected endpoint is still connected in the expected phase; every challenge
   was consumed once; every HUMAN has exactly one staged claimant; no endpoint
   or principal is duplicated; and no active or staged competing association
   exists. Any mismatch aborts before canonical installation.
5. `NetworkManager` atomically replaces the association map from that revalidated
   complete staged map while keeping command admission disabled. `LobbyManager`
   immediately calls the unchanged `GameManager.start_new_game_from_state()` on
   the host. The successful return from that call is the fresh-resume canonical
   publication linearization point: before it no restored canonical state is
   live; at it every HUMAN has one connected, proved, exclusive association.
6. If host installation fails, roll back the just-committed association map and
   send abort; no client installs.
7. On host success, send one commit message. Each client installs its already
   validated staged candidate through the same `GameManager` seam, restores the
   same cursor, transitions to `IN_GAME`, and rebuilds the board through the
   existing preloaded-state path, then returns one attempt-scoped installation
   acknowledgement.
8. The host accepts each installation acknowledgement once from its expected
   associated sender and rechecks the installed binding/cursor fingerprint.
   Player-originated command admission remains fail closed for all resumed
   principals until every publishing endpoint has acknowledged installation;
   only then does the coordinator enter `PUBLISHED` and enable the existing
   association-aware admission path.
9. Duplicate stage or installation acknowledgements, commit messages, or callbacks are
   idempotently ignored. Exactly one host install, one install per client, and
   one local `game_started` publication are permitted per attempt.

A disconnect after the canonical publication linearization point is ordinary
post-publication association loss: the confirmed disconnect removes only that
association, command admission remains closed for the missing principal, and
Section 6 governs reassociation. It does not roll back canonical gameplay state.
A disconnect before that point aborts the attempt without canonical publication.

The host's full authoritative state and each client's accepted filtered mirror
must have the same binding, cursor, public canonical facts, legal next decision
semantics, and stable-state outcome. Hidden fields remain server-only under the
existing filtering contract; convergence does not authorize distributing RNG,
hidden dials, damage-deck order, credentials, or verifier material.

### 5.4 Publication and reconstruction order

The live boundary is:

```text
validated saved candidate
  -> exact saved binding and host verifier registry match
  -> every HUMAN claim valid and exclusive
  -> per-associated-player filtered candidates validated by clients
  -> commit-time connection/claim/registry/candidate revalidation
  -> complete transient association set committed with admission closed
  -> host canonical state installed once (publication linearization point)
  -> clients publish their staged mirrors and acknowledge installation once
  -> all principal-originated command admission enabled together
  -> next legal decision/stable state and presentation re-derived
```

No gameplay command is submitted to create a valid resume point. Passive peers,
replay, reconstruction callbacks, modal routing, and presentation code SHALL
NOT drain, finish, skip, acknowledge, advance, or otherwise synthesize gameplay
progression. Any existing authoritative post-load recovery seam may run only
under its accepted exact-once authority and must be proven decision-equivalent
by Section 12.

## 6. Ordinary Reconnect And Active Association Rules

Ordinary reconnect means a new endpoint joins a still-running authoritative
host after the former endpoint's disconnect has been confirmed by the existing
transport disconnect or heartbeat lifecycle.

1. An `IN_GAME` transport handshake may authenticate protocol compatibility,
   but it assigns no gameplay slot or principal authority.
2. The host issues the same challenge described in Section 4.4 against the
   current canonical binding and original-host verifier registry.
3. While the old association remains active, any claim for that principal
   fails closed even with a valid signature. There is no eviction, host
   arbitration, or stale timeout added by MATCH-002.
4. After the existing disconnect callback removes the old peer association, a
   valid proof may establish a new association with the same principal.
5. The host derives the reconnecting endpoint's local gameplay player from the
   unchanged binding, sends one authorized filtered snapshot plus the current
   command cursor and scenario ID, and waits for its exact-once installation
   acknowledgement before enabling player-originated submission for that
   endpoint.
6. Client installation uses the same staged snapshot/install/presentation seam
   as fresh resume. Reconnect neither reloads the host state nor emits a second
   host `game_started` event.

Old peer IDs, freed lobby slots, prior local player index, display/profile data,
and connected membership are correlation data only. A disconnected endpoint's
loss changes no principal, kind, player mapping, command history, completed
inspection, timing window, current attack, activation state, or other canonical
fact.

## 7. Relationship To MATCH-001 And Existing Load Behavior

MATCH-001 remains the default fail-closed guard. Replace only the branch that
currently rejects a ready fresh lobby for lack of same-live-match association:

| Load/reconstruction case | MATCH-002 disposition |
| --- | --- |
| Hot-Seat current-format named save/checkpoint | Unchanged existing `SaveGameManager` -> `GameManager.start_new_game_from_state()` path. No entitlement registry or proof. |
| Network load inside the same live match with exact binding and all associations valid | Preserve `NetworkManager.can_install_loaded_binding()` and current behavior. Do not require a redundant fresh claim or alter the binding. Distribution should continue to respect the existing filtering boundary. |
| Fresh Network lobby on original save-owning host with complete valid registry and claims | New staged MATCH-002 flow; publish only after Sections 5.1-5.4. |
| Fresh Network lobby with missing/corrupt/mismatched registry or any missing/invalid/competing claim | Reject without calling the live installation seam or changing associations. |
| Saved Network artifact copied to another host installation | Existing save HMAC and absent/mismatched protected registry fail closed. No trust import or verifier transfer. |
| Ordinary reconnect to live host | Same Section 4.4 validator; new association only after confirmed old-association loss; send filtered snapshot. |
| Network replay | Existing replay path only. No capability creation, claim, or live reassociation. |

The implementation SHALL retain a visibly named distinction between
`same_live_match_load`, `fresh_session_resume`, and `reconnect` orchestration,
while calling the same entitlement validator for the latter two. Do not weaken
`can_install_loaded_binding()` into a lobby/slot check or use it as a hidden
fresh-resume bypass.

## 8. Failure, Rollback, And Exact-Once Behavior

### 8.1 Before live publication

Every failure preserves the pre-attempt `GameManager.current_game_state`,
`is_game_active`, command cursor, existing active associations, scene, and
published presentation. If no match is live, they remain empty/inactive.

Abort and discard the whole attempt on:

- save/version/signature/schema/cursor/lifecycle validation failure;
- unsupported Network binding shape;
- missing, corrupt, invalidly signed, or wrong-binding verifier registry;
- missing proof at explicit confirmation;
- malformed key or signature;
- stale, repeated, wrong-operation, wrong-attempt, wrong-match,
  wrong-principal, or wrong-endpoint challenge response;
- duplicate endpoint, duplicate principal, ambiguous claim, or competing
  active/staged claim;
- client staging rejection, mismatch, pre-publication disconnect, or negative
  acknowledgement; or
- host live-installation failure.

Discarded attempts invalidate all challenges and erase candidate snapshots,
proofs, signatures, acknowledgements, and staged association changes. Private
capabilities and the durable verifier registry are not deleted or rotated.

### 8.2 Commit and duplicate delivery

Use the 256-bit attempt ID from Section 4.1 and explicit phases such as
`STAGING_CLAIMS`, `STAGING_SNAPSHOTS`, `COMMITTING`, `AWAITING_INSTALL_ACKS`,
`PUBLISHED`, and `ABORTED` only inside the purpose-specific resume coordinator
fields. They are runtime orchestration, not a canonical session FSM.

State changes are compare-and-commit:

- a principal/endpoint can transition from unclaimed to staged once;
- every challenge is consumed once;
- every client readiness and installation acknowledgement counts once;
- association maps are replaced only from one complete validated staged map;
- host and client installation are each invoked once per attempt;
- command admission changes from closed to enabled once, only after all
  installation acknowledgements;
- repeated commit/abort/RPC delivery is a no-op; and
- no rejection enters gameplay command history or triggers gameplay follow-up.

After successful publication, normal confirmed disconnect removes only the
affected transient association. It does not roll back the restored canonical
match. Reassociation then follows Section 6.

If a client disconnects or fails to acknowledge installation after the host
publication linearization point, do not roll back canonical host state. Keep
fresh-resume command admission closed for every resumed principal, remove the
affected association on confirmed disconnect, and require Section 6
reassociation plus installation acknowledgement before the original attempt
may enter `PUBLISHED` and enable admission for all. Until then the canonical
host state is live but fail-closed and the attempt must not be reported as a
successful resume.

## 9. Host/Client Distribution And Security Boundary

Use reliable RPCs and bump `NetworkManager.PROTOCOL_VERSION` from 3 to 4 in the
same cutover as the new handshake/claim/staging messages. Mixed protocol 3/4
connections reject before capability or state exchange. Do not add resume
claims to `GameCommand` or accepted command history.

Required message families, with final names chosen consistently during
implementation:

- new-match public-verifier registration, persisted-verifier fingerprint
  confirmation, and matching persistence acknowledgement;
- resume/reconnect offer and one-use challenge;
- challenge response containing principal ID and signature, never private key;
- per-peer filtered candidate staging and acknowledgement;
- resume commit, installation acknowledgement, publish/admission-enable, and
  abort; and
- reconnect snapshot staging/commit.

All RPC receivers validate server/client role, connection phase, remote sender,
attempt ID, expected message phase, exact binding fingerprint, and one-use
ordering before changing staging state. Client-supplied principal IDs and
verifier fingerprints are claims to validate, not authority.

Never serialize or log private capabilities, local HMAC keys, challenge
responses, or proof bytes. Public verifiers must remain outside:

- `GameState` and `MatchPlayerControlBinding`;
- `StateFilter` input/output;
- save body/header and display metadata;
- replay headers and commands;
- `InteractionFlow`, `UIProjector.UIIntent`, modals, and labels; and
- gameplay command payloads/results and baseline traces.

Diagnostic logs may contain only attempt phase, endpoint ID, principal ID or a
short non-secret fingerprint, and a generic rejection category. They must not
include key material, signatures, nonce bytes, exported envelopes, or pasted
input.

## 10. UI And Bootstrap Changes

### 10.1 New-match capability readiness

Normal Network start gains a short pre-publication "Preparing resume access"
state while each endpoint generates/persists its private capability and the
host persists public verifiers. `LobbyRoom` shows generic ready/failed status;
it does not show verifier or private-key material. Failure returns to the lobby
without starting the match.

### 10.2 Fresh-session resume

Keep the existing host-only Network section in `LoadGameDialog`, but change its
fresh-lobby action from direct `host_load_save()` to staged resume. A row is
enabled only when the save is current-format, valid on this installation, and a
matching valid host verifier registry exists. Non-resumable legacy/current
saves remain visible with a precise fail-closed explanation.

`LobbyRoom` shows the pending save name and only non-secret statuses such as
"waiting for entitlement", "proof accepted", "staging restored state", or a
generic failure. It provides:

- an explicit field/action to import a deliberately transferred capability;
- an explicit cancel action; and
- a publish/confirm action that remains disabled until every HUMAN principal
  is validly and exclusively claimed and all client candidates are staged.

Do not identify the entitled person or imply physical-person continuity.

### 10.3 Reconnect

The Main Menu join flow accepts an optional imported resume capability or uses
an already stored matching local capability after the host's non-secret offer.
When the server is already `IN_GAME`, successful transport handshake enters the
entitlement challenge flow rather than assigning a vacant lobby slot. On
successful snapshot commit it uses the existing board transition and preloaded
state reconstruction. Invalid or competing proof shows a generic rejection and
never enters the board.

### 10.4 Deliberate transfer

Add a narrow capability dialog reachable from the in-game Network menu and the
Main Menu. It lists only locally held match/principal labels, and reveals or
copies the private export only after an explicit user action and warning that
the holder can control that saved principal. There is no host-side "grant",
"take over", "replace player", "reset key", or "revoke" control.

UI enablement is presentation only. Every operation repeats authoritative
validation in `NetworkManager`/`LobbyManager`. UI and bootstrap code call only
narrow `NetworkManager` façade methods for capability listing, import, explicit
export/reveal, signing, availability, and status. They never instantiate the
store, read its files, validate their own proof, or edit associations.

## 11. Exact Authorized Scope

Implementation is limited to the files below. Equivalent final filenames for
new purpose-specific files are permitted, but no materially broader owner or
generic framework is authorized.

### 11.1 Production files

| File | Authorized bounded change |
| --- | --- |
| `src/core/network/match_principal_entitlement_store.gd` (new) | Exact Section 4.1 proof encoding/hash/signature helpers; versioned match fingerprint; RSA capability generation/import/export; canonical public verifier derivation; cryptographically random HMAC key; HMAC-integrity-protected local capability vault and original-host verifier registry; atomic replacement; injected test paths; exact bounds/validation; and no logging of secret material. No account/profile/session API and no UI ownership. |
| `src/utils/path_config.gd` | Add explicit `user://` credential-vault, verifier-registry, and local integrity-key paths. Do not place these under public saves/replays or `res://`. |
| `src/autoload/network_manager.gd` | Own the helper and expose its narrow UI/bootstrap façade; protocol 4; end-to-end confirmed new-match verifier establishment; shared resume/reconnect challenge validator; attempt-scoped staged and active exclusive associations; commit-time revalidation; principal-derived local player association; filtered candidate/reconnect snapshot messages; readiness/install acknowledgement, publication, admission-enable, commit/abort exact-once behavior; retain command-admission checks. |
| `src/autoload/lobby_manager.gd` | Preserve same-live-match load; stage fresh resume candidate/metadata/cursor; coordinate claims, snapshot acknowledgements, rollback, and final publication through existing owners. No generic session state. |
| `src/autoload/save_game_manager.gd` | Narrow forwarding-only read of the exact match-fingerprint/resumability result after normal save validation/list inspection; substantive registry logic remains in the NetworkManager-owned helper. No entitlement proof, save-body field, save-signature substitution, canonical mutation, or new owner category. Preserve named-save/checkpoint parity. |
| `src/ui/save/load_game_dialog.gd` | Report fresh-resume availability from the authoritative query, route lobby Network load into staging, preserve same-live-match and Hot-Seat routing, and avoid emitting success before publication. |
| `src/scenes/lobby/lobby_room.gd` | Purpose-specific resume status, transferred-capability import, cancel, and gated confirmation controls. No authority inference from Ready, slot, names, or displayed status. |
| `src/scenes/main_menu/main_menu.gd` | Optional resume-capability input/import in join flow; handle `IN_GAME` entitlement/reconnect result and board transition. Preserve ordinary lobby join. |
| `src/ui/save/game_menu_modal.gd` | Expose the local capability dialog for Network participants only; no host takeover controls. |
| `src/ui/network/match_principal_capability_dialog.gd` (new) | Explicit local capability import/export/reveal/copy UI with warnings and redaction by default. It calls only narrow `NetworkManager` façade APIs and never owns/constructs the store, validates entitlement, reads credential files, or edits associations. |

Repository evidence proves that `GameManager.start_new_game_from_state()` and
`StateFilter.filter_for_player()` already provide the required installation and
filtered-candidate seams. No MATCH-002 production change is authorized in
`GameManager` or `StateFilter`. If implementation discovers a concrete required
change in either file, stop under Section 14 and refine the accepted scope and
corresponding regressions before proceeding.

No production change is authorized in `GameState`,
`MatchPlayerControlBinding`, `PlayerState`, `GameCommand`, `CommandProcessor`,
gameplay commands/validators, replay types/driver, `PlayerProfile`, setup package
formats, gameplay interaction owners, attack/timing/activation state, or rule
code. If implementation evidence requires such a change, stop under Section 14.

### 11.2 Automated test files

| File | Authorized coverage |
| --- | --- |
| `tests/unit/test_match_principal_entitlement_store.gd` (new) | Key/CSPRNG generation; exact canonical proof bytes/digest/signature/hex representation and size bounds; canonical verifier round trip; wrong-key/nonce/attempt/endpoint/principal failures; import/export; persistence/HMAC/corruption/atomic replacement; integrity-versus-confidentiality boundary; secret redaction; and original-install path behavior. |
| `tests/unit/test_network_manager.gd` | Protocol 4; exact wire-schema/size rejection; end-to-end verifier-fingerprint confirmation; shared claim validator; active/staged exclusivity; disconnect-only association removal; challenge exact-once; wrong-phase/sender rejection; commit-time revalidation; readiness/install acknowledgement exact-once; fail-closed admission enablement; host same-standard proof; command admission after reassociation; façade-only UI access; and no weaker fallback. |
| `tests/unit/test_lobby_manager_load.gd` | Separate same-live-load and fresh-resume branches; no early install/publication; full-claim and client-stage gate; publication linearization; invalid/missing/competing/commit-race rollback; duplicate callback exact-once; client filtered candidate validation and installation acknowledgement. |
| `tests/unit/test_save_game_manager.gd` and `tests/unit/test_save_load_round_trip.gd` | Current v5 round trip unchanged; resumability query requires exact local registry; save/checkpoint parity; copied/missing/corrupt registry fails only fresh resume; save deletion does not revoke capability. |
| `tests/unit/test_load_game_dialog.gd` | Fresh-lobby resumable/non-resumable rows, staged result semantics, Hot-Seat preservation, and same-live Network behavior. |
| `tests/unit/test_lobby_room.gd` | Status, import/cancel/confirm gates, secret redaction, and no Ready/slot-derived entitlement. |
| `tests/unit/scenes/main_menu/test_main_menu_new_game.gd` | Ordinary join preserved; `IN_GAME` join routes to challenge/reconnect; rejected proof never transitions to board. |
| `tests/unit/test_game_menu_modal.gd` and `tests/unit/test_match_principal_capability_dialog.gd` (new) | Explicit reveal/copy/import only, correct Network visibility, no automatic clipboard/log/display exposure, and no host grant/takeover controls. |
| `tests/integration/test_network_resume_and_reassociation.gd` (new) | End-to-end in-process orchestration matrix in Section 12 using production owners and real serialized/filtered candidates; decision-equivalent recovery and passive/exact-once assertions. |
| `tests/integration/test_network_transport.gd` | Real ENet handshake/message coverage where the current harness permits it: protocol mismatch, staged claim ordering, reconnect after confirmed disconnect, competing live claim, and targeted snapshot/commit. Function-call tests alone do not satisfy transport admission. |
| `tests/integration/test_reconnection_mid_attack.gd` and `tests/integration/test_current_attack_production_resume.gd` | Extend existing canonical reconstruction fixtures only as needed to prove that entitled production reconnect/fresh resume reaches the same decision and passive peers synthesize no progression. Do not change accepted gameplay expectations. |
| `tests/acceptance/network_resume/` (new) | Mandatory separate-process production-RPC drivers and assertions for Section 12.2 A-D, with isolated installation roots and no shared autoload memory or direct-call transport bypass. |
| `scripts/run_network_resume_acceptance.sh` (new) | Mandatory bounded runner that launches, coordinates, times out, and cleans up the separate host/client/replacement processes while preserving redacted evidence on failure. |

The current in-process harness explicitly does not prove real peer transport.
The multi-process harness and runner above are therefore unconditional scope,
not a fallback. Do not add test-only bypasses or credential hooks to production
behavior.

### 11.3 Documentation files

| File | Authorized update after implementation |
| --- | --- |
| `docs/setup_network_game.md` | Replace stale fresh-lobby load guidance with the accepted original-host entitlement flow, capability transfer warning, reconnect behavior, and unsupported cases. |
| `docs/qa/MATCH-002-network-resume-manual-acceptance.md` (new) | Record Section 12.3 manual acceptance cases, tested build/commit, exact expected publication/reassociation/convergence behavior, evidence locations, and pass/fail results without capability material. |

Do not modify ADR-011, ADR-008, ADR-010, MATCH-001, contracts, requirements,
roadmap status, reality-gap status, boundary status, Arc42, or archived plans as
part of implementation. Any later acceptance/status update is a separate Owner
governance action.

## 12. Verification And Acceptance Matrix

### 12.1 Automated invariant coverage

| Obligation | Required evidence |
| --- | --- |
| Capability establishment | Each endpoint independently creates one key; only its public verifier reaches the host; the host persists that exact canonical verifier fingerprint and returns it; the endpoint verifies the returned fingerprint, persists its private capability, and sends confirmation; the host accepts that confirmation from the submitting endpoint against the persisted registry before a new Network match publishes. Failure or mismatch at any step leaves no live match or association. Assert private keys differ from principal, player, peer, client/profile, lobby, display, password, save-signature, and RNG values. |
| Proof wire contract | Assert fixed vectors for the exact version-1 domain, sorted canonical JSON UTF-8 bytes, SHA-256 digest, RSA-2048 signature, and 512-character lowercase-hex representation. Reject unknown/missing fields, wrong types, invalid or non-canonical encodings, wrong lengths, oversized verifier/export values, wrong operation/version, stale attempt, and any echoed field that differs from the host-held pending challenge before verification. |
| Persistence and threat boundary | Restart each isolated installation and verify valid vault/registry recovery, HMAC tamper detection, malformed/partial/oversized record rejection, and atomic prior-or-new-file behavior. Assert private PEM is absent from saves, replays, logs, snapshots, and UI by default. Record that HMAC provides integrity, not encryption or same-user/malware resistance; copying the complete application trust directory is an installation clone outside this MVP's resistance claim. |
| Fresh-session original-host resume | Create/save a Network match, terminate the whole session, create a fresh host/lobby using the same host credential registry, load the save, prove both principals, stage both endpoints, and publish once. Assert the pre-attempt game is inactive and no state/association/event is published before the last gate. |
| Complete HUMAN entitlement | Derive the exact saved HUMAN set from the binding. Assert every member has exactly one verified endpoint and every verified endpoint maps to exactly one member before commit. Missing/extra/AUTOMATED claims reject. |
| Canonical binding preservation | Snapshot the saved binding serialization and principal-to-player queries before staging. Assert byte-equivalent binding and query results on host/client after publication and after deliberate substitution. No principal creation/deletion/kind/mapping API is called. |
| Deliberate capability-holder substitution | Export the remote principal's private capability, import it into a replacement endpoint, end the old association/session as applicable, complete proof, and assert the replacement controls the same saved principal/player. Assert public canonical state and binding are unchanged and no host grant/reset path exists. |
| Competing active claims | With incumbent association active, present a valid copied capability from a second endpoint. Reject the second claim, preserve the incumbent and canonical state, send no snapshot/commit, and record no gameplay command. Repeat for staged competition before fresh publication and active competition during reconnect. |
| Invalid/missing entitlement | Wrong key, corrupted signature, wrong principal, wrong match, reused nonce, wrong endpoint/attempt, absent registry, corrupt registry, and missing claimant each fail with zero live installs, zero `game_started`/`game_starting`, zero association commit, unchanged cursor/state, and cleared attempt state. |
| Shared reconnect standard | Run the same proof validator vectors through fresh resume and reconnect. After confirmed disconnect, valid proof creates one association; before disconnect, the same proof competes and fails. Old peer/slot/name/profile matching alone always fails. |
| Host same standard | Remove or corrupt only the host private capability and prove fresh publication fails even while the host owns the save, save key, lobby, and verifier registry. A valid host signature then succeeds through the same validator API used remotely. |
| Save/load compatibility | Named save and checkpoint use current v5 payload unchanged. New registry-backed Network saves resume; pre-MATCH-002 v5 Network saves without verifier metadata still support only an already-live exact-binding load and fail fresh resume with `entitlement_unavailable`. Hot-Seat named/checkpoint load remains byte/behavior equivalent. |
| Original-install boundary | Copy a valid save without the original host registry/key and assert save verification or resume-registry validation rejects. Copying the save, registry, public verifier, or any incomplete subset of the trust directory does not migrate host trust. A complete trust-directory copy is explicitly classified as an installation clone outside this MVP's resistance claim, not a supported verifier-transfer workflow. No host registry import/transfer UI exists. |
| Distribution convergence | Host installs full canonical state; each client installs the expected `StateFilter` result for its reassociated player. Assert equal binding, cursor, round/phase, public entities, public lifecycle state, accepted public state hash, and decision semantics; assert server-only/other-player hidden facts remain filtered. |
| Decision-equivalent next action | Use at least one save containing a live optional or mandatory decision and one accepted stable state. After fresh resume and reconnect, compare derived opportunity existence, actor/controller, optionality, legal choices/source, commit/decline/completion semantics, and UI intent against direct reconstruction of the saved state. |
| Passive reconstruction | Record command count/sequence before staging. Host/client snapshot validation and `UIProjector` add zero commands. Replay applies recorded history only. Passive peers never call authoritative recovery submission. Any accepted deterministic host-only recovery already required by existing authority occurs at most once and yields the same saved decision/stable outcome. |
| Publication and admission boundary | Race disconnect, registry/candidate/cursor mutation, duplicate/competing claims, and stale readiness immediately before commit-time revalidation. Assert every mismatch aborts before host installation. Assert the successful host `start_new_game_from_state()` return is the sole canonical publication linearization point, association commit occurs with admission closed, and no resumed principal command is admitted until every expected installation acknowledgement is accepted. |
| Exact-once publication | Duplicate verifier registrations and confirmations, claims, signatures, staging acknowledgements, commit, installation acknowledgements, admission enable, abort, and reconnect snapshot delivery. Assert one consumed challenge, one association per endpoint/principal, one local install/event per publishing endpoint, one admission transition, no duplicate scene transition, and no duplicate gameplay command/follow-up. |
| Admission and legality independence | Entitled/reassociated legal command reaches existing validation; wrong-principal legal command rejects before `CommandProcessor`; entitled but illegal command reaches and fails existing gameplay validation. Trusted authoritative and replay provenance remain unchanged. |
| Same-live Network load regression | In one live match with exact unchanged binding and associations, load an earlier same-match save successfully. Different binding, missing association, or fresh lobby without proof continues to fail. |
| Façade and security redaction | Structural checks prove UI/bootstrap code accesses capability listing/import/export/signing/availability only through `NetworkManager`, never by constructing or reading the store. Search serialized save, filtered snapshots, replay, command history/results, logs, UI labels, baseline traces, and committed fixtures for private-key/export/challenge/proof material. Assert none exists. Public verifier registry is only in its protected local envelope. |

### 12.2 End-to-end acceptance scenarios

Scenarios A-D SHALL run in the mandatory separate-process acceptance harness
through protocol-4 production ENet RPCs and production serialization and
orchestration seams. In-process integration tests supplement this evidence but
cannot replace it. The harness SHALL:

- launch the authoritative host and every original, replacement, or competing
  endpoint used by a scenario as separate Godot OS processes, with no shared
  autoload memory, direct method calls, or test-only transport/credential
  bypass; a copied-save foreign-host case likewise uses a separate host
  process;
- give each installation an isolated `user://` root; reuse the original host
  root across a complete host shutdown/restart and the original client root
  across its restart, while replacement, competing, and foreign-host processes
  use fresh, mutually distinct roots;
- prove messages arrive through ENet with the authoritative sender peer ID,
  protocol-4 negotiation, attempt/phase ordering, duplicate/replay rejection,
  confirmed disconnect lifecycle, simultaneous competing claim behavior, and
  targeted filtered snapshot delivery without hidden-state or credential
  leakage; and
- use bounded startup/phase/shutdown timeouts, terminate all child processes,
  and retain only redacted per-process logs and machine-readable assertions on
  failure.

The automated integration/acceptance suite SHALL run at least these complete
scenarios:

**A. Fresh-session successful resume**

1. Start a two-human Network match and prove the exact host-persisted verifier
   fingerprint round trip, endpoint confirmation, and private/verifier
   persistence complete before initial publication.
2. Advance to a canonical live gameplay decision, create a named save and
   checkpoint, record binding/cursor/decision snapshot, and terminate both
   processes/session state.
3. Start a fresh lobby on the original host installation and connect a claimant
   endpoint with a matching capability.
4. Stage the save; assert no live state after only the host claim or only the
   remote claim.
5. Complete both claims and client staging; revalidate at commit, publish the
   host once, collect the client's installation acknowledgement, and enable
   command admission once.
6. Assert host/client convergence under the filtering contract, exact saved
   binding, decision equivalence, correct principal-derived local viewers, and
   zero synthetic progression.

**B. Deliberate replacement holder**

Repeat A after exporting the remote capability to a clean replacement client
installation/root that has a different peer ID, profile/client ID, display
name, and lobby slot history. Assert success with the same canonical
principal/player binding and no host-mediated grant.

**C. Competing and invalid claims**

Present valid claims simultaneously from two isolated endpoint processes for
one principal, then each negative vector in Section 12.1, including stale and
replayed challenge responses over real transport. Assert complete attempt
rollback before fresh publication and incumbent preservation during live
reconnect.

**D. Ordinary reconnect**

Disconnect the remote endpoint during a recoverable gameplay decision. Before
confirmed disconnect, competition fails. After the existing disconnect signal,
reconnect from a new endpoint, prove the same capability, stage the filtered
snapshot, acknowledge installation, and restore interactivity for the unchanged
principal. Assert the host state/cursor never reloads or republishes, admission
opens only after installation acknowledgement, and no gameplay progress is
synthesized.

**E. Compatibility regressions**

Run same-live Network named/checkpoint load, unrelated Hot-Seat named/checkpoint
load, pre-MATCH-002 Network fresh-resume rejection, and Network replay. Assert
their Section 7 dispositions exactly.

### 12.3 Manual verification

Run a real two-GUI-process session, not only direct function calls:

1. Create a new Network game; observe capability preparation completes and each
   participant can explicitly reveal/copy only its own resume capability.
2. Save at a visible decision, close both processes, start a fresh host lobby on
   the same installation, connect the other participant, and resume. Confirm no
   board appears until both claims are accepted; then compare round, phase,
   pieces, visible hidden-information treatment, current actor, legal controls,
   and next decision on host/client.
3. Transfer the remote capability export to a clean second client profile and
   repeat. Confirm the replacement receives the saved side/principal even when
   its lobby/profile/display identity differs.
4. Keep the incumbent connected and try the same exported capability from a
   third endpoint. Confirm rejection without eviction or state/UI change.
5. Disconnect the incumbent, wait for the existing confirmed-disconnect
   indication, reconnect with valid proof, and confirm the exact pending
   decision returns without a duplicate action or modal-driven progression.
6. Try missing/wrong capability and a copied save on another host installation.
   Confirm no partial board/state publication and a clear unsupported/error
   message.
7. Load an earlier same-match Network save in-session and an unrelated Hot-Seat
   save from the Main Menu. Confirm both existing supported behaviors remain.

Record application logs with secret redaction, screenshots of the pre-publish
gate and restored decision, host/client state-hash/convergence output from the
test harness, and the exact commit under verification. Do not attach capability
exports or private-key material.

### 12.4 Execution gates

Implementation acceptance requires, at minimum:

1. all focused unit and integration tests in Section 11.2;
2. `./scripts/run_network_resume_acceptance.sh`, with Sections 12.2 A-D passing
   across separate Godot processes, isolated/reused installation roots exactly
   as specified, production protocol-4 ENet RPCs, confirmed disconnects,
   competing endpoints, targeted filtering, and redacted retained evidence;
3. existing save/load, checkpoint, Network command, filtered reconstruction,
   reconnect projection, replay, current-attack, timing-window, activation, and
   shared-protocol suites;
4. `./scripts/run_tests.sh`;
5. `./scripts/run_baseline_traces.sh --all`, with no fixture promotion unless
   an independently reviewed canonical change is expected (none is expected);
6. `./scripts/lint_phase_k.sh` and `./scripts/quality_check.sh`;
7. structural searches proving no private capability/verifier registry/proof
   enters canonical, save, snapshot, replay, command, UI label, or log payloads;
8. structural searches proving peer/session/player/profile/lobby/name/password/
   save-signature values are never accepted as entitlement;
9. structural searches proving `GameState`/binding have no new rebind or
   credential mutation surface, UI/bootstrap reaches the entitlement store only
   through `NetworkManager`, and the authorized diff contains no production
   change to `GameManager` or `StateFilter`;
10. `git diff --check`, repository-reference/link review, authorized-file diff
    review, and final worktree-status review; and
11. the manual verification in Section 12.3.

## 13. Compatibility, Migration, Rollout, And Rollback

### 13.1 Save and replay formats

Do **not** bump `SaveGameMetadata.CURRENT_VERSION` from 5. MATCH-002 adds no save
header/body field and changes no canonical serialized state. The match
fingerprint derives from the already required binding, and verifier/private
material lives in the separate protected local boundary.

Do **not** change replay format. Replay neither proves entitlement nor contains
resume credentials.

Increment only Network protocol 3 -> 4 because handshake and runtime RPC shape
changes. Mixed versions fail before session admission.

### 13.2 Existing artifacts

- Existing current-version Hot-Seat saves/checkpoints remain fully supported.
- Existing current-version Network saves remain supported by the exact
  same-live-match load path when its associations already exist.
- A Network save made before a complete MATCH-002 host verifier registry was
  established is not fresh-session resumable. Reject it without synthesizing
  verifiers or principals and without offering an automatic resave/migration.
- A Network save made after successful capability establishment is resumable
  on the original host installation because the match-scoped registry applies
  across every save/checkpoint with the exact binding.
- Copying a save, registry file, public verifier, or any incomplete subset of
  the original host's trust directory does not migrate trust. Copying the
  complete trust directory, including integrity keys, is an installation clone
  outside this MVP's resistance claim and is not a supported transfer workflow.
  Cross-host/cross-install resume remains unsupported.
- Saving/checkpointing never rotates or invalidates a capability. Deleting a
  save never revokes one.

No migration derives entitlement from version, signature, profile, lobby,
names, slots, player indices, or principal IDs. No pre-MATCH-002 match is
silently enrolled.

### 13.3 Cutover and rollback

Activate capability establishment, protected persistence, protocol 4,
fresh-resume staging, reconnect proof, UI, and all fail-closed admission gates
as one semantic cutover. Do not ship an intermediate build that creates
resumable-looking saves without verifier persistence or accepts proof without
atomic association/publication.

Before cutover, behavior-inert helper/tests may be removed. After cutover,
rollback means reverting the complete MATCH-002 feature and protocol version.
Version-5 saves remain readable under their prior rules, but matches created
with MATCH-002 capabilities lose fresh resume/reassociation until the complete
feature returns. Do not relabel protocol messages, import registries into an
older build, or fall back to slots/profile identity.

## 14. Implementation Stop Gates

Stop and request Project Owner direction rather than improvise if evidence
requires any of the following:

- changing a settled ADR-011 decision or resolving a deferred policy to deliver
  this MVP;
- rebinding, replacing, creating, deleting, or changing the kind of a saved
  canonical principal;
- putting peer/session/profile/lobby/presentation identity into durable
  authority or using any of them as entitlement proof;
- allowing host discretion to grant, manufacture, bypass, replace, revoke, or
  arbitrate another saved HUMAN principal's entitlement;
- evicting an active association, supporting multiple peers per principal, or
  selecting stale timeout/retry/rotation/revocation/proof-loss policy;
- storing a private capability in `GameState`, save/replay, snapshots,
  commands, presentation, logs, or display metadata;
- requiring cross-host, cross-installation, cross-device, cloud, or copied-save
  trust transfer;
- publishing with a missing HUMAN claimant, partial association set, or client
  that has not validated its staged candidate;
- synthetic gameplay progression, presentation-originated progression, or a
  second gameplay-state owner during reconstruction;
- partial HUMAN participation, absent-player progression, forfeit, bot
  substitution, AUTOMATED-kind changes, spectators, late join, accounts,
  matchmaking, invites, or general session management;
- a materially new architectural owner, autoload service, general participant/
  identity/session framework, or new `GameManager` responsibility category;
- a production change to `GameManager` or `StateFilter` despite the existing
  installation/filtering seams, unless the workbook is first re-refined with
  concrete evidence, authorized scope, and corresponding regression coverage;
- same-OS-user extraction resistance, hardware-backed or OS-keychain custody,
  or clone-resistant installation identity beyond the explicitly bounded HMAC
  integrity and application-data storage model;
- changes to canonical save/replay schema, gameplay commands, accepted
  gameplay authorities, or production files outside Section 11; or
- a materially larger production/test/document scope than this bounded MVP.

Also stop if Godot's built-in cryptographic API cannot implement the selected
private-key challenge proof without an external security/key-management
framework. Do not silently downgrade to a reusable bearer secret over the
transport.

## 15. Exit Gate

MATCH-002 is implementation-ready only while all of these statements remain
true:

1. The original host installation can validate the current save and exact
   integrity-protected verifier registry under the explicit Section 4.2 threat
   boundary without changing the save or binding.
2. Each saved HUMAN principal has one independently held capability and exactly
   one proved endpoint before fresh publication.
3. Host and remote claims use one proof validator; reconnect reuses it after
   confirmed association loss.
4. Associations remain transient, exclusive, principal-derived, and are
   committed with command admission closed until every publishing endpoint has
   acknowledged installation.
5. Candidate state, claims, client mirrors, and publication are staged;
   immediate commit-time revalidation precedes the sole host-installation
   publication linearization point, and every pre-linearization failure is
   fail-closed from live gameplay's perspective.
6. Host and clients recover the same authorized canonical semantics, cursor,
   and next decision/stable state; presentation is derived and passive paths
   synthesize no gameplay.
7. MATCH-001 same-live-match load, Hot-Seat save/load, filtering, replay, and
   gameplay legality remain intact.
8. Existing saves receive the exact Section 13 compatibility treatment with no
   fabricated migration.
9. All automated checks, including the mandatory isolated separate-process
   production-transport harness, plus structural, repository, and manual checks
   in Section 12 pass.
10. No Section 14 stop gate is triggered.

No additional Owner decision is required for the selected match fingerprint,
asymmetric capability, protected original-install registry, two-phase staging,
protocol allocation, or no-save-format-bump choices. Acceptance of this
workbook is still required before implementation begins.
