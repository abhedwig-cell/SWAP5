# F-PE-ORCH01 preregistration — production groundwater hot-loop orchestration decomposition

Date: 2026-09-28

Status: `PREREGISTERED_OBSERVATION_ONLY`

## Question

After SETUP04/05, CODEGEN01 and AGG01, determine how much production-shaped groundwater trial wall time is owned by orchestration outside the physical backend solve.

## Frozen workload

- N = 1,000 / 10,000 / 40,000
- worker=4 primary
- worker=1 secondary discriminator
- 5 measured repetitions after one warm-up
- existing admitted MULTI04 production-shaped fixture
- exact q/tangent checksums must remain unchanged

## Inclusive timing families

For worker=4:
1. cell-head to tile-head mapping and range validation;
2. participant pretrial cost-proxy lookup and static owner initialization;
3. load-ratio / optional cost-aware scheduler construction;
4. parallel trial region;
5. post-trial registry/trial-valid validation;
6. cell aggregation;
7. total trial wall time.

Temporary benchmark-only instrumentation also records time spent inside `backend%run_trial`, per OpenMP thread, so the parallel trial region can be decomposed into physical backend work versus wrapper/orchestration residual.

For worker=1:
- total trial wall;
- backend `run_trial` time;
- aggregation time;
- residual wrapper/orchestration time.

## Candidate selection gate

No repair is authorized by preregistration alone.

Advance exactly one orchestration family only if it either:
- owns approximately >=10-15% of production-shaped trial wall at representative large N; or
- grows superlinearly with N and is materially visible at N=40,000.

Do not advance a micro-optimization solely because a local routine is measurable.

## Registry hypothesis

`resolve_handle[_const]` contains a direct O(1) fast path for dense sequential handles and a generic linear fallback. The production-shaped fixture is expected to use the fast path after SETUP04. ORCH01 must measure before any bounded direct-index repair is considered.

## Production boundary

Observation-only. No `src/**` production source change is authorized in ORCH01 qualification.
Temporary instrumented source copies may be generated inside the benchmark build directory only.

## Governance

RECONCILE → QUALIFY → REPAIR → ADMIT → CLOSE.
