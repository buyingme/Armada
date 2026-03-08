#!/usr/bin/env bash
# Quality Check Script — Star Wars: Armada Digital Edition
#
# Run this before every commit to verify code quality.
# Usage: ./scripts/quality_check.sh
#
# Exit codes:
#   0 = all checks passed
#   1 = one or more checks failed

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo "========================================="
echo " Armada Quality Check"
echo "========================================="
echo ""

# --- Check 1: No print() in source code ---
echo -n "Checking for banned print() calls... "
PRINT_HITS=$(grep -rn '\bprint(' src/ --include="*.gd" 2>/dev/null | grep -v 'utils/logger.gd' | grep -v '## ' | grep -v '#.*print(' || true)
if [ -n "$PRINT_HITS" ]; then
    echo -e "${RED}FAIL${NC}"
    echo "$PRINT_HITS"
    echo "  → Use GameLogger instead of print()"
    ((ERRORS++))
else
    echo -e "${GREEN}OK${NC}"
fi

# --- Check 2: All .gd files in src/ have doc comments ---
echo -n "Checking for missing class doc comments... "
MISSING_DOCS=0
for f in $(find src/ -name "*.gd" -type f 2>/dev/null); do
    FIRST_LINE=$(head -1 "$f")
    if [[ "$FIRST_LINE" != "##"* ]]; then
        if [ $MISSING_DOCS -eq 0 ]; then
            echo -e "${RED}FAIL${NC}"
        fi
        echo "  Missing doc comment: $f"
        ((MISSING_DOCS++))
    fi
done
if [ $MISSING_DOCS -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
else
    ((ERRORS++))
fi

# --- Check 3: All public functions have type annotations ---
echo -n "Checking for untyped function signatures... "
UNTYPED=$(grep -rn '^func [a-z].*):$' src/ --include="*.gd" 2>/dev/null | grep -v '\->' || true)
if [ -n "$UNTYPED" ]; then
    echo -e "${YELLOW}WARN${NC}"
    echo "$UNTYPED"
    echo "  → Add return type annotation (-> Type)"
    ((WARNINGS++))
else
    echo -e "${GREEN}OK${NC}"
fi

# --- Check 4: No magic numbers in core logic ---
echo -n "Checking for magic numbers in src/core/... "
# Look for bare integers > 1 that aren't in enum/const declarations or array indices
MAGIC=$(grep -rn '[^a-zA-Z_0-9][2-9][0-9]*[^a-zA-Z_0-9.:]' src/core/ --include="*.gd" 2>/dev/null \
    | grep -v 'const ' | grep -v 'enum ' | grep -v '##' | grep -v '#' \
    | grep -v 'Constants\.' | grep -v 'assert' | grep -v 'var.*:.*=' || true)
if [ -n "$MAGIC" ]; then
    echo -e "${YELLOW}WARN (review manually)${NC}"
    echo "$MAGIC"
    ((WARNINGS++))
else
    echo -e "${GREEN}OK${NC}"
fi

# --- Check 5: Every src/core/ and src/models/ file has a test ---
echo -n "Checking test coverage completeness... "
MISSING_TESTS=0
for f in $(find src/core/ src/models/ -name "*.gd" -type f 2>/dev/null); do
    BASENAME=$(basename "$f" .gd)
    TEST_FILE="tests/unit/test_${BASENAME}.gd"
    if [ ! -f "$TEST_FILE" ]; then
        if [ $MISSING_TESTS -eq 0 ]; then
            echo -e "${RED}FAIL${NC}"
        fi
        echo "  Missing test: $TEST_FILE (for $f)"
        ((MISSING_TESTS++))
    fi
done
if [ $MISSING_TESTS -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
else
    ((ERRORS++))
fi

# --- Check 6: Run GUT tests ---
echo -n "Running GUT tests... "
if command -v godot &> /dev/null; then
    TEST_OUTPUT=$(godot --headless -s addons/gut/gut_cmdln.gd \
        -gdir=res://tests -ginclude_subdirs -gexit 2>&1)
    if echo "$TEST_OUTPUT" | grep -q "All tests passed"; then
        PASSED=$(echo "$TEST_OUTPUT" | grep "Passing Tests" | awk '{print $NF}')
        TOTAL=$(echo "$TEST_OUTPUT" | grep "^Tests " | awk '{print $NF}')
        echo -e "${GREEN}OK${NC} ($PASSED/$TOTAL passed)"
    else
        echo -e "${RED}FAIL${NC}"
        echo "$TEST_OUTPUT" | tail -20
        ((ERRORS++))
    fi
else
    echo -e "${YELLOW}SKIP (godot not in PATH)${NC}"
    ((WARNINGS++))
fi

# --- Summary ---
echo ""
echo "========================================="
if [ $ERRORS -gt 0 ]; then
    echo -e " Result: ${RED}$ERRORS ERROR(S)${NC}, $WARNINGS warning(s)"
    echo "========================================="
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e " Result: ${GREEN}PASSED${NC} with ${YELLOW}$WARNINGS warning(s)${NC}"
    echo "========================================="
    exit 0
else
    echo -e " Result: ${GREEN}ALL CHECKS PASSED${NC}"
    echo "========================================="
    exit 0
fi
