# F-PE-NLGLOB13A closeout — halfstep failure attribution

Date: 2026-09-29

Final status:

`NLGLOB13A_MIXED_HALFSTEP_FAILURE`

Qualification authority:

- run `36555124716`;
- job `109362393556`;
- SUCCESS.

## Closure

The seven NLGLOB13 near-saturation subdivision failures are fully attributed.

- 5 fail accepted-state retention admissibility in halfstep 1.
- 2 fail accepted-state retention admissibility in halfstep 2.
- 0 fail by endpoint nonconvergence.
- 0 fail by route, ponding or nonfinite-state defects.

The failure mechanism is therefore purely temporal-admissibility within this bank.

## Direct successor

Open:

`F-PE-NLGLOB13B — bounded second-level failing-half subdivision`.

The candidate must be preregistered before results and may add only one additional subdivision level to the failed half-interval.

Maximum depth:

- nominal `h`;
- first subdivision `h/2`;
- one failing `h/2` may be replaced by two `h/4` intervals;
- no `h/8` or adaptive recursion.

Each accepted subinterval must preserve the unchanged physical mass and constitutive-state contracts.

Smooth second-order authority must remain unchanged when subdivision is inactive.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB13A

BASELINE: `15cd2388028d0eae2bec8ab5ab96db6aacf10497`

BRANCH: `research/f-pe-nlglob13a-halfstep-attribution`

STATUS: closed mixed attribution

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `NLGLOB13A_MIXED_HALFSTEP_FAILURE`

NEXT SAFE STEP: preregister NLGLOB13B bounded second-level subdivision

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
