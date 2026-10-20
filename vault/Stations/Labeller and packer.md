---
type: station
role: labeller
capacity: 1
capacity_unit: machine sets
line_speed:
  can:
    value: 33000
    unit: containers/h
  bottle:
    value: 26400
    unit: containers/h
shift: packaging
failure:
  mtbf:
    value: 60
    unit: h
  mttr:
    dist: lognormal
    mean: 0.5
    sd: 0.4
    unit: h
next: "[[Palletiser]]"
sources:
  line_speed: "public rule of thumb (packaging-line 'V-curve'): machines downstream of the filler are rated about 10-25% faster so the filler rarely waits; 10% used here"
  failure: illustrative assumption
---
# Labeller and packer

Labels bottles, then packs cans and bottles into cases. It sits in line with the filler, so the line runs at the speed of its slowest machine, and when this machine stops, the filler stops too.

Each filling line needs one of these. With two fillers and one labeller and packer, the second filler would mostly stand idle.

**Units:** capacity in machine sets; line speed in containers per hour; MTBF and MTTR in hours of operation.
