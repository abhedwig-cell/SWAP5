# F-PE-SOLVE01 P2B preregistration — live difficult-regime corrector demand

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH`

Parent:
`F-PE-SOLVE01 P2A`

## Trigger

P2A established that E4 retains approximately 62% SWAP-side wall-clock gain through N=1,000 real participants.

P1 established live MODFLOW6 robustness, but the single F-GC44 live case converged in only two exact iterations. In that short-loop regime E4 was approximately 25% slower because validation/recovery overhead could not be amortized.

Before building a large heterogeneous live scale benchmark, SOLVE01 must determine whether difficult physically relevant coupled regimes actually generate enough discarded corrector work for solve elimination to matter.

## Primary question

Across the frozen difficult PROFILE06 regime set, how many live MODFLOW-generated corrector requests are required under E0, and in which regimes does E4 reduce exact SWAP trial work without unacceptable iteration amplification?

This is a demand-characterization gate for the solve-elimination mechanism.

## Frozen regime matrix

Use the six difficult material/regime origins already used by SOLVE01:

- B01 wet, h0 = -10 cm;
- B01 mid, h0 = -75 cm;
- B12 wet, h0 = -10 cm;
- O05 wet, h0 = -10 cm;
- O14 wet, h0 = -10 cm;
- O14 mid, h0 = -75 cm.

For each origin use both dynamic-history directions:

- -10%;
- +10%.

Total:

`12 live coupled regime groups`.

## Live authority

Use:

- MODFLOW6 6.8.0;
- prepared-solve coupling;
- real FMR SWAP participant;
- same exact final validation safeguard as P1;
- BALTOL02 balance-floor replay in the research harness;
- frozen conservative c=0.50 temporal policy as the nonzero-corrector research enabler.

No production source change.

## Arms

### E0

Every MODFLOW-generated corrector head receives an exact SWAP trial.

### E4

Use the current exact aggregate/local anchor for up to three intermediate discarded responses.

Any apparent coupled convergence reached from an approximate response must be validated by a real SWAP trial before publication.

A failed validation becomes a fresh exact anchor and the coupled corrector continues.

## Measurements

Per regime group and policy:

- MODFLOW corrector iterations;
- exact SWAP trials;
- approximate responses;
- exact validation attempts;
- validation failures;
- coupled-loop wall-clock;
- final head;
- final q;
- final residual;
- publication/ledger identity.

## Demand classification

For E0 classify each group by live exact-trial demand:

- SHORT: 1-2 exact trials;
- MODERATE: 3-4 exact trials;
- REUSE-RICH: >=5 exact trials.

This classification is descriptive only.

## Advancement logic

The solve-elimination route remains application-relevant only if difficult live regimes show enough corrector demand for saved Richards solves to offset validation/recovery overhead.

Advance to final heterogeneous live scale if either:

1. at least 25% of the 12 groups are REUSE-RICH under E0; or
2. E4 shows a positive aggregate wall-clock gain across the full 12-group live matrix while preserving exact endpoint authority.

If neither condition holds, do not manufacture a larger favorable workload. Close SOLVE01 with the conclusion that discarded-trial solve elimination has a large conditional SWAP-side gain but insufficient live corrector demand in the tested coupled regimes.

## Hard correctness gates

For every E4 group:

- exact final physical residual;
- same accepted endpoint as E0 within existing F-GC44 authority;
- no approximate state commit;
- one SWAP commit;
- one ledger commit;
- no accepted-XOLD drift.

## Interpretation

P2B is intentionally placed before final scale admission.

P2A answers whether the mechanism scales with N.

P2B answers whether live coupled problems actually ask for enough repeated responses.

Only if both are favorable is a large heterogeneous live benchmark justified.
