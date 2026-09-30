# PPA-WU05-A4 bounded Richards Picard characterization

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_CHARACTERIZATION / FAST_FIXED_POINT_CONVERGENCE_IN_TESTED_CASES`

Workflow run: `36765412541`

Head: `88f322a98ae9e3f2f8a6346a9eb50ba53e8bbb87`

## Purpose

Characterize whether dynamic macropore/matrix exchange requires fully implicit coupling inside the Richards Newton solve, or whether a bounded outer predictor/corrector iteration is sufficient.

Each corrector:

1. starts from the same accepted matrix state;
2. uses the same accepted macropore history for the physical step;
3. recomputes exchange from the previous corrector matrix state;
4. solves Richards with that exchange frozen;
5. checks solver and combined matrix+macropore mass closure.

No convergence tolerance was preregistered; the sequence was observed first.

## Fresh-event sequence

Exchange rate [cm d-1]:

1. 8.3813780726
2. 8.1203910703
3. 8.1287684720
4. 8.1284998205
5. 8.1285084360
6. 8.1285081597

Relative change between successive exchange estimates:

- 1 -> 2: 3.1139e-2 = 3.11%;
- 2 -> 3: 1.0317e-3 = 0.103%;
- 3 -> 4: 3.3049e-5 = 0.00330%;
- 4 -> 5: 1.0599e-6;
- 5 -> 6: 3.3991e-8.

## Aged-event sequence

Exchange rate [cm d-1]:

1. 0.2064276696
2. 0.2063013032
3. 0.2063013806
4. 0.2063013805
5. 0.2063013805
6. 0.2063013805

Relative change:

- 1 -> 2: 6.1216e-4 = 0.0612%;
- 2 -> 3: 3.7524e-7;
- 3 -> 4: 2.2987e-10;
- later changes at numerical roundoff scale.

## Mass and solver behaviour

Every corrector:

- converged in the real Richards solver;
- satisfied the strict typed solver residual check;
- satisfied combined matrix + macropore mass reconciliation;
- preserved fresh-versus-aged event-memory ordering.

O0 and O2 outputs were identical.

## Interpretation

The tested coupling behaves as a strongly convergent outer fixed-point problem.

There is currently no evidence that macropore exchange must be embedded as a fully implicit Newton term.

For the tested fresh-event case:

- predictor + one corrector leaves about 3.1% exchange feedback unresolved;
- two correctors reduce that to roughly 0.10%;
- three correctors reduce the successive exchange change to about 0.0033%;
- four and later are effectively converged for ordinary scientific purposes.

The aged-history case is much weaker and effectively converges after the second corrector.

## Provisional coupling policy

Do not freeze a production policy from one hydraulic regime.

For continued research:

- **strict reference candidate:** bounded outer Picard iteration, with convergence on exchange change;
- **practical candidate:** one or two correctors depending on tolerated approximation;
- **fully implicit Newton coupling:** not justified by current evidence.

A convergence tolerance should be selected only after broader regime characterization.

## Next step

Use local reduced-model sweeps to screen coupling strength over:

- matrix moisture;
- event age;
- step duration;
- sorptivity strength;
- macropore water availability.

Then select a small adversarial subset for real Richards confirmation through the focused CI probe.

This keeps GitHub Actions as qualification evidence rather than the primary experimental engine.
