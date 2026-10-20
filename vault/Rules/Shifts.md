---
type: rule
rule: shifts
applies_to:
  - "[[Brewhouse]]"
  - "[[Filler]]"
  - "[[Labeller and packer]]"
  - "[[Palletiser]]"
  - "[[Dispatch]]"
calendars:
  continuous:
    days: [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
    start: "00:00"
    end: "24:00"
  brewhouse:
    days: [Mon, Tue, Wed, Thu, Fri, Sat]
    start: "00:00"
    end: "24:00"
  packaging:
    days: [Mon, Tue, Wed, Thu, Fri]
    start: "06:00"
    end: "22:00"
  dispatch:
    days: [Mon, Tue, Wed, Thu, Fri]
    start: "06:00"
    end: "22:00"
sources:
  calendars: illustrative assumption (two eight-hour packaging shifts on weekdays; no packaging at weekends)
---
# Shifts

When each part of the plant is staffed. A station names its calendar in its `shift:` property.

- **continuous**: tanks and the warehouse never stop; beer keeps fermenting at weekends.
- **brewhouse**: 24 hours, Monday to Saturday. No brewing on Sundays.
- **packaging**: two shifts, 06:00 to 22:00, Monday to Friday. **No packaging on Saturdays or Sundays.** A batch that is half packaged at 22:00 on Friday finishes on Monday morning.
- **dispatch**: 06:00 to 22:00, weekdays.

To try a Saturday packaging shift, add `Sat` to `packaging.days` (the "Saturday packaging shift" scenario does exactly this as an override).
