---
type: station
role: warehouse
capacity: 5000
capacity_unit: pallet positions
shift: continuous
next: "[[Dispatch]]"
sources:
  capacity: illustrative assumption (about seven weeks of average demand)
---
# Warehouse

Finished pallets wait here for orders. The warehouse is a store, not a machine: its "utilisation" is how full it is.

The production plan will not start a new brew if the pallets in stock plus the pallets already in tanks would overflow the warehouse.

**Units:** capacity in pallet positions.
