# F-PE-APPROX01 A1 result — bounded same-origin tangent cache

Date: 2026-09-26

Status: `QUALIFIED_LOCAL_AND_PARTICIPANT_PENDING_COUPLED_E2E`

PR:
`#629 — F-PE-APPROX01: practical MultiSWAP tangent cadence`

Branch:
`work/f-pe-approx01-tangent-cadence`

Parent exact authority:
`F-PE-DIR01@584af6ce2e6e4a6cd2c790e6341805e56085127b`

## Candidate

A1 is an opt-in cache for the production bottom-head coupling response tangent.

Policy:

- default OFF;
- exact physical SWAP solve on every trial;
- fresh tangent on the first trial from an origin;
- reuse only while:
  - same captured lineage/revision;
  - same coupling window;
  - prescribed bottom head remains within 0.5 cm of the refresh head;
  - cache age remains within the bounded age-8 policy;
  - cached tangent is finite and valid;
- invalidate on new origin, abandon, commit and failed/exchange-invalid trial paths.

Only the response derivative is approximated.

## Local tangent frontier

Across the production material/regime matrix:

- B01, B12, O05, O14;
- wet, mid, dry;

the controlling case is O05-wet.

For fixed cadence over a ±0.5 cm corrector sweep:

- lag-2 worst relative tangent error: about 0.8%;
- lag-4/8 worst relative tangent error: about 1.6%.

The corresponding worst local flux prediction error remains below about 0.8% of the actual flux excursion for lag-4/8.

Larger corrector ranges show why cadence alone is insufficient:

- ±1 cm: lag-4 worst tangent error about 3.2%;
- ±2 cm: lag-4 worst tangent error about 6.6%.

## Adaptive frontier

The head-delta + max-age rule bounds the error much better.

For head threshold 0.5 cm and max age 8:

- ±0.5 cm pattern: about 83% of tangent evaluations avoided;
- ±1 cm pattern: about 67% avoided;
- ±2 cm pattern: about 33% avoided;
- current worst relative tangent error remains approximately 1.65% or lower over the 4x3 matrix.

A 0.25 cm threshold is more conservative but refreshes substantially more often.

The selected research envelope is therefore:

- head threshold: 0.5 cm;
- max age: 8.

## Exact-solve cadence timing

Benchmarks in which every evaluation retains the exact Richards solve and only tangent construction is skipped show large gains.

Representative median speedups:

- lag-2: about 18-22%;
- lag-4: about 28-34%;
- lag-8: about 32-40%.

Physical solve checksums remain identical.

## Production participant qualification

A1 was implemented in the real FMR groundwater participant with explicit provenance fields on the published trial response.

Three independent 20,000-trial same-origin production benchmarks on the final qualification head gave:

- replica 1: `21.5643%` speedup;
- replica 2: `21.2349%` speedup;
- replica 3: `20.9586%` speedup.

All replicas had exactly:

- fresh tangent count: `2223`;
- reused tangent count: `17777`.

Physical exchange sums were identical between cached and fresh modes.

The fresh/reuse lifecycle and new-origin invalidation checks pass.

## Default exact preservation

Two independent default-off gates pass:

1. the existing FGC44 production FMR participant gate;
2. direct parent-vs-current stable-output identity against the DIR01 parent postimage.

Therefore enabling A1 infrastructure does not change the default exact coupling route.

## Provenance

A published response explicitly distinguishes:

- fresh accepted-trajectory tangent;
- same-origin cached tangent;
- reuse age;
- refresh head.

A reused tangent is not represented as a newly computed exact accepted-trajectory derivative.

## Current decision

A1 is retained as the leading practical-performance candidate.

It is not yet fully admitted as the production approximate mode.

The remaining mandatory gate from the preregistration is:

**coupled end-to-end MODFLOW response qualification.**

That gate must quantify:

- coupled MODFLOW head difference;
- cumulative groundwater exchange difference;
- convergence / iteration behavior;
- physical SWAP state and mass preservation;
- end-to-end runtime benefit;

against fresh-tangent authority.

No additional local tangent microbenchmark is needed before that gate.
