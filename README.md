# brewery-des-demo

A small, working discrete-event simulation (DES) of a **made-up** mid-size lager brewery, built to show three things:

1. **The plant lives in plain-text notes you own.** Every station, rule and "what if" is an Obsidian note in `vault/`. Capacities, process times, shifts and breakdown rates are properties at the top of each note. Change the plant by editing a note, not code.
2. **A script reads the notes, simulates and writes back.** `R/run.R` parses the vault, checks it, builds a [simmer](https://r-simmer.org) model, runs 40 replications of a simulated year, and writes results into `vault/Results/` as notes with charts.
3. **An agent is the scaffold between a question and the runs.** Write a question in a note; Claude Code (instructions in `CLAUDE.md`) turns it into scenario notes, runs them, and writes the answer back. Git records each step.

## Synthetic data: read this first

Nothing here comes from Heineken, any other brewer, or any real plant. Every number is either labelled **illustrative assumption** or tied to a public rule of thumb (brewing textbooks, packaging-line design conventions), in a `sources:` property next to it. The demand level was calibrated once so that the synthetic plant has plausible headroom (see the commit "Demand: calibrate base..."); no scenario was tuned to give an expected answer. Treat results as a demonstration of the method, not a statement about any brewery.

## Run it

On the butler (`~/repos/brewery-des-demo`):

```sh
~/miniconda/envs/renv/bin/Rscript R/run.R            # every scenario + Results/Comparison.md
~/miniconda/envs/renv/bin/Rscript R/run.R Baseline   # one scenario
~/miniconda/envs/renv/bin/Rscript R/run.R --check    # validate the vault only
~/miniconda/envs/renv/bin/Rscript R/run.R --compare  # rebuild the comparison from saved results
~/miniconda/envs/renv/bin/Rscript R/run.R --reps 10 "Second filler"
```

Anywhere else with R and the packages: `Rscript R/run.R`. The script adds `~/Rlibs/brewery-des` to the library path if it exists.

**Runtime:** about 2.5 to 3 seconds per scenario (40 replications of 58 simulated weeks, in parallel on 9 of the butler's 10 cores); all five scenarios plus the comparison in about 16 seconds including R start-up and charts. One replication takes roughly half a second on one core.

### Versions (butler, 20 Oct 2026)

| | Version |
|---|---|
| R | 4.5.3 (conda env `renv`, aarch64-apple-darwin20) |
| simmer | 4.4.7 |
| simmer.plot | 0.1.19 |
| yaml | 2.3.12 |
| ggplot2 | 4.0.2 |

simmer and simmer.plot live in `~/Rlibs/brewery-des`, not in the `renv` env, so the other project using that env is untouched. The butler has no Xcode command-line tools, so simmer cannot be compiled there; `R/setup.sh` installs CRAN's prebuilt arm64 binary and repoints it at the conda R. On a laptop with a normal R, `install.packages(c("simmer", "simmer.plot", "yaml", "ggplot2"))` is enough.

## The vault

Open `vault/` as a vault in Obsidian. Start with `Start here`.

```
vault/
  Start here.md          how to read and edit the vault
  Stations/              one note per step; next: links give the routing
  Rules/                 Shifts, Changeovers, Stoppages, Demand, Products
  Scenarios/             Baseline + one note per "what if"
  Questions/             questions for the agent, answered in place
  Templates/             "Ask a question" template
  Results/               written by R/run.R: one note per scenario, Comparison, img/, data/
```

### Conventions

- **Properties are the model; the body is for people.** The YAML front matter is what `run.R` reads.
- `type:` is one of `station`, `rule`, `scenario`, `question`, `result`, `guide`.
- **Routing:** each station has `next: "[[Next station]]"`; exactly one has `start: true`. Obsidian's graph view draws these links, so the graph shows the plant flow (stations are blue; arrows are on). The model checks the route has no loops or orphans and matches the order it knows how to simulate.
- **Units are explicit.** Times are `{value, unit}` or a distribution with `unit:` (`min`, `h`, `d`); line speeds are `containers/h` (filler, labeller) or `pallets/h` (palletiser); volumes in hL; capacities say what a unit is (`capacity_unit:`).
- **Distributions:** `fixed`, `uniform`, `triangular`, `normal`, `lognormal`, `exponential`, with the parameters named in `Start here`.
- **Every number has a source** in `sources:`: "illustrative assumption" or a public rule of thumb.
- **Validation errors name the note**, e.g. `In note 'Fermenters': next: links to [[Bright tank]], but there is no note called 'Bright tank'` or `In note 'Filler': 'failure.mttr' uses unknown distribution 'gamma'; use one of fixed, uniform, ...`.

### The model in one paragraph

The unit of flow is one fermenter fill: four 200 hL brews, 800 hL, one product. Every hour a simple production plan checks whether any product's stock, plus beer already in tanks for it, minus its back orders, is below the next five weeks of expected demand; if so, and a fermenter and the brewhouse are free and the warehouse has room, it starts a fill. A fermenter is held from cleaning through brewing and about three weeks of fermentation and conditioning until a bright tank is free. A bright tank is held through a 24-hour minimum hold until the packaging line has emptied it. The packaging line (filler + labeller and packer + palletiser, held together and paced by the slowest machine) runs only on its shift calendar, loses time to changeovers between formats and products, and stops for random breakdowns (exponential, by MTBF in operating hours, repair times from MTTR). Pallets go to the warehouse; weekday orders ship from stock or wait as back orders; trucks of 26 pallets load at two bays. Each result is the mean of 40 replications of a 52-week year after a 6-week warm-up, with 95% intervals.

### How a question becomes a scenario

1. Someone copies `Templates/Ask a question` into `Questions/` and writes the question in plain words.
2. Claude Code, run from this folder, is asked to "answer the open questions". Following `CLAUDE.md`, it reads the question and the notes it touches, and writes one scenario note per option with a few `overrides:`, e.g.
   ```yaml
   type: scenario
   question: "Would two more fermenters fix our summer shortfalls?"
   overrides:
     "Fermenters.capacity": 24
   ```
   Keys are `<note name>.<property path>`; `run.R` refuses an override whose target does not exist.
3. It runs `R/run.R "<scenario>"` for each, then `--compare`.
4. It writes the answer under `## Answer` in the question note, links the results, says what the model cannot tell you, and sets `status: answered`.
5. Each scenario (note + results) is its own commit, so `git log` is the record of what was asked, what changed and what the model said. `Questions/Where should we invest` is a worked example.

## What the baseline model shows

| Scenario | Service level | vs Baseline (paired 95% interval) | Bottleneck |
|---|---|---|---|
| Baseline | 87.6% | | Fermenters (91% active) |
| Two more fermenters | 94.6% | +7.0 pts (+5.5 to +8.5) | Packaging line (filler 86%) |
| Second filler (with its own labeller/palletiser) | 90.5% | +2.9 pts (+2.1 to +3.7) | Fermenters |
| Saturday packaging shift | 90.1% | +2.5 pts (+1.7 to +3.3) | Fermenters |
| Changeover cut by 15 minutes | 87.3% | -0.2 pts (-1.0 to +0.5), within noise | Fermenters |

The synthetic plant is tank-limited: more fermenters help most, and once added, packaging becomes the constraint. Packaging changes help a little, by getting beer out of bright tanks sooner (timing), not by packaging more of it (volume is capped by demand). Details in `vault/Results/Comparison.md`.

## Rough edges

- The route order is fixed in code (brewhouse, fermentation, bright, filler, labeller, palletiser, warehouse, dispatch). The notes can change every number, add units, rename notes and change calendars, but a new kind of station needs code.
- One fermenter fill is one product; no blending, no partial fills, no yeast or QA holds beyond the fixed bright-tank hold.
- The production plan is a simple cover rule. It does not pre-build for summer beyond five weeks ahead, which a real planner would.
- No costs, so the model ranks options by service, not return.
- Breakdowns happen only on shift; one that would start off shift is skipped.
- `vault/.obsidian/graph.json` is committed for the colour groups. Obsidian rewrites it whenever the graph is adjusted; `git checkout vault/.obsidian/graph.json` restores it.

## A 45-minute walk-through

| Minutes | What | Where |
|---|---|---|
| 0-5 | The idea: the plant's rules are notes you own; the model reads them; an agent does the plumbing. All data synthetic. | this README |
| 5-10 | Open the vault, **graph view**: the plant flow drawn from `next:` links. | Obsidian, Ctrl/Cmd+G |
| 10-15 | Open **Fermenters**: properties (capacity, triangular 16-19-24 days, CIP, `sources:`) and the plain-English body. Change one number live to show validation catching a typo. | `Stations/Fermenters` |
| 15-20 | **Run the baseline** (3 seconds) and read `Results/Baseline`: service level, utilisation, the bottleneck and the evidence for it. | terminal, `Results/Baseline` |
| 20-30 | **Ask "where should we invest?"**: write it from the template, ask Claude Code to answer it, watch it write scenario notes and run them. (Fallback: the pre-run `Questions/Where should we invest`.) | `Questions/`, `Scenarios/` |
| 30-38 | **Comparison**: tanks beat fillers here; why packaging still helps a little (timing); the bottleneck moving after the fix. Invite a question from the room and run it (e.g. "two more fermenters and a Saturday shift"). | `Results/Comparison` |
| 38-43 | **`git log`** as the record of decisions: skeleton, stations, rules, model, calibration, baseline tag, one commit per scenario. `git diff baseline -- vault/Scenarios` shows exactly what each what-if changed. | terminal |
| 43-45 | Where this goes for a real plant: the notes are the specification, owned by the people who know the plant. | |
