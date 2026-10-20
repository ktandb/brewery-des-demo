---
type: result
scenario: comparison
generated: 2026-10-20 13:24
---
# Comparison of scenarios

*Written by `R/run.R --compare`; do not edit by hand. Synthetic plant.*

| Scenario | Changes | Service level (95% interval) | vs Baseline | Packaged hL/yr | Back orders at year end (hL) | Fermenters active | Filler occupied | Plan blocked by full tanks | Bottleneck | Runtime (s) |
|---|---|---|---|---|---|---|---|---|---|---|
| [[Baseline]] | NA | **87.6%** (85.5% to 89.7%) |  | 268,806 | 0 | 91% | 86% | 41% | Fermenters | 3 |

![Service level by scenario](img/comparison-service.png)

Each scenario runs the same random-number seeds per replication (common random numbers), so differences between scenarios are less noisy than the intervals suggest.
