---
type: question
status: answered
asked_by: demo
asked_on: 2026-10-20
scenarios:
  - "[[Second filler]]"
  - "[[Two more fermenters]]"
  - "[[Changeover cut by 15 minutes]]"
  - "[[Saturday packaging shift]]"
---
# Where should we invest?

## Question

We run short every summer. Where should we invest to fix it: a second filler, more fermenters, faster changeovers, or Saturday packaging? Don't change demand.

## Answer

**Fermenters.** In this (synthetic) plant, the brewery is tank-limited: lager ties up a fermenter for about three weeks, and for 41% of the year the production plan wanted to brew but every fermenter was full. Two more fermenters lift the service level by about 7 points; nothing on the packaging side comes close.

| Option | Service level | Change vs Baseline (paired 95% interval) | Bottleneck afterwards |
|---|---|---|---|
| [[Baseline]] | 87.6% | | Fermenters |
| [[Two more fermenters]] | 94.6% | +7.0 pts (+5.5 to +8.5) | Packaging line (filler) |
| [[Second filler]] | 90.5% | +2.9 pts (+2.1 to +3.7) | Fermenters |
| [[Saturday packaging shift]] | 90.1% | +2.5 pts (+1.7 to +3.3) | Fermenters |
| [[Changeover cut by 15 minutes]] | 87.3% | -0.2 pts (-1.0 to +0.5): no measurable change | Fermenters |

Two things worth knowing:

- **Packaging changes help a little, through timing rather than volume.** The plant packages almost the same hectolitres in every scenario, because demand caps it. A second line or a Saturday shift means beer waits less in bright tanks over the weekend, so more of it is on the shelf when orders arrive. A Saturday shift buys about as much of this as a second line (their intervals overlap), for no capital.
- **After two more fermenters, the packaging line becomes the constraint** (filler 86% of on-shift time vs fermenters 83%). The next question is therefore "two more fermenters *and* a Saturday shift?", which is one scenario note away.

Full numbers: `Results/Comparison`.

**What the model cannot tell you:** costs (it has none, so it can't rank by return); anything about real plants (every number is an illustrative assumption); whether the production plan is a good one (it is a simple cover rule, and a better plan might pre-build more stock in spring for free).
