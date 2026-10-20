---
type: station
role: palletiser
capacity: 1
capacity_unit: palletisers
line_speed:
  value: 40
  unit: pallets/h
shift: packaging
failure:
  mtbf:
    value: 150
    unit: h
  mttr:
    dist: lognormal
    mean: 0.75
    sd: 0.5
    unit: h
next: "[[Warehouse]]"
sources:
  line_speed: illustrative assumption (comfortably faster than the filler, per the V-curve rule)
  failure: illustrative assumption
---
# Palletiser

Stacks cases onto pallets and stretch-wraps them. In line with the filler and the labeller and packer: if it stops, the line stops. A batch of beer **becomes pallets** here; pallet sizes per product are in the Products rule.

**Units:** capacity in palletisers; line speed in pallets per hour; MTBF and MTTR in hours of operation.
