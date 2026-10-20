---
type: guide
---
# Start here

This vault describes a **made-up, mid-size lager brewery**. Every number in it is synthetic: either an *illustrative assumption* or a public rule of thumb, and each one says which. Nothing comes from a real plant.

The vault is the model. A small R script (`R/run.R`, one folder up) reads these notes, simulates a year of brewing and packaging many times over, and writes what it found back into `Results/`. Nobody edits the script to change the plant: you edit a note.

## What is in here

| Folder | What it holds | Who edits it |
|---|---|---|
| `Stations/` | One note per step of the plant: capacity, process times, changeovers, breakdowns, and `next:` (where the beer goes after this step) | You |
| `Rules/` | Rules that cut across stations: shifts, changeovers, stoppages, demand, products | You |
| `Scenarios/` | "What if" notes. Each one changes a few numbers (`overrides:`) and asks a question in plain English | You or the agent |
| `Questions/` | Questions written for the agent (see `Templates/Ask a question`) | You write, the agent answers |
| `Results/` | Written by the script. One note per scenario plus `Comparison` | The script (don't hand-edit; it is overwritten) |

## How to read a note

The block at the top of each note (Obsidian shows it as **Properties**) is what the model reads. The text underneath is for people. If the two disagree, the model believes the properties.

Times always carry a unit (`min`, `h` or `d`). Random times are written as a distribution:

```yaml
process_time:
  dist: triangular   # fixed | uniform | triangular | normal | lognormal | exponential
  min: 16
  mode: 19
  max: 24
  unit: d
```

## How to change the plant

1. Open a station or rule note and change a property, e.g. `capacity: 22` to `capacity: 24` in [[Fermenters]].
2. Run `Rscript R/run.R Baseline` (or ask the agent to).
3. Read `Results/Baseline`. If a note is broken (a link to a station that doesn't exist, a time with no unit, an unknown distribution), the script stops and names the note.

For a "what if" that you want to keep alongside the baseline, don't edit the station: copy a note in `Scenarios/` and put the change in its `overrides:`.

## The flow

Open the **graph view** (left ribbon, or Ctrl/Cmd+G). Blue nodes are stations; the arrows are their `next:` links, so the graph *is* the plant flow:

Brewhouse → Fermenters → Bright tanks → Filler → Labeller and packer → Palletiser → Warehouse → Dispatch

Begin at [[Brewhouse]].

## Ask a question

Copy `Templates/Ask a question` into `Questions/`, write the question in plain words, and ask the agent (Claude Code, run from the repo folder) to "answer the open questions". It turns the question into one or more scenario notes, runs them, and writes the answer back into your question note with links to the results. Every step is a git commit, so the history shows what was asked and what was changed.

**See the plant.** Open [[Canvas/Baseline.canvas|the Baseline canvas]]: each station coloured by how busy it is, the bottleneck marked ▲. [[Canvas/Comparison.canvas|The comparison canvas]] shows every scenario side by side.
