---
type: result
scenario: "[[Saturday packaging shift]]"
generated: 2026-10-20 13:25
replications: 40
simulated: 52 weeks after a warm-up
runtime_seconds: 2.5
service_level: 0.9010
bottleneck: "Fermenters"
---
# Results: Saturday packaging shift

*Written by `R/run.R`; do not edit by hand. Synthetic plant: every input is an illustrative assumption or a rule of thumb.*

> **Question:** Would adding Saturday packaging shifts help?

## Headline

Service level **90.1%** (95% interval 88.4% to 91.8%) of 253,969 hL ordered. The bottleneck is **Fermenters** (91% of its available time in use, excluding time spent blocked); next tightest is Filler at 71%. For 39% of the year's hours the production plan wanted to brew but every fermenter was full.

## Changes from the plant notes

- `Shifts.calendars.packaging.days` = Mon, Tue, Wed, Thu, Fri, Sat

## Throughput and demand (measured year)

| Measure | Mean | 95% interval |
|---|---|---|
| Demand ordered (hL) | 253,969 | 252,439 to 255,500 |
| Beer packaged (hL) | 267,239 | 265,810 to 268,669 |
| Packaged / ordered | 105.2% | |
| Service level (share shipped on the day ordered) | 90.1% | 88.4% to 91.8% |
| Back orders at year end (hL) | 0 | 0 to 0 |
| Fermenter fills packaged | 350 | |
| Hours the plan wanted beer but all fermenters were full | 39% | 37% to 41% |
| Changeover hours on the filler | 206 | |

![Weekly demand and output](img/saturday-packaging-shift-weekly.png)

## Utilisation per station

Share of each station's *available* time (on shift, all units) that it was occupied. **Active** excludes time a tank sat full waiting for the next step, which is a symptom of a constraint downstream, not work. Queue is the time-averaged number of batches (or trucks) waiting; wait is the mean hours a batch waited to get in.

| Station | Units on shift (mean) | Occupied | Blocked | Breakdowns + changeovers | Active | Mean queue | Mean wait (h) |
|---|---|---|---|---|---|---|---|
| Brewhouse | 0.9 | 68% | 0% | 1% | **68%** | 0.30 | 5.9 |
| Fermenters | 22.0 | 91% | 0% | 0% | **91%** | 0.00 |  |
| Bright tanks | 6.0 | 44% | 10% | 0% | **34%** | 0.01 | 0.2 |
| Filler | 0.6 | 71% | 0% | 7% | **71%** | 0.89 | 15.3 |
| Labeller and packer | 0.6 | 71% | 0% | 1% | **71%** | 0.26 |  |
| Palletiser | 0.6 | 71% | 0% | 1% | **71%** | 0.25 |  |
| Dispatch | 0.9 | 11% | 0% | 0% | **11%** | 0.26 |  |
| Warehouse | 5,000 pallet positions | 18% | 0% | 0% | **18%** |  |  |

![Utilisation by station](img/saturday-packaging-shift-utilisation.png)

![Stock and back orders](img/saturday-packaging-shift-stock.png)

![Fermenter occupancy](img/saturday-packaging-shift-fermenters.png)

## How to read the bottleneck

The bottleneck is the station with the highest *active* utilisation. The packaging line (filler, labeller and packer, palletiser) runs as one unit, so the three machines show nearly the same figure; the filler paces it. Wait at Bright tanks is the time beer sat in a full fermenter waiting for a bright tank; wait at the filler is the time beer sat in a bright tank waiting for the line.

Runtime: 2.5 s for 40 replications. Raw numbers: `Results/data/saturday-packaging-shift.csv` and `saturday-packaging-shift-replications.csv`.
