---
type: station
role: dispatch
capacity: 2
capacity_unit: loading bays
pallets_per_truck: 26
process_time:
  dist: triangular
  min: 30
  mode: 40
  max: 60
  unit: min
process_time_per: truck
shift: dispatch
sources:
  capacity: illustrative assumption
  pallets_per_truck: "public rule of thumb: a UK articulated trailer carries about 26 standard pallets"
  process_time: illustrative assumption
---
# Dispatch

Loads trucks for customers. Orders arrive every weekday morning (see the Demand rule); they are shipped from warehouse stock if it is there, and otherwise wait as back orders until the next pallets come off the line.

The end of the flow: no `next`.

**Units:** capacity in loading bays; pallets per truck; loading time in minutes per truck.
