# F-PE-ELASTIC59 — refined-oracle solvability attribution preregistration

Date: 2026-09-30

Status: PREREGISTERED_OBSERVATION_ONLY

Parent authority:
`F-PE-ELASTIC58 — QUALIFIED_PHYSICAL_BUDGET_CANDIDATE_WITH_UNSATURATED_ORACLE_COVERAGE_BLOCKER`

Parent postimage:
`research/f-pe-elastic58-independent-head-budget@db27081adc8d28c5c74958ac8f4f346419e73efd`

Canonical authority:
`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

## Question

Why does the fixed N=32 Reference oracle fail for 54 ELASTIC58 accepted points,
all in unsaturated states?

## Frozen accepted-point set

Replay the exact ELASTIC58 controller:
- profiles 11060, 10260, 8016, 3030;
- h0 = -75, -20, +2, +10 cm;
- delta = +/-0.035 and +/-0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- same 15-level C-SAFE ladder;
- frozen Binf threshold `0.05773585599727987 cm`.

Only C-SAFE accepted points enter oracle attribution.

## Oracle substep-count sweep

For every accepted point, run independent fixed-substep Reference oracles at:

- N = 4;
- N = 8;
- N = 16;
- N = 32;
- N = 64.

Same:
- origin;
- forcing;
- mode 7;
- swkimpl=0;
- material/ELAS regime;
- solver/tolerances.

Record:
- whether all N substeps converge;
- first failing substep index;
- failing solver status;
- minimum and maximum substep nonlinear iterations;
- maximum independent mass-ledger residual;
- terminal state checksum for successful oracles.

## Oracle refinement consistency

Whenever two successive oracle levels both complete, compare their terminal
states:

- `H_N = max |h_N - h_2N|`;
- `THETA_N = max |theta_N - theta_2N|`.

This is diagnostic only. No acceptance limit is fitted.

## Hypotheses

H1. ELASTIC58 oracle unavailability is controlled by small-substep solver
solvability rather than ELAS regime.

H2. The first failing substep occurs in similar locations across OFF,
FIXED_1E6 and GENERATED for the same unsaturated profile/state/forcing case.

H3. At least one coarser oracle level among N=4/8/16 provides substantially
better coverage than N=32.

H4. Successful successive oracle levels show decreasing terminal refinement
differences over at least part of the domain.

## Gates

A1. ELASTIC58 C-SAFE accepted-point count reproduces exactly 96.

A2. N=32 completion count reproduces exactly 42 and unavailability exactly 54.

A3. Every N sweep result records a deterministic completion/failure status.

A4. O0/O2 C-SAFE decisions remain identical.

A5. No physical limit, alpha, solver tolerance or controller criterion changes.

A6. Zero production `src/**` changes.

## Decision

ELASTIC59 is attribution-only.

A positive result may select a better refined-oracle construction for renewed
physical-budget qualification. It does not authorize weakening solver criteria
or replacing the Reference oracle with an approximate model.
