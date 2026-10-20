---
type: result
scenario: "[[Changeover cut by 15 minutes]]"
generated: 2026-10-20 13:32
replications: 40
simulated: 52 weeks after a warm-up
runtime_seconds: 2.8
service_level: 0.8735
bottleneck: "Fermenters"
---
# Results: Changeover cut by 15 minutes

*Written by `R/run.R`; do not edit by hand. Synthetic plant: every input is an illustrative assumption or a rule of thumb.*

> **Question:** What is a 15-minute cut in every changeover worth?

## Headline

Service level **87.3%** (95% interval 85.2% to 89.5%) of 253,969 hL ordered. The bottleneck is **Fermenters** (91% of its available time in use, excluding time spent blocked); next tightest is Filler at 84%. For 41% of the year's hours the production plan wanted to brew but every fermenter was full.

## Changes from the plant notes

- `Changeovers.format_change.value` = 45
- `Changeovers.product_change.value` = 15

## Throughput and demand (measured year)

| Measure | Mean | 95% interval |
|---|---|---|
| Demand ordered (hL) | 253,969 | 252,439 to 255,500 |
| Beer packaged (hL) | 268,653 | 267,190 to 270,117 |
| Packaged / ordered | 105.8% | |
| Service level (share shipped on the day ordered) | 87.3% | 85.2% to 89.5% |
| Back orders at year end (hL) | 0 | 0 to 0 |
| Fermenter fills packaged | 351 | |
| Hours the plan wanted beer but all fermenters were full | 41% | 39% to 43% |
| Changeover hours on the filler | 147 | |

![Weekly demand and output](img/changeover-cut-by-15-minutes-weekly.png)

## Utilisation per station

Share of each station's *available* time (on shift, all units) that it was occupied. **Active** excludes time a tank sat full waiting for the next step, which is a symptom of a constraint downstream, not work. Queue is the time-averaged number of batches (or trucks) waiting; wait is the mean hours a batch waited to get in.

| Station | Units on shift (mean) | Occupied | Blocked | Breakdowns + changeovers | Active | Mean queue | Mean wait (h) |
|---|---|---|---|---|---|---|---|
| Brewhouse | 0.9 | 68% | 0% | 1% | **68%** | 0.30 | 5.8 |
| Fermenters | 22.0 | 92% | 0% | 0% | **91%** | 0.00 |  |
| Bright tanks | 6.0 | 57% | 21% | 0% | **36%** | 0.06 | 1.4 |
| Filler | 0.5 | 84% | 0% | 6% | **84%** | 1.67 | 31.2 |
| Labeller and packer | 0.5 | 84% | 0% | 1% | **84%** | 0.38 |  |
| Palletiser | 0.5 | 84% | 0% | 0% | **84%** | 0.38 |  |
| Dispatch | 0.9 | 11% | 0% | 0% | **11%** | 0.16 |  |
| Warehouse | 5,000 pallet positions | 15% | 0% | 0% | **15%** |  |  |

![Utilisation by station](img/changeover-cut-by-15-minutes-utilisation.png)

![Stock and back orders](img/changeover-cut-by-15-minutes-stock.png)

![Fermenter occupancy](img/changeover-cut-by-15-minutes-fermenters.png)

## How to read the bottleneck

The bottleneck is the station with the highest *active* utilisation. The packaging line (filler, labeller and packer, palletiser) runs as one unit, so the three machines show nearly the same figure; the filler paces it. Wait at Bright tanks is the time beer sat in a full fermenter waiting for a bright tank; wait at the filler is the time beer sat in a bright tank waiting for the line.

Runtime: 2.8 s for 40 replications. Raw numbers: `Results/data/changeover-cut-by-15-minutes.csv` and `changeover-cut-by-15-minutes-replications.csv`.
