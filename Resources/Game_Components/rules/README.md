# Rules Reference Catalog

This folder holds static rules-reference JSON for the fleet builder.

The goal is one display source for generic rules such as squadron keywords,
commands, defense tokens, attack timing, setup, obstacles, scoring, and other
Core Set rules. Components link to these records through `rules_reference_ids`.

Rules-reference JSON is not executable gameplay logic. Live effects belong in
`src/core/effects/rules/`, are registered through `RuleBootstrap`, and are listed
by id in `implemented_rule_ids` or component `rules_integration` metadata.

Expected record shape:

```json
{
  "data_key": "squadron_keyword.bomber",
  "kind": "rules_reference",
  "scope": "GENERIC",
  "display_name": "Bomber",
  "category": "SQUADRON_KEYWORD",
  "rules_text": "Full local rules text.",
  "summary": "Short display/search summary.",
  "search_tags": ["squadron", "keyword", "bomber"],
  "source_refs": ["RRG 1.5.0 Squadron Keywords"],
  "implemented_rule_ids": ["squadron_keyword.bomber"],
  "implementation_status": "INTEGRATED"
}
```

FB1 adds the first records for implemented squadron keywords. FB3 is expected to
broaden the catalog with more generic Core Set rules and component-specific
records.
