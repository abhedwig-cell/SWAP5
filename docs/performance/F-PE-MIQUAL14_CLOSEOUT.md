# F-PE-MIQUAL14 closeout — serialized manager break-even scaling

Date: 2026-10-01

Final status:

`QUALIFIED_MIQUAL14_BREAK_EVEN_REACHED`

MIQUAL14 closes the current moving-interface performance investigation.

Production-shaped serialized results:

- N16/T13: median wall ratio 1.0313, no gain;
- N32/T25: median wall ratio 0.9964, approximately break-even;
- N64/T49: median wall ratio 0.9701, reproducible gain.

All geometries preserve exact final physical state, hard mass, transaction semantics, 100% reduced routing and zero fallback/bypass.

## Closure conclusion

The moving-interface manager is not a universal speedup mechanism at small column dimensions.

It becomes performance-positive when the physical column/reconstructible-tail geometry is large enough to amortize fixed solve and runtime overhead.

The N64 result demonstrates that the architecture can deliver real end-to-end runtime gain through the normal serialized transaction route.

Further adapter micro-optimization is not justified as the main research direction.

## Deferred successor options

Only reopen if useful:

- `F-PE-MIQUAL15 — manager activation-envelope qualification`, for a broader dimension/tail-ratio bank and a defensible opt-in performance threshold;
- a separate dynamic serialized-reference workload derivation, needed before any dynamic production-speed claim.

No production admission or default activation is authorized by MIQUAL14 alone.

Production default remains `LEGACY_NUMERICS`.
