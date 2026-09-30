# F-PE-NLGLOB14Z18 result — post-event UPPER boundary attribution

Date: 2026-09-30

Status:

`QUALIFIED_Z18_POST_EVENT_UPPER_OWNERSHIP_BOUNDARY_ATTRIBUTION`

Qualification authority:

- workflow run: `36697938929`;
- segment B HEAD job: `109835480588`;
- segment B RUNOFF job: `109835480609`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Frozen question

What exactly causes the immediate post-event fine-dt split `UPPER` rejection after the already-qualified accepted transition:

`12:16 -> 13:16`

with ownership:

`face 11/12 -> face 12/13`?

## Coverage

PASS.

Both frozen fine split fixtures reproduce the accepted event endpoint and then execute exactly one diagnostic nominal split interval from accepted tail `13:16`.

Both classify:

`QUALIFIED_Z18_POST_EVENT_UPPER_OWNERSHIP_BOUNDARY_ATTRIBUTION`.

## HEAD fine

Accepted event endpoint:

- event time: `260.9335 d`;
- origin saturated tail: `13:16`.

One post-event candidate:

- converged: yes;
- nonlinear iterations: 2;
- finite: yes;
- physical mass ledger: about `5.99e-16 cm`;
- max residual: about `1.63e-15`;
- rollback authority: exact;
- top route at both ends: `surface-flux`;
- candidate paired saturated tail: `12:16`;
- candidate geometry: contiguous.

The only upper-domain violation is node 12:

- `h = +1.3764e-5 cm`;
- `theta = theta_s = 0.336701`;
- paired saturation: true.

Thus node 12, which belongs to the current upper domain under ownership `12/13`, becomes physically saturated in the candidate.

## RUNOFF fine

Accepted event endpoint:

- event time: `260.9303125 d`;
- origin saturated tail: `13:16`.

One post-event candidate:

- converged: yes;
- nonlinear iterations: 2;
- finite: yes;
- physical mass ledger: about `1.03e-15 cm`;
- max residual: about `5.48e-16`;
- rollback authority: exact;
- top route at both ends: `surface-flux`;
- candidate paired saturated tail: `12:16`;
- candidate geometry: contiguous.

The only upper-domain violation is again node 12:

- `h = +1.4588e-5 cm`;
- `theta = theta_s = 0.336701`;
- paired saturation: true.

## Attribution

The immediate post-event `UPPER` rejection is not caused by:

- nonlinear convergence failure;
- nonfinite state;
- mass failure;
- rollback leakage;
- dynamic-top provider failure;
- noncontiguous geometry;
- h/theta inconsistency.

It is caused only by the frozen ownership/domain exclusion that requires all current upper-domain nodes to remain strictly unsaturated.

The physical candidate instead indicates an immediate accepted-direction re-expansion candidate:

`13:16 -> 12:16`.

That candidate is deliberately not accepted in Z18.

## Scientific interpretation

The Z15 fine-dt post-event blocker is an ownership/domain-definition boundary.

After the accepted retreat to `13:16`, the very next nominal split candidate wants to saturate node 12 again while remaining otherwise numerically and physically clean.

Therefore the current one-way retreat-only ownership assumption becomes insufficient at this phase.

This does not prove that immediate re-expansion should be committed. It proves that the next research question is explicit bidirectional accepted-state ownership transition semantics, not solver repair or tolerance relaxation.

## Qualified claim boundary

Qualified:

`QUALIFIED_Z18_POST_EVENT_UPPER_OWNERSHIP_BOUNDARY_ATTRIBUTION`.

Not qualified:

- accepting the reverse candidate;
- bidirectional interface ownership;
- persistence/chatter behavior under reverse ownership;
- later retreat `13:16 -> 14:16` in split mode;
- disappearance;
- whole-column TG re-entry;
- production temporal ownership.

## Consequence

A separately preregistered successor may test transaction-safe bidirectional ownership reclassification for exactly this immediate post-event candidate.

The successor must:

1. preserve accepted `13:16` event state as origin authority;
2. solve the next candidate unchanged;
3. if the candidate is exact contiguous `12:16`, reclassify ownership from `12/13` back to `11/12` only as an explicit accepted-state event;
4. require mass, residual, rollback and provider gates;
5. characterize whether subsequent intervals chatter or settle;
6. use no fitted threshold or hysteresis unless separately preregistered.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
