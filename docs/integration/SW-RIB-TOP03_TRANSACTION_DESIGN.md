# SW-RIB-TOP03 — transactional top-exchange publication design

Date: 2026-10-01

Status: PREREGISTERED_DESIGN_ONLY

Dependency:
SW-RIB-TOP02 executable qualification must pass before implementation.

## Purpose

Publish the TOP01/TOP02 signed top-surface exchange with the same accepted-origin
discipline already admitted for F-APP09, without combining it with the
subsurface drainage exchange.

## Reuse

The admitted `fmr_surface_water_swap_participant_t` establishes the required
transaction pattern:

- capture committed origin lineage/revision/time;
- run trial from that exact origin;
- retain a live candidate without commit;
- compare candidate versus realized external transfer;
- on mismatch discard/recompose from the same accepted origin;
- commit only when publication is ready;
- clear origin/candidate after exactly one commit.

TOP03 should reuse this pattern rather than invent a second coupling protocol.

## Distinct transfer identities

A coupled trial may expose two independent signed transfers:

1. `SUBSURFACE_DRAINAGE_EXCHANGE` from F-APP09;
2. `TOP_SURFACE_EXCHANGE` from TOP03.

They may have opposite signs in the same interval.

Publication readiness is component-wise. A scalar sum is insufficient because
a matching total could hide compensating mismatches.

## Top candidate

From the completed TOP02 soil trial:

- explicit runoff amount `O >= 0`;
- residual external supply `X` from the surface control volume;
- signed legacy-compatible top exchange `T = O-X`.

TOP03 interface sign:

- `T > 0`: SWAP -> Ribasim;
- `T < 0`: Ribasim -> SWAP.

The existing B1.10 mass family maps the same sign to runoff/inundation.

## Recomposition

If Ribasim cannot realize the requested negative `T` because external water
availability is lower than requested, the soil candidate must not be committed.

The participant discards the candidate and recomposes from the same accepted
SWAP/Ribasim origins with the realized hydraulic constraint. No post-hoc mass
clipping is permitted.

Positive runoff realization may likewise require receipt confirmation where
the coupled application treats Ribasim acceptance as authoritative.

## Exactly-once rule

The top transfer is booked:

- once in the accepted SWAP transaction mass;
- once with opposite sign in the Ribasim/coupler ledger.

Rejected trials book neither.

## Fail-closed first profile

TOP03 implementation must reject:

- TOP02 provider not executable-qualified;
- missing top-transfer decomposition diagnostics;
- multistep outer window if decomposition cannot be attributed per accepted
  substep;
- snow/macropore top composition in the first profile;
- stale origin;
- component-wise transfer mismatch;
- nonfinite transfer or tolerance.

## Admission sequence

1. TOP02 provider executable qualification.
2. Pure TOP01 materializer executable qualification.
3. Add top candidate observation/materialization to serialized runtime.
4. Extend/create participant with separate top transfer identity.
5. Test reject/replay/commit and component-wise mismatch.
6. Live Ribasim receipt test.
7. Independent qualification.
8. Canonical admission only after all prior gates pass.

No TOP03 production code is authorized by this design record alone.
