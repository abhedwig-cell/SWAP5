# F-PE-NLGLOB14Z12 result — control exposure beyond 11:16

Date: 2026-09-30

Status:

`BLOCKED_NLGLOB14Z12_CONTROL_EXPOSURE`

with preserved accepted event evidence in 3/4 fixtures.

Qualification authority:

- workflow run: `36674896760`;
- job: `109757622503`;
- conclusion: SUCCESS;
- scientific aggregate: blocked by endpoint-solve failure before event exposure in fine RUNOFF.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Does the unchanged persistent-KLAG control expose exact accepted retreat:

`11:16 -> 12:16`

within the staged 120 -> 240 d horizon?

## Event exposure

Three fixtures accept the exact event:

HEAD:

- dt 1.25e-4 d: 123.58775 d;
- dt 6.25e-5 d: 123.587875 d.

RUNOFF:

- dt 1.25e-4 d: 123.58450 d.

All three accepted event trajectories remain:

- finite;
- contiguous;
- non-reversing;
- non-skipping;
- h/theta indicator consistent;
- mass-clean.

## Blocking fixture

Fine RUNOFF, dt = 6.25e-5 d:

- does not expose `11:16 -> 12:16`;
- last accepted saturated set remains `11:16`;
- terminates with `ENDPOINT_SOLVE_FAILURE`;
- remains finite and mass-clean up to the accepted origin;
- therefore fails before event exposure.

Because the preregistered event qualification requires all four controls, Z12 remains blocked.

## Additional post-event completions

The longer 240 d stage also reveals later endpoint-solve failure in:

- fine HEAD after accepting the event;
- coarse RUNOFF after accepting the event.

Coarse HEAD completes 240 d.

These later failures do not invalidate already accepted event evidence, but they reinforce that long dry-horizon fixed-dt solver robustness is now a numerical research boundary.

## Physical mass

Observed maxima:

- interval physical mass ledger: about `2.36e-14 cm`;
- cumulative accepted ledger: about `4.09e-12 cm`.

No mass correction or redistribution occurs.

## Scientific interpretation

The physical retreat `11:16 -> 12:16` is strongly exposed in three independent trajectories near 123.585 d.

However, unlike Z9, the fine RUNOFF numerical failure occurs before this event. Therefore there is not yet four-fixture physical authority for downstream split ownership.

The immediate research question is narrow:

can the fine-RUNOFF pre-event retry/failure be crossed transaction-safely without changing forcing, solver tolerances or accepted-state physics?

## Direct successor

Open a separately preregistered local attribution/recovery workunit for fine RUNOFF around its first endpoint-solve failure before the expected event window.

Require:

- exact accepted origin;
- exact rollback;
- solver retry-advised / hard-failure attribution;
- unchanged forcing;
- unchanged nominal dt;
- bounded transaction subdivision only if retry is advised;
- no tolerance tuning;
- continuation only far enough to determine whether accepted `11:16 -> 12:16` can be reached.

Do not authorize split ownership from Z12 itself.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
