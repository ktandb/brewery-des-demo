# brewery-des-demo: instructions for Claude Code

This repo is a discrete-event simulation of a **synthetic** brewery. The plant lives in `vault/` as Obsidian notes; `R/run.R` reads them, simulates, and writes `vault/Results/`. You are the scaffold between a question someone writes in a note and the model runs that answer it.

## Answering a question note

When asked to "answer the open questions" (or a specific one):

1. Find notes in `vault/Questions/` with `status: open`. Read the question, and read the station and rule notes it touches.
2. Turn it into scenarios. Each scenario is a note in `vault/Scenarios/` with front matter:
   ```yaml
   type: scenario
   question: "One line, plain English"
   overrides:
     "Note name.field.subfield": value
   ```
   Keys are `<note title>.<property path>`; the note title is the file name without `.md`. Reuse an existing scenario if it already asks the same thing. Change as few parameters as answer the question; say in the body why each value was chosen and whether it is an illustrative assumption.
3. Run each new scenario: `Rscript R/run.R "<Scenario name>"`, then `Rscript R/run.R --compare` to refresh `Results/Comparison.md`. (On the butler, use `~/miniconda/envs/renv/bin/Rscript`.)
4. Write the answer into the question note under `## Answer`: the headline in one or two sentences, a small table, links to the `Results/` notes, and what the model cannot tell you. Set `status: answered`.
5. Commit: one commit per scenario (note + its results), then one for the answer. Message says what was asked and what the model showed.

## Rules

- All data is synthetic. Never add real company data. Label every new number `illustrative assumption` or give a public source.
- Report what the model shows, including when it contradicts the expected answer. Quote the replication interval, not just the mean.
- Don't hand-edit `vault/Results/`; regenerate it.
- Don't change `R/run.R` to answer a question unless the question needs a mechanism the model lacks; if so, say so in the answer and make it a separate commit.
