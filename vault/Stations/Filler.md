---
type: station
role: filler
capacity: 1
capacity_unit: filling lines
line_speed:
  can:
    value: 30000
    unit: containers/h
  bottle:
    value: 24000
    unit: containers/h
efficiency_pct: 80
loss_pct: 1.5
changeovers: Changeovers
shift: packaging
failure:
  mtbf:
    value: 40
    unit: h
  mttr:
    dist: lognormal
    mean: 1.0
    sd: 0.8
    unit: h
next: "[[Labeller and packer]]"
sources:
  line_speed: "illustrative assumption; within the range of mid-size can and bottle lines"
  efficiency_pct: "public rule of thumb: packaging lines typically run at 60-85% of rated speed once minor stops and speed losses are counted"
  loss_pct: illustrative assumption
  failure: illustrative assumption (major breakdowns only; minor stops are in efficiency_pct)
---
# Filler

Fills cans or bottles from a bright tank. One line that can run either format, so switching between cans and bottles costs a changeover (see the Changeovers rule). Changing beer or pack within the same format costs a shorter one.

The filler sets the pace of the packaging line: the labeller, packer and palletiser are rated faster on purpose. Rated speed is in containers per hour; the model converts it to hL/h using each product's container size, then applies `efficiency_pct` for minor stops and slow running. Big breakdowns are separate (`failure`).

Runs on the `packaging` shift calendar: Monday to Friday, 06:00 to 22:00.

**Units:** capacity in filling lines; line speed in containers per hour; efficiency and loss in per cent; MTBF and MTTR in hours of operation.
