#!/usr/bin/env bash
# Phase K lint — guards against new PlayMode discriminators in the
# presentation layer.
#
# Usage:
#   ./scripts/lint_phase_k.sh
#
# Exit codes:
#   0 = no violations
#   1 = at least one un-allow-listed PlayMode branch in src/scenes/ or src/ui/
#
# Rule (per docs/refactoring_phase_k_plan.md §3.1):
#   `if PlayMode.is_network()` / `if PlayMode.is_hot_seat()` (and their
#   negations) are forbidden in src/scenes/ and src/ui/ unless the line is
#   accompanied by a `# Phase K allow-list:` marker comment within ±5 lines.
#
#   Allow-listed sites are session-mode dispatchers (plan §3.1a) — branches
#   that select between fundamentally different *content* (e.g. lobby vs no
#   lobby), not "who is allowed to interact" decisions.  Modal-authority
#   branches must use UIProjector.project()/UIIntent or the
#   NetworkManager.get_local_player_index() axis instead.

set -euo pipefail

cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

WINDOW=8  # lines of context to scan around a hit for the allow-list marker
          # (multi-line `if` conditions can put the marker further away
          # than the 3-5 line standard).
PATTERN='\bPlayMode\.is_(network|hot_seat)\('
MARKER='Phase K allow-list'

violations=0
allowed=0

# Collect all candidate lines (file:line:text) under src/scenes and src/ui.
# Skip pure comment lines (those starting with optional whitespace + '#') —
# they cannot be branches.
HITS=$(grep -rnE "$PATTERN" src/scenes src/ui 2>/dev/null \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)

if [[ -z "$HITS" ]]; then
    echo -e "${GREEN}lint_phase_k: 0 PlayMode branches found in src/scenes/ or src/ui/.${NC}"
    exit 0
fi

while IFS= read -r hit; do
    file="${hit%%:*}"
    rest="${hit#*:}"
    line="${rest%%:*}"

    start=$(( line > WINDOW ? line - WINDOW : 1 ))
    end=$(( line + WINDOW ))

    if sed -n "${start},${end}p" "$file" | grep -qF "$MARKER"; then
        allowed=$(( allowed + 1 ))
        continue
    fi

    if [[ $violations -eq 0 ]]; then
        echo -e "${RED}lint_phase_k: forbidden PlayMode branch(es) in src/scenes/ or src/ui/:${NC}"
    fi
    echo "  $hit"
    echo -e "    ${YELLOW}→ replace with UIProjector.project() / NetworkManager.get_local_player_index(),${NC}"
    echo -e "    ${YELLOW}  or add a '# Phase K allow-list: session-mode dispatcher (plan §3.1a)' marker${NC}"
    echo -e "    ${YELLOW}  within ±${WINDOW} lines and update docs/refactoring_phase_k_plan.md §3.1a.${NC}"
    violations=$(( violations + 1 ))
done <<< "$HITS"

if [[ $violations -gt 0 ]]; then
    echo -e "${RED}lint_phase_k: ${violations} violation(s); ${allowed} allow-listed.${NC}"
    exit 1
fi

echo -e "${GREEN}lint_phase_k: 0 violations (${allowed} allow-listed branches).${NC}"
exit 0
