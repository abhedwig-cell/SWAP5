# F-PE-REPRO01 D2 — pre-trial read isolation

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

## Trigger

D1 reduced the exact route to:

`initialize -> trial(href)`

and produced 40/40 PASS with identical solver diagnostics.

In the full live test, the intermittent status-6 failure occurs at that same first `trial(href)`, but only after additional read-only bridge calls.

Before the failing probe, with one-cell closeout disabled, the relevant additional calls are:

- `e1_diagnostics()`;
- `state()`.

MODFLOW has not yet been initialized at that point.

## Question

Does either nominally read-only bridge query alter or expose process state in a way that changes the first exact corrector trial?

## Fixed-build matrix

Compile one exact bridge once.

Run four process variants, 40 fresh processes each:

- N: initialize -> trial;
- E: initialize -> e1_diagnostics -> trial;
- S: initialize -> state -> trial;
- ES: initialize -> e1_diagnostics -> state -> trial.

No MODFLOW initialization or solve is allowed.

No A1 or A2C.

## Measurements

For each process record:

- HCOF, RHS, href;
- pretrial E1 values when requested;
- pretrial state tuple when requested;
- trial status and q;
- backend solver diagnostics after the trial.

## Decision

If one read pattern alone reproduces status 6, localize D3 to that query and its state dependencies.

If all four patterns are 40/40 PASS, the missing trigger lies elsewhere between the simplified probe and the inherited full test and D3 must restore the remaining Python/module import/runtime context one component at a time.
