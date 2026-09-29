# F-PE-NLGLOB10 closeout — post-replay residual-failure decomposition

Date: 2026-09-29

Final status:

- Arm A: `NLGLOB10_POST_REPLAY_ENDPOINT_REMAINS_ABOVE_FLOOR`
- Arm B: `NLGLOB10_TG_FORWARD_PREDICTOR_DOMAIN_OVERSHOOT`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@3fe1e5e6f908f819509f8c1b5ab7438b40267a37`

Qualification authority:

- run `36550225479`;
- job `109346307296`;
- SUCCESS.

## Closure

NLGLOB10 closes the post-NLGLOB09 decomposition with two separate residual blockers.

### Arm A

All 14 remaining endpoint failures are still above the balance/storage-floor guard at terminal exhaustion.

They are not S0 misses and must not be accepted by relaxing S0.

### Arm B

All 7 TG predictor-domain exits start from valid finite accepted states inside the retention domain.

The auxiliary first-order moisture predictor alone leaves the domain.

Maximum normalized overshoot is about `5.17e-4` of the full theta range.

The accepted physical state is therefore not the problem.

## Direct successors

Open two separate bounded workunits.

1. `F-PE-NLGLOB11 — TG coefficient-stage predictor admissibility`.
   - Preserve the accepted moisture state and mass contract.
   - No silent theta clipping.
   - Candidate must remain current-step/provider-consistent.
   - Requalify second-order behavior, not just robustness.

2. `F-PE-NLGLOB12 — above-floor endpoint robustness attribution`.
   - Keep S0 unchanged.
   - Determine why these 14 solves remain above the floor.
   - No tolerance relaxation or MAXIT increase as a default rescue.

The two lines may be reunited only after each mechanism is separately understood.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB10

BASELINE: `3fe1e5e6f908f819509f8c1b5ab7438b40267a37`

BRANCH: `research/f-pe-nlglob10-residual-decomposition`

STATUS: closed decomposition

IMPLEMENTATION STATUS: observational diagnostics persisted

TEST STATUS: focused run PASS

QUALIFICATION STATUS: two bounded mechanism classifications above

DEPENDENCIES / BLOCKERS: 7 TG predictor overshoots and 14 above-floor endpoint failures remain separate blockers

NEXT SAFE STEP: preregister NLGLOB11 and NLGLOB12 separately

RECOVERY POINT: this closeout plus NLGLOB10 result/run authority

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
