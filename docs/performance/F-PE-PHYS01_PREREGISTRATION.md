# F-PE-PHYS01 preregistration — physical backend trial decomposition

Date: 2026-09-28

Status: `PREREGISTERED_OBSERVATION_ONLY`

## Purpose

ORCH01 showed that approximately 98-99% of production-shaped groundwater trial wall time is inside `backend%run_trial`.
PHYS01 decomposes that physical backend time before any new optimization is selected.

## Frozen workload

- N = 1,000 / 10,000 / 40,000
- worker=4 primary
- worker=1 secondary discriminator
- 5 measured repetitions after one warm-up
- admitted MULTI04 production-shaped groundwater fixture
- exact q/tangent checksums must remain unchanged

## Inclusive timing families

Temporary benchmark-only instrumentation records, per OpenMP worker thread:

1. total `fmr_serialized_backend_run_trial` time;
2. total `fmr_serialized_advance` time;
3. soil-water solver call time inside `fmr_serialized_advance`;
4. temporal-history / model-certificate service time;
5. derived backend residual outside `fmr_serialized_advance`, including checkpoint/kernel/transaction orchestration and state cloning;
6. derived `advance` residual outside the solver and temporal service, including request construction, state copying, process bindings, mass bookkeeping and publication work.

The primary metric is max-thread accumulated time because worker=4 wall time is governed by the slowest worker.

## Candidate-selection gate

No production repair is authorized by PHYS01 preregistration.

Advance one family only if it:
- owns approximately >=10-15% of physical backend critical-path time at N=40,000; or
- shows material superlinear growth with N.

If the soil-water solver itself owns the overwhelming majority, PHYS01 closes the wrapper/transaction frontier and the next workunit must profile inside the selected Richards solver rather than optimize outer runtime machinery.

## Production boundary

Observation-only.
No production `src/**` source change.
Instrumentation is generated only in temporary benchmark source copies.

## Governance

RECONCILE → QUALIFY → REPAIR → ADMIT → CLOSE.
