# F-PE-DIR01 Repair03 result

Date: 2026-09-26

Status: `QUALIFIED_KEEP`

Repair:
reusable worker-local incoming directional request workspace.

Production changes:
- `build_trajectory_step_request` accepts a reusable request object and explicitly resets request metadata;
- incoming pressure-head and water-content direction vectors are reallocated only when shape changes;
- optional source/sink direction arrays are explicitly cleared to preserve absence semantics;
- `fmr_serialized_reference_model_t` owns one reusable request workspace;
- `fmr_serialized_advance` consumes that worker-local workspace instead of a fresh local request object.

Transaction-core semantics are unchanged.

## Experimental qualification

The true reuse experiment first established the intended mechanism:

- 6 malloc fewer per application interval;
- 6 free fewer per application interval;
- 192 fewer allocated bytes per interval;
- identical physical checksum;
- identical accepted bottom-exchange derivative;
- identical accepted-step count;
- identical accepted backsolve count;
- unchanged nonlinear and constitutive solve diagnostics.

The first paired experiment gave:
- mean ratio: approximately `0.97935`;
- median ratio: approximately `0.97818`;
- mean speedup: approximately `2.07%`;
- median speedup: approximately `2.18%`.

## Production-postimage qualification

The production source was then compared directly against the pre-Repair03 postimage at:

`807c19f543acc1eb24de8ac17015ba76497a5ee5`

A direct production comparison gave:
- mean ratio: `0.975279402`;
- median ratio: `0.976000201`;
- mean speedup: `2.472060%`;
- median speedup: `2.399980%`.

A second independent production run gave:
- mean ratio: `0.981520785`;
- median ratio: `0.985256489`;
- mean speedup: `1.847921%`;
- median speedup: `1.474351%`.

Three additional independent production replicas gave job-median ratios:
- `0.988308851`;
- `0.975796548`;
- `0.979822275`.

Equivalent median speedups:
- approximately `1.17%`;
- approximately `2.42%`;
- approximately `2.02%`.

All three job medians are speed-positive. One individual pair in one replica was a small timing outlier above 1.0, while the job aggregate remained positive.

A reasonable planning interpretation is therefore:
- stable exact gain of roughly `1-2.5%` on the directional interval;
- central replicated gain around `2%`.

## Production heap effect

Direct pre/post production heap comparison confirms:

- malloc delta: `-6` per interval;
- free delta: `-6` per interval;
- malloc-byte delta: `-192 bytes` per interval;
- no new calloc or realloc traffic.

This exactly matches the preregistered request-vector allocation target.

## Preservation

Across the paired qualification:
- physical checksum is identical;
- accepted bottom-exchange derivative is identical;
- accepted-step count is identical;
- accepted backsolve count is identical;
- nonlinear iteration count is unchanged;
- constitutive evaluation count is unchanged.

The repair changes numerical scratch ownership only. It does not alter:
- physical state;
- transaction state;
- mass accounting;
- accepted trajectory semantics;
- derivative equations;
- number of nonlinear solves.

## Decision

Repair03 is retained.

It is a small but reproducible exact-P0 optimization with a directly observed removal of repeated heap work.

DIR01 should now rebaseline the remaining bottom-head directional overhead on the Repair01 + Repair03 postimage before choosing any further target.
