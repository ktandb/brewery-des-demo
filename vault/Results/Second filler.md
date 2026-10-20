---
type: result
scenario: "[[Second filler]]"
generated: 2026-10-20 13:25
replications: 40
simulated: 52 weeks after a warm-up
runtime_seconds: 2.7
service_level: 0.9050
bottleneck: "Fermenters"
---
# Results: Second filler

*Written by `R/run.R`; do not edit by hand. Synthetic plant: every input is an illustrative assumption or a rule of thumb.*

> **Question:** Would a second filling line fix our summer shortfalls?

## Headline

Service level **90.5%** (95% interval 88.8% to 92.2%) of 253,969 hL ordered. The bottleneck is **Fermenters** (92% of its available time in use, excluding time spent blocked); next tightest is Brewhouse at 68%. For 40% of the year's hours the production plan wanted to brew but every fermenter was full.

## Changes from the plant notes

- `Filler.capacity` = 2
- `Labeller and packer.capacity` = 2
- `Palletiser.capacity` = 2

## Throughput and demand (measured year)

| Measure | Mean | 95% interval |
|---|---|---|
| Demand ordered (hL) | 253,969 | 252,439 to 255,500 |
| Beer packaged (hL) | 266,609 | 265,273 to 267,944 |
| Packaged / ordered | 105.0% | |
| Service level (share shipped on the day ordered) | 90.5% | 88.8% to 92.2% |
| Back orders at year end (hL) | 0 | 0 to 0 |
| Fermenter fills packaged | 349 | |
| Hours the plan wanted beer but all fermenters were full | 40% | 38% to 42% |
| Changeover hours on the filler | 200 | |

![Weekly demand and output](img/second-filler-weekly.png)

## Utilisation per station

Share of each station's *available* time (on shift, all units) that it was occupied. **Active** excludes time a tank sat full waiting for the next step, which is a symptom of a constraint downstream, not work. Queue is the time-averaged number of batches (or trucks) waiting; wait is the mean hours a batch waited to get in.

| Station | Units on shift (mean) | Occupied | Blocked | Breakdowns + changeovers | Active | Mean queue | Mean wait (h) |
|---|---|---|---|---|---|---|---|
| Brewhouse | 0.9 | 68% | 0% | 1% | **68%** | 0.30 | 5.9 |
| Fermenters | 22.0 | 92% | 0% | 0% | **92%** | 0.00 |  |
| Bright tanks | 6.0 | 43% | 8% | 0% | **34%** | 0.02 | 0.4 |
| Filler | 0.9 | 44% | 0% | 5% | **44%** | 0.80 | 12.1 |
| Labeller and packer | 0.9 | 43% | 0% | 1% | **43%** | 0.27 |  |
| Palletiser | 0.9 | 43% | 0% | 0% | **43%** | 0.26 |  |
| Dispatch | 0.9 | 11% | 0% | 0% | **11%** | 0.16 |  |
| Warehouse | 5,000 pallet positions | 16% | 0% | 0% | **16%** |  |  |

![Utilisation by station](img/second-filler-utilisation.png)

![Stock and back orders](img/second-filler-stock.png)

![Fermenter occupancy](img/second-filler-fermenters.png)

## How to read the bottleneck

The bottleneck is the station with the highest *active* utilisation. The packaging line (filler, labeller and packer, palletiser) runs as one unit, so the three machines show nearly the same figure; the filler paces it. Wait at Bright tanks is the time beer sat in a full fermenter waiting for a bright tank; wait at the filler is the time beer sat in a bright tank waiting for the line.

Runtime: 2.7 s for 40 replications. Raw numbers: `Results/data/second-filler.csv` and `second-filler-replications.csv`.
