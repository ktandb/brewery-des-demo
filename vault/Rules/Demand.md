---
type: rule
rule: demand
applies_to:
  - "[[Dispatch]]"
  - "[[Warehouse]]"
base_hl_per_week: 5000
seasonality:
  - weeks: "1-4"
    factor: 0.8
  - weeks: "22-35"
    factor: 1.35
  - weeks: "49-51"
    factor: 1.2
noise_cv: 0.15
order_days: [Mon, Tue, Wed, Thu, Fri]
order_time: "06:00"
planning:
  cover_weeks: 5
  initial_stock_weeks: 2
warmup_weeks: 6
sources:
  base_hl_per_week: "illustrative assumption (about 280,000 hL a year, a mid-size lager brewery)"
  seasonality: "illustrative assumption; a summer peak and a Christmas bump are the familiar shape of UK beer sales"
  noise_cv: illustrative assumption
  planning: illustrative assumption
---
# Demand

Customers order **pallets** of each product every weekday at 06:00. The week's volume is `base_hl_per_week` times the seasonal factor for that week, with random week-to-week noise (coefficient of variation 15%), split across products by their share (see Products) and spread evenly over the five order days.

| Weeks | Factor | Why |
|---|---|---|
| 1-4 | 0.8 | January lull |
| 22-35 | 1.35 | Summer peak (June to August) |
| 49-51 | 1.2 | Christmas |
| all others | 1.0 | |

Orders are shipped from stock on the day if the pallets are there. Anything short is a **back order**, shipped late as soon as pallets arrive. *Service level* means the share of ordered pallets shipped on the day they were ordered.

**Production plan.** The brewhouse brews a product when the stock of it, plus what is already in the tanks for it, minus its back orders, is less than the expected demand for it over the next `cover_weeks` (5) weeks. When several products are short, it brews the one with the biggest gap in hL. The plant starts with two weeks of stock, and the first `warmup_weeks` (6) of the simulation are discarded so the tanks are full before measurement starts; the measured year is weeks 1 to 52.
