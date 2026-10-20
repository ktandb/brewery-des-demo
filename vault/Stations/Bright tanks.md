---
type: station
role: bright
capacity: 6
capacity_unit: tanks
tank_size_hl: 800
transfer_time:
  dist: triangular
  min: 6
  mode: 8
  max: 10
  unit: h
process_time:
  dist: fixed
  value: 24
  unit: h
process_time_per: tank fill (minimum hold before packaging)
cip:
  dist: fixed
  value: 3
  unit: h
shift: continuous
next: "[[Filler]]"
sources:
  capacity: illustrative assumption
  transfer_time: illustrative assumption (filtration and transfer of 800 hL)
  process_time: illustrative assumption (carbonation check and quality release)
  cip: illustrative assumption
---
# Bright tanks

Filtered, finished beer waits here for the packaging line. Each tank takes one fermenter's worth of beer.

A bright tank is occupied from CIP, through filtration and transfer in from a fermenter, a minimum 24-hour hold for carbonation and quality release, and then until the filler has emptied it. Beer that is ready on a Saturday waits here until the line runs on Monday; if every bright tank is full, the fermenters behind them back up.

**Units:** capacity in tanks; tank size in hL; times in hours.
