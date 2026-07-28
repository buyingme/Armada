# QA Issue Workflow

This directory contains file-based tracking for bugs and UX observations.

## Sources of Truth

- The issue directory path is the authoritative lifecycle status.
- issue.md records the human-readable problem, impact, evidence, and resolution.
- annotation.json records captured game-state evidence when available.
- Generated indexes are navigation aids only and are not authoritative.

Do not add a separate status field to issue files.

## Issue Structure

text bugs/<status>/BUG-NNN/ ├── issue.md └── annotation.json  ux/<status>/UX-NNN/ ├── issue.md └── annotation.json

An annotation is optional when no useful game-state capture exists.

## Workflow

Create a new issue from the appropriate template and assign the next unused ID.

Move the complete issue directory when its lifecycle status changes. Do not create a new issue ID during investigation, implementation, verification, or closure.

Example:

text bugs/open/BUG-017/ → bugs/in_progress/BUG-017/ → bugs/verify/BUG-017/ → bugs/closed/BUG-017/

Use the status directories already defined under bugs/ and ux/. Do not introduce additional lifecycle states without an explicit workflow decision.

## Classification

Choose the layer that best describes where the issue is visible to the player. The initial classification does not need to identify the technical root cause and may be corrected during investigation.

## Indexes

BUG_INDEX.md and UX_INDEX.md may be generated from the directory structure.

Index generation must:

- preserve the directory structure as the status authority;
- link to each issue's issue.md;
- derive titles and classifications from the issue file;
- avoid adding information that is not present in the issue artifacts.

## Completion

Before moving an issue to a completed state, record the resolution and verification in issue.md.

Closed, rejected, and duplicate issues remain in the repository for traceability.
