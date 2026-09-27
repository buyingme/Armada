# BUG-062 — Resolved Attack Does Not Rebuild Pending Immediate Choice

**Status:** Open

## Finding

The BUG-043 R3 production Attack-resume test installed a resolved Attack with a valid active Shield Failure record. `AttackExecutor.resume_current_attack()` returned a generic await-completion plan and did not recover the public card or legal chooser. A resumed player could not complete the pending canonical choice.

## Bounded repair

After the existing Attack resume projection, derive the matching active immediate record from the defender ship and rebuild its existing choice modal for the canonical actor. The reconstruction path submits no command or flow publication. Automatic branches remain authority-owned.
