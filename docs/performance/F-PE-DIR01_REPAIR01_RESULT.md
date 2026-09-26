# F-PE-DIR01 Repair01 result

Date: 2026-09-26

Status: `QUALIFIED_KEEP`

Repair:
move-based ownership transfer for accepted-step directional vectors in
`src/transaction/mod_accepted_trajectory_directional_sensitivity.f90`.

Pre-repair authority:
`0fc57e27bb1d1abd8cdd4f516e6066d55e8a44d8`

## Preservation

Paired qualification preserved exactly:
- physical checksum;
- accepted bottom-exchange derivative;
- accepted step count;
- accepted backsolve count;
- nonlinear iteration count;
- constitutive evaluation count.

No additional nonlinear solve was introduced.

## Heap effect

Before Repair01, bottom-head directional minus Reference added per application interval:
- 32 malloc;
- 4 calloc;
- 36 free;
- 2594 malloc bytes;
- 128 calloc bytes.

After Repair01:
- 26 malloc;
- 4 calloc;
- 30 free;
- 2402 malloc bytes;
- 128 calloc bytes.

Repair01 therefore removes:
- 6 malloc per interval;
- 6 free per interval;
- 192 allocated bytes per interval.

The removed allocations are the duplicate pending-trajectory vector allocations that previously followed already-allocated directional result vectors.

## Runtime effect

Ten paired same-run timings against the direct pre-repair source:

- mean candidate/base ratio: `0.990710311`;
- median ratio: `0.991819254`;
- mean speedup: `0.928969%`;
- median speedup: `0.818075%`;
- mean reduction: approximately `108 ns/interval`.

Interpretation:
Repair01 is small but directionally consistent with the measured allocation reduction and preserves semantics exactly. It is retained.

## Remaining hotspot

The post-Repair01 heap map still shows substantial exact overhead.

Largest remaining directional-only allocation groups include:
- `solve_with_accepted_step_direction`: 6 allocations/interval for outgoing vectors;
- `build_trajectory_step_request`: 6 allocations/interval for incoming vectors;
- transaction attempt-context capture/restore: fewer calls but by far the largest byte volume;
- initial trajectory vector ownership and publication.

The next repair must be separately preregistered from this post-Repair01 map.
