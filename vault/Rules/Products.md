---
type: rule
rule: products
applies_to:
  - "[[Filler]]"
  - "[[Palletiser]]"
  - "[[Demand]]"
skus:
  - name: Premium lager 440ml can
    code: PL-C440
    format: can
    container_ml: 440
    containers_per_case: 24
    cases_per_pallet: 80
    share: 0.55
  - name: Premium lager 330ml bottle
    code: PL-B330
    format: bottle
    container_ml: 330
    containers_per_case: 24
    cases_per_pallet: 84
    share: 0.30
  - name: Session lager 440ml can
    code: SL-C440
    format: can
    container_ml: 440
    containers_per_case: 24
    cases_per_pallet: 80
    share: 0.15
sources:
  skus: illustrative assumption (invented products; pack sizes typical of UK retail)
---
# Products

Three made-up products. Both beers are lagers and ferment the same way; they differ only in how they are packed.

| Product | Format | Pack | Pallet holds | Share of demand |
|---|---|---|---|---|
| Premium lager 440ml can | can | 24 x 440 ml | 80 cases = 8.4 hL | 55% |
| Premium lager 330ml bottle | bottle | 24 x 330 ml | 84 cases = 6.7 hL | 30% |
| Session lager 440ml can | can | 24 x 440 ml | 80 cases = 8.4 hL | 15% |

Shares must add up to 1. Each brew is one product from the brewhouse to the pallet.
