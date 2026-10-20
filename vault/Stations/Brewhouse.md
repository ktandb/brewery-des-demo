---
type: station
role: brewhouse
start: true
capacity: 1
capacity_unit: brewhouse
brew_length_hl: 200
process_time:
  dist: triangular
  min: 3.0
  mode: 3.5
  max: 4.5
  unit: h
process_time_per: brew
shift: brewhouse
failure:
  mtbf:
    value: 300
    unit: h
  mttr:
    dist: lognormal
    mean: 3
    sd: 1.5
    unit: h
next: "[[Fermenters]]"
sources:
  brew_length_hl: illustrative assumption
  process_time: "public rule of thumb: modern lauter-tun brewhouses manage roughly 8-12 brews a day, i.e. a brew every 2-3 h; 3.5 h is deliberately conservative (brewing textbooks, e.g. Kunze, Technology Brewing and Malting)"
  failure: illustrative assumption
---
# Brewhouse

Mashes, lauters, boils and cools wort, one **brew** at a time. A brew is 200 hL of cold wort.

The brewhouse only starts brewing when the production plan wants more beer *and* a fermenter is free to receive it. It fills one fermenter with several brews in a row (see Fermenters for the tank size), so one fermenter fill takes about four brew cycles.

Runs round the clock Monday to Saturday (shift calendar `brewhouse` in the Shifts note). Breakdowns are rare but long.

**Units:** capacity in brewhouses; process time per brew; brew length in hectolitres (hL).
