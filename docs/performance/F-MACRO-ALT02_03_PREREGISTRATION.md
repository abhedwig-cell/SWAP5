# F-MACRO-ALT02/03 — sorption and wet-wall memory falsification preregistration

Date: 2026-09-30

Status: `PREREGISTERED_RESEARCH_ONLY`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Owning research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Determine whether two legacy macropore history roles are independently necessary for future event-scale response:

- E02: sorption-event memory;
- E03: accepted wet-wall memory.

This is a state-sufficiency study, not a production migration.

## Source-bound motivation

Recovered historical artifacts establish distinct state roles:

### Sorption-event memory

The retained S12o source delta identifies:

- `SorpDmCp`: Philip sorptivity at start of sorption event;
- `ThtSrpRefDmCp`: sorption reference water content;
- `TimAbsCumDmCp`: cumulative duration of a sorption event;
- `FlEndSrpEvt`: end-of-sorptivity-event flag.

These variables are not rate scratch. The S12o qualification classifies the first three as column-owned physical/history state and reports `SorpDmCp` and `ThtSrpRefDmCp` as trial-mutable.

### Wet-wall memory

The retained S12o dependency map states that `FrMpWalWetOld` was already moved to a separate `MacroporeAcceptedHistory` object.

This creates a source-backed distinction between sorption-event memory and accepted wet-wall history.

## Common controlled state

Both E02 and E03 must compare paired second-event trajectories with identical:

```text
matrix state theta/h
fast-domain current water storage
dynamic macropore volume
current connectivity/topology
current forcing and future forcing
solver/numerical settings
all non-target macropore history variables
```

Only the selected target history group may differ.

Any pair violating this equalization is diagnostically invalid.

## E02 — sorption-event memory necessity

### Target variation

Vary only the source-proven sorption-event history group:

```text
SorpDmCp
ThtSrpRefDmCp
TimAbsCumDmCp
FlEndSrpEvt
```

while holding accepted wet-wall history fixed.

### Null hypothesis E02-H0

Given equal current physical state, current geometry, accepted wet-wall history and future forcing, sorption-event history does not alter future macropore response.

### Alternative E02-H1

A source-proven sorption-event history perturbation changes at least one future response observable despite equal current storage, matrix state, geometry and wet-wall history.

### Primary observables

- unsaturated matrix exchange `QOutMtxUnsDmCp` or exact B1.11 equivalent;
- fast-domain storage evolution;
- bottom/deep preferential flux;
- rapid drainage where active;
- wetting-arrival signatures;
- accepted whole-column water balance.

### Decision rule

`SORPTION_MEMORY_IRREDUCIBLE` if a deterministic, reproducible nonzero future-response difference remains after all non-target state has been equalized and the difference traces to the target source variables.

Otherwise E02 does not prove irreducibility.

A failure to detect a difference in one scenario is not sufficient to eliminate the state group; scenario coverage must include at least dry/high-sorptivity and wetter/low-sorptivity regimes.

## E03 — accepted wet-wall memory necessity

### Target variation

Vary only accepted wet-wall history represented historically by `FrMpWalWetOld` / `MacroporeAcceptedHistory`.

All sorption-event state is held identical.

### Null hypothesis E03-H0

Given equal current physical state, sorption history, geometry and future forcing, accepted wet-wall history does not alter future response.

### Alternative E03-H1

Accepted wet-wall history changes at least one future response observable under otherwise equal state.

### Primary observables

- onset and magnitude of matrix/macropore exchange;
- activation/persistence of wall contact;
- fast-domain storage evolution;
- deep/rapid outflow;
- accepted mass balance.

### Decision rule

`WET_WALL_MEMORY_IRREDUCIBLE` if a reproducible future-response difference remains under exact equalization of all non-target state and traces to accepted wet-wall history.

## Cross-test interpretation

The possible outcomes are:

| E02 | E03 | reduced-state implication |
| --- | --- | --- |
| no detectable independent effect | no detectable independent effect | aggressive history compression remains viable |
| independent effect | none | retain/compress sorption memory only |
| none | independent effect | retain/compress wet-wall memory only |
| independent effect | independent effect | at least two information roles must be represented unless later compression proves a sufficient joint statistic |

No row authorizes production removal of legacy state without exact B1.11 source-bound replay.

## Compression test after E02/E03

If both history groups matter, a later E04/E05 study may still test whether one latent/effective state variable can summarize both.

That compression candidate must be trained/calibrated on one event set and predict held-out event sequences. Fitting each event independently is not evidence of state sufficiency.

## Research-only toy-harness role

Standalone reduced-model experiments may be used to verify discrimination power and mass bookkeeping, but they cannot decide E02/E03 for SWAP.

The decisive reference is the exact source-bound SWAP macropore implementation.

## Production authority boundary

PPA-WU05-A1 remains open until byte-exact B1.11 source materialization and the complete mutable-field/mass-transfer census are closed.

This preregistration therefore changes no production state schema, no restart contract and no canonical physics.

## Architecture invariants touched

3, 4, 5, 7, 13, 16, 23, 25, 27.

The intended direction strengthens compact optional state and worker-local scratch while retaining hard mass conservation and transactional rollback.
