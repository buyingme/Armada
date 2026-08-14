#!/usr/bin/env bash

# create_bundle.sh
#
# Creates consolidated Markdown bundles of all currently open and
# verification-pending QA issues.
#
# The bundles are temporary analysis artifacts. They make it easy to review,
# prioritize, or provide all active BUG and UX issues to an external review
# or AI tool without manually copying the individual issue files.
#
# Sources:
#   docs/qa/bugs/open/
#   docs/qa/bugs/verify/
#   docs/qa/ux/open/
#   docs/qa/ux/verify/
#
# Outputs:
#   docs/qa/BUG-BUNDLE.md
#   docs/qa/UX-BUNDLE.md
#
# Usage:
#   Run from the repository root:
#
#     ./scripts/create_bundle.sh
#
# The output files are regenerated on every run.
# Individual issue files remain the authoritative QA records.

set -e

BUG_BUNDLE="docs/qa/BUG-BUNDLE.md"
UX_BUNDLE="docs/qa/UX-BUNDLE.md"

echo "Creating ${BUG_BUNDLE}..."

for f in $(find docs/qa/bugs/open docs/qa/bugs/verify -type f -name "*.md" | sort); do
  echo -e "\n\n===== FILE: $f =====\n"
  cat "$f"
done > "$BUG_BUNDLE"

echo "Creating ${UX_BUNDLE}..."

for f in $(find docs/qa/ux/open docs/qa/ux/verify -type f -name "*.md" | sort); do
  echo -e "\n\n===== FILE: $f =====\n"
  cat "$f"
done > "$UX_BUNDLE"

echo "Done."
echo "Created:"
echo "  ${BUG_BUNDLE}"
echo "  ${UX_BUNDLE}"
