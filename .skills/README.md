# Skill Documents — Star Wars: Armada Digital Edition

These documents define the standards and patterns that **must** be followed when generating or reviewing code for this project. They ensure consistency across AI-assisted and manual development.

## Global Safety Gate

If there is ambiguity or uncertainty about what should be changed, how it
should behave, which files or data sources should be touched, whether hot-seat
and network need different handling, or whether an action could be destructive
or broad, ask a concise clarifying question or present concrete options with
tradeoffs. Wait for explicit user approval before making the change. This rule
applies across all skill documents and exists to prevent unwanted code changes.

## Documents

| File | Purpose |
|------|---------|
| [gdscript_style.md](gdscript_style.md) | GDScript coding standards and naming conventions |
| [architecture_patterns.md](architecture_patterns.md) | Required architecture patterns and principles |
| [testing_standards.md](testing_standards.md) | Testing conventions, naming, and coverage requirements |
| [file_organization.md](file_organization.md) | File and folder structure rules |
| [copilot_instructions.md](copilot_instructions.md) | Instructions for AI code generation |
| [ui_styling.md](ui_styling.md) | Modal panel, overlay, button, label, and layout styling rules |
| [refactoring_guidelines.md](refactoring_guidelines.md) | Function-size limits, extraction patterns, and refactoring targets |
| [serialization_and_commands.md](serialization_and_commands.md) | Serialization contract, command system, normalised positions, replay safety |
| [sound_and_music.md](sound_and_music.md) | Audio architecture and sound/music implementation guidance |

## Usage

When working with AI assistants (GitHub Copilot, etc.), reference these documents to ensure generated code meets project standards. The AI should be instructed to follow these guidelines for every code generation task.

The core mandatory set is defined in `.github/copilot-instructions.md` and
currently includes all of the documents above except `sound_and_music.md`,
which is a domain-specific guide to load when a task touches audio.

These `.skills/*.md` files are project guidance documents referenced by
instructions. Discoverable workspace Copilot skills live under
`.github/skills/` as `SKILL.md` files, for example
`.github/skills/rule-integration/SKILL.md`.
