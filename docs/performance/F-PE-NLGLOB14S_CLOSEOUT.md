# F-PE-NLGLOB14S closeout — moving-interface split temporal ownership feasibility

Date: 2026-09-29

Final status:

`NLGLOB14S_SPLIT_OWNERSHIP_MECHANICALLY_FEASIBLE`

Qualification authority:

- run `36595791223`;
- job `109500276921`;
- conclusion: SUCCESS.

## Closure

NLGLOB14S closes the first split-domain ownership feasibility test positively.

All 12 qualified first-retreat states admit the same spatial ownership split:

- nodes 1:3 unsaturated and TG-compatible;
- nodes 4:16 persistently saturated;
- one shared 3/4 interface flux.

The split reconstruction is conservative:

- max absolute interface cancellation = 0;
- max split/full storage-rate mismatch about `3.55e-15 cm/d`;
- no state or control-mass inconsistency.

The upper TG predictor remains admissible in all fixtures.

## Scientific conclusion

The whole-column TG release route was falsified by NLGLOB14R4, but the first-retreat state does support a conservative split temporal-ownership representation.

At this instant, the lower saturated block has near-zero storage tendency and the interface exchange is very small, while the upper unsaturated domain carries essentially all net drying.

This provides a mechanically consistent starting point for a moving-interface formulation.

It does not yet qualify a finite-interval split solve.

## Direct successor

Open a separately preregistered transactional split-domain shadow-interval study.

That successor must:

1. keep the interface flux single-valued;
2. evolve upper TG and lower saturated ownership without independent interface-flux fitting;
3. recombine one shadow endpoint;
4. prove total mass and rollback;
5. compare against the persistent-KLAG control;
6. remain research-only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14S

BRANCH: `research/f-pe-nlglob14s-split-ownership-feasibility`

STATUS: closed positive mechanical feasibility

TEST STATUS: 12-case split decomposition PASS

QUALIFICATION STATUS: `NLGLOB14S_SPLIT_OWNERSHIP_MECHANICALLY_FEASIBLE`

NEXT SAFE STEP: preregister one transactional split-domain shadow interval.

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
