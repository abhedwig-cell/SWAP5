# F-PE-ORCH01 result — production groundwater hot-loop orchestration decomposition

Date: 2026-09-28

Status: `CLOSED_ORCHESTRATION_LOW_RETURN`

PR:
`#689 — F-PE-ORCH01: qualification evidence`

Workflow run:
`36354474564`

Measured head:
`c69ab91c7c2bdf60508998d66be22fbcfa4a0fca`

## Frozen workload

- N = 1,000 / 10,000 / 40,000
- worker=4 primary
- worker=1 secondary discriminator
- 5 measured repetitions after warm-up
- production-shaped MULTI04 fixture
- exact q/tangent checksums preserved

## Results

### N=1,000

worker=4:
- total trial wall: 0.028776676 s
- backend max-thread time: 0.028482058 s
- backend share: 98.98%
- explicit orchestration share: 0.23%
- residual inside parallel trial region: 0.63%

worker=1:
- total trial wall: 0.075129738 s
- backend share: 99.00%

### N=10,000

worker=4:
- total trial wall: 0.289397439 s
- backend max-thread time: 0.285867049 s
- backend share: 98.78%
- explicit orchestration share: 0.26%
- residual inside parallel trial region: 0.78%

worker=1:
- total trial wall: 0.764236813 s
- backend share: 99.01%

### N=40,000

worker=4:
- total trial wall: 0.884416536 s
- backend max-thread time: 0.871924496 s
- backend share: 98.59%
- explicit orchestration share: 0.23%
- residual inside parallel trial region: 1.00%

Explicit N=40,000 worker=4 phase times:
- cell-head to tile-head mapping: 0.000107973 s
- cost-proxy plus static owner initialization: 0.000580166 s
- scheduler selection: 0.000000160 s
- post-trial validation: 0.000042013 s
- aggregation: 0.001317574 s

worker=1:
- total trial wall: 2.262489878 s
- backend share: 99.07%
- aggregation: 0.001204178 s

## Interpretation

No measured orchestration family approaches the preregistered 10-15% advancement threshold.

The production-shaped hot loop is overwhelmingly owned by the physical backend solve. The measured orchestration fractions remain small from N=1,000 through N=40,000 and show no material superlinear growth.

The registry linear-scan fallback is not exercised materially by this fresh-sequential production path because dense handles resolve through the existing direct O(1) fast path.

The 4-worker owner-loop structure does perform extra owner checks, but its measured contribution is too small to justify a production repair on current evidence.

## Decision

Do not open a registry direct-index repair, scheduler repair, owner-array repair, trial-valid bookkeeping repair, or aggregation micro-optimization from ORCH01 evidence.

Close this orchestration line as low expected return.

The next meaningful performance frontier remains inside the physical backend solve itself, not application-context orchestration.

No production source change is authorized or required by ORCH01.
