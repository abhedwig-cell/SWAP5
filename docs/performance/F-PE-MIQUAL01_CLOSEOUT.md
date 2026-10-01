# F-PE-MIQUAL01 closeout — broad post-admission moving-interface qualification

Date: 2026-10-01

Final status:

`MIQUAL01_REFERENCE_DOMAIN_LIMITATION`

Qualification authority:

- workflow run `36819243347`;
- job `110231006391`;
- workflow conclusion SUCCESS.

Canonical authority:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

## Closure

MIQUAL01 is closed as a qualified negative qualification-design result.

The frozen expanded bank contains 8 trajectories. Five complete on the full reference route. Three fail on the full Heritage reference before adaptive-manager evaluation:

- B01_N32_T25;
- O14_N32_T25;
- O14_N64_T49.

The failures are retry/iteration-ceiling reference-solvability failures with clean mass ledgers. They are not manager failures.

Because the preregistration prohibited dropping or replacing exposed cases, no reduced 5-case success claim is manufactured.

## Architectural conclusion

The Z43F canonical manager admission remains intact.

MIQUAL01 demonstrates that the next broad qualification harness must be shaped like production temporal execution rather than a rigid fixed-dt no-retry comparison.

The correct next layer is therefore:

- same physical cases;
- production-valid accepted-state retry/subdivision semantics;
- LEGACY and manager under the same temporal policy;
- hard mass unchanged;
- explicit manager fallback;
- wall-clock and deterministic-work measurement at accepted-trajectory level.

This is more representative of the intended SWAP Heritage adaptive timestep manager than raising MAXIT merely to make a synthetic fixed-step bank finish.

## Recovery point

WORK UNIT: F-PE-MIQUAL01

BRANCH: `research/f-pe-miqual01`

PREREGISTRATION: `docs/performance/F-PE-MIQUAL01_PREREGISTRATION.md`

RESULT: `docs/performance/F-PE-MIQUAL01_RESULT.md`

QUALIFICATION STATUS: `MIQUAL01_REFERENCE_DOMAIN_LIMITATION`

NEXT SAFE STEP: open a separately preregistered production-temporal broad qualification successor retaining all four hydraulic archetypes and using accepted-state retry/subdivision semantics.

## Production boundary

No canonical change requested by MIQUAL01.

`LEGACY_NUMERICS` remains production default.
