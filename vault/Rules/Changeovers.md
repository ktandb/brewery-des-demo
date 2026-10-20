---
type: rule
rule: changeovers
applies_to:
  - "[[Filler]]"
format_change:
  dist: fixed
  value: 60
  unit: min
product_change:
  dist: fixed
  value: 30
  unit: min
sources:
  format_change: illustrative assumption (can <-> bottle on a dual-format line)
  product_change: "illustrative assumption (same container, different beer or pack: flush and label/pack change)"
---
# Changeovers

Time lost on the filling line between batches.

- **Format change**, can to bottle or bottle to can: 60 minutes.
- **Product change**, same format but a different product (e.g. Premium lager can to Session lager can): 30 minutes.
- Same product as the last batch on that line: no changeover.

The line is stopped during a changeover, and changeovers only happen on shift.
