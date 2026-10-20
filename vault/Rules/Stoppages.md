---
type: rule
rule: stoppages
applies_to:
  - "[[Filler]]"
  - "[[Labeller and packer]]"
  - "[[Palletiser]]"
  - "[[Brewhouse]]"
planned:
  - name: Packaging planned maintenance
    calendar: packaging
    every_weeks: 4
    day: Mon
    start: "06:00"
    duration:
      value: 8
      unit: h
  - name: Christmas shutdown
    calendar: [packaging, dispatch, brewhouse]
    weeks: [52]
    days: [Thu, Fri]
breakdowns:
  time_between: exponential
  clock: operating hours
sources:
  planned: illustrative assumption
  breakdowns: "standard DES modelling convention: exponential time between failures with the station's MTBF"
---
# Stoppages

Two kinds of lost time.

**Planned.** The packaging line is down for maintenance for the first shift (06:00 to 14:00) of every fourth Monday. Packaging, dispatch and the brewhouse shut for two days in the last week of the year.

**Unplanned breakdowns.** Each station with a `failure:` property breaks down at random. The time between breakdowns is exponential with the station's MTBF (mean time between failures), counted in hours the station is on shift; the repair takes a random time with the station's MTTR distribution. A breakdown on the filler, labeller and packer or palletiser stops the whole packaging line until it is repaired.

Minor stops (jams, a few minutes each) are not modelled as breakdowns; they are folded into the filler's `efficiency_pct`.
