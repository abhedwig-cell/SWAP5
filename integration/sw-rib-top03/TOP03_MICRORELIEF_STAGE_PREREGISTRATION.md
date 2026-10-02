# TOP03 microrelief stage-evolution preregistration

Date: 2026-10-02
Status: PREREGISTERED_RESEARCH_ONLY

## Question

The fixed-stage microrelief probe supports partial areal hydraulic contact as a way to regularize the shallow inundation onset. A production surface, however, must eventually move from partial contact to full inundation as external stage rises.

This experiment tests whether the same microrelief law remains numerically coherent through that transition, without changing the soil, lower boundary or Reference Richards law.

## Fixed soil and numerical problem

Keep the same TOP03 fixture:

- initial pressure head -123 cm;
- initial groundwater level -2.25 cm;
- initial local surface storage 0;
- same MOD_grid geometry and B1.10 MVG parameters;
- bottom mode 7 with the same initial conductivity-derived bottom flux;
- Reference Richards;
- max 80 nonlinear iterations and 16 backtracking attempts;
- no root extraction, drainage response, macropore, snow, thermal, rain, irrigation, runon, evaporation or runoff;
- positive accepted qtop remains outside the bounded inundation profile.

## Common external-stage trajectory

Use the same absolute stage trajectory for every surface geometry:

`H = [0.005, 0.020, 0.050, 0.100, 0.200, 0.300] cm`.

Each stage is a piecewise-constant event lasting `0.03125 day`. Refinement must preserve these event boundaries exactly.

This means:

- D=0 is full-area contact at every event;
- D=0.02 is partial only at the first event and full from H=0.02 onward;
- D=0.05 reaches full contact at H=0.05;
- D=0.10 reaches full contact at H=0.10;
- D=0.25 reaches full contact only at the final H=0.30 event.

Test amplitudes `D = 0, 0.02, 0.05, 0.10, 0.25 cm`.

## Temporal refinement

Within every event use independently:

`1, 2, 4, 8` equal substeps.

Each trajectory restarts from the same accepted dry origin. Event boundaries are identical across all refinement levels, so comparisons do not mix temporal error with shifted forcing events.

## Mass ownership

At each event the local SWAP surface storage is the microrelief storage `S_surface(H,D)`. A change in externally imposed stage can therefore change local storage instantaneously at the event boundary; the post-solve top materializer must include that change in the external surface-water transfer.

The represented larger surface-water body remains external. This is research evidence only and does not by itself settle Ribasim geometry ownership.

## Recorded observables

For every trajectory:

- completion or failing event/substep;
- nonlinear iterations;
- cumulative signed external top transfer;
- cumulative bottom transfer;
- total soil+local-surface storage change;
- whole-trajectory ledger residual;
- maximum accepted soil mass residual;
- final pressure/water state and final local surface storage.

For adjacent refinements compare:

- pressure-head infinity difference;
- water-storage L1 and maximum-cell difference;
- local surface-storage difference;
- top-transfer difference;
- bottom-transfer difference.

## Hard gates

Usable trajectories require:

- every solve converged;
- accepted soil mass residual <= 1e-10 cm;
- surface materializer closure <= 1e-12 cm;
- whole-trajectory ledger residual <= 1e-10 cm;
- admitted qtop sign throughout;
- exact O0/O2 numerical output identity.

## Decision rule

The stage-evolution hypothesis is supported when at least one nonzero D:

1. completes the full six-event partial-to-full trajectory through 8 substeps per event;
2. has at least three complete temporal refinement levels;
3. shows simultaneous contraction of state, cumulative top transfer and cumulative bottom transfer across successive adjacent refinement pairs.

The result must separately report the D=0 flat-surface trajectory. If a flat event-aligned ramp also succeeds, that is evidence that event alignment contributes independently and must not be attributed to microrelief.

A positive result remains research-only. It authorizes a surface-geometry and temporal-contract design step, not production admission.
