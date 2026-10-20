---
type: station
role: fermentation
capacity: 22
capacity_unit: tanks
tank_size_hl: 800
process_time:
  dist: triangular
  min: 16
  mode: 19
  max: 24
  unit: d
process_time_per: tank fill
cip:
  dist: fixed
  value: 4
  unit: h
loss_pct: 3
shift: continuous
next: "[[Bright tanks]]"
sources:
  capacity: illustrative assumption
  tank_size_hl: "illustrative assumption; multi-brew fills of cylindroconical tanks are standard practice (brewing textbooks)"
  process_time: "public rule of thumb: primary fermentation about a week plus cold maturation of one to three weeks for lager; 16-24 days total is a typical modern range"
  cip: illustrative assumption
  loss_pct: "illustrative assumption (yeast and filtration losses of a few per cent are commonly quoted)"
---
# Fermenters

Cylindroconical tanks where wort becomes lager: primary fermentation, then cold conditioning (lagering). This is the slow step: a tank is tied up for **about three weeks** per fill.

A tank is occupied from the start of cleaning-in-place (CIP) before it is filled, through filling (four brews of 200 hL), fermentation and conditioning, until the beer can move to a free bright tank. If no bright tank is free, the beer waits in the fermenter and the tank stays blocked.

**Units:** capacity in tanks; tank size in hL; process time (fermentation plus conditioning) in days per tank fill; CIP in hours; loss as a percentage of volume.
