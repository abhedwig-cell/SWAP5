# F-PE-PHYS01 result — physical backend trial decomposition

Date: 2026-09-28

Status: `CLOSED_WITH_MATERIAL_SUCCESSORS`

PR:
`#692 — F-PE-PHYS01: qualification evidence`

Workflow run:
`36354998213`

Measured head:
`84e64aa1ce76abaa20d3c2eafae959573ad3abce`

## Frozen workload

- N = 1,000 / 10,000 / 40,000
- worker=4 primary
- worker=1 secondary discriminator
- 5 measured repetitions after warm-up
- production-shaped MULTI04 fixture
- exact q/tangent checksums preserved

## Results

### N=1,000

worker=4:
- backend max-thread time: 0.036667770 s
- soil-water solver: 56.28%
- temporal-history service: 23.83%
- backend residual outside `advance`: 13.62%
- remaining `advance` residual: 6.27%

worker=1:
- solver: 58.17%
- temporal-history service: 23.96%
- backend residual: 12.82%
- advance residual: 5.05%

### N=10,000

worker=4:
- backend max-thread time: 0.385371007 s
- soil-water solver: 55.43%
- temporal-history service: 23.71%
- backend residual outside `advance`: 14.45%
- remaining `advance` residual: 6.41%

worker=1:
- solver: 57.94%
- temporal-history service: 24.05%
- backend residual: 12.73%
- advance residual: 5.28%

### N=40,000

worker=4:
- backend max-thread time: 1.548780532 s
- soil-water solver: 55.52%
- temporal-history service: 23.45%
- backend residual outside `advance`: 15.00%
- remaining `advance` residual: 6.03%

worker=1:
- solver: 58.10%
- temporal-history service: 23.55%
- backend residual: 13.12%
- advance residual: 5.23%

## Interpretation

PHYS01 falsifies the simpler hypothesis that essentially all remaining backend wall time is inside the main Richards solve.

Three stable families are visible across N:

1. the primary soil-water solver, about 55-58%;
2. the temporal-history certificate service, about 23-24%;
3. transaction/checkpoint/state-cloning and other backend work outside `advance`, about 13-15%.

The temporal-history service is therefore the largest non-solver candidate and clearly clears the preregistered 10-15% advancement gate.

Inspection of the temporal service shows that, after the main solve, it:
- snapshots the previous right derivative;
- constructs the current derivative;
- reevaluates constitutive properties at both base and candidate heads;
- assembles a tridiagonal defect operator;
- performs one additional tridiagonal solve;
- updates temporal history and certificate metadata.

The backend residual also clears the gate, but it is smaller and semantically broader. It should be investigated after the temporal family unless temporal decomposition closes without a viable repair.

## Decision

Close PHYS01 as a decomposition workunit with two material successor families.

Primary successor:
`F-PE-TEMPORAL09` — decompose the production temporal-history certificate cost before changing semantics or implementation.

Secondary successor:
transaction/checkpoint/state-cloning decomposition of the approximately 13-15% backend residual.

No production source change is authorized by PHYS01 itself.
