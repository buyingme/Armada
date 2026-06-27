# AI Development Principles

> **Status:** Draft
>
> **Authority:** Development Architecture
>
> **Audience:** Project Owner and AI Agents

------------------------------------------------------------------------

# Purpose

These principles define the philosophy behind the Armada AI-assisted
development process.

They are intentionally stable and tool-independent.

The principles guide decisions whenever the detailed workflow does not
prescribe a single correct action.

------------------------------------------------------------------------

# Guiding Principle

> **Build the simplest process that consistently produces excellent
> software.**

The development process is considered part of the project architecture
and shall therefore evolve deliberately and remain lightweight.

------------------------------------------------------------------------

# Principle 1 --- Value over Process

Every process element shall provide measurable value.

A process step should exist only if it:

-   improves software quality,
-   reduces development risk,
-   improves AI collaboration, or
-   saves development time.

If none of these goals are achieved, the process should be simplified.

------------------------------------------------------------------------

# Principle 2 --- Evidence before Decisions

Architecture decisions shall be based on evidence.

The amount of evidence shall be proportional to the importance of the
decision.

Small decisions require little evidence.

Large architectural decisions require broader analysis.

------------------------------------------------------------------------

# Principle 3 --- Owner Authority

The Project Owner remains responsible for all architectural and
implementation decisions.

AI agents assist the decision-making process but never establish project
authority.

------------------------------------------------------------------------

# Principle 4 --- Architecture before Implementation

Implementation follows accepted architecture.

Implementation may reveal weaknesses in the architecture, but it shall
not redefine architecture implicitly.

Architecture changes require an explicit Owner decision.

------------------------------------------------------------------------

# Principle 5 --- Tasks over Prompts

The Project Owner communicates objectives through tasks.

Agent behaviour is defined by reusable agent definitions.

Prompts are temporary.

Tasks are reusable.

------------------------------------------------------------------------

# Principle 6 --- Roles over Tools

Development roles remain stable.

AI tools may change over time.

The development process shall not depend on a specific AI model or
vendor.

------------------------------------------------------------------------

# Principle 7 --- Continuous Simplification

The development process is reviewed regularly.

Complexity is introduced only when justified by measurable value.

Whenever equivalent results can be achieved with a simpler process, the
simpler process shall be preferred.

------------------------------------------------------------------------

# Success Criteria

The development process is successful when it:

-   preserves architectural consistency,
-   enables sustainable long-term development,
-   supports effective AI collaboration,
-   remains easy to understand,
-   remains lightweight,
-   evolves only when justified by project needs.

------------------------------------------------------------------------

# Related Documents

-   AI_DEVELOPMENT_PROCESS.md
-   TASK_SPECIFICATION.md
-   REVIEW_PROCESS.md
-   REQUIREMENTS_PROCESS.md
-   AGENTS.md
