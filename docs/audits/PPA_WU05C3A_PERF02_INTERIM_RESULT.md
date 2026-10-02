# PPA-WU05-C3A-PERF02 interim qualification record

Date: 2026-10-02
State: IMPLEMENTED_NOT_YET_PRODUCTION_ADMISSION_CANDIDATE

## Reconciliation

Current canonical checked during this work unit: `cd03d041f967f1bedc8d1a68d0ed17c71988d50d`.
PERF02 remained based on merge-base `a89990169fb8429a0fd143df9e3d28b9a35d28b8`; qualification therefore uses the PR merge postimage against current canonical rather than assuming the research branch alone is current production authority.

The historical 1100-state gate run 37004279085 / job 110828798019 reported:
- GATE_TOTAL=1100
- GATE_NOSTRESS=765
- GATE_BOUND_SKIPS=672
- GATE_BOUND_FALSE_SKIPS=0

That run established the original analytical candidate but its sweep used equal current and z0 root dry mass. Production response assembly uses current `w_root` for MICRO and `w_root_z0` for MACRO. PERF02 therefore corrected the gate contract to take both independently before production integration.

## Analytical envelope

The admitted parameter validation permits `waterfilm_gen_n > 2`. The simple lower bound `I >= (H/2) f(H/2)` is only used for `1 < n <= 2`. The gate explicitly returns to the full Reference route for `n > 2`; no extrapolation is admitted.

## Boundary falsification

Run 37005076175 / job 110831331398, after separating current `w_root` from `w_root_z0`:
- BOUNDARY_TOTAL=15823
- BOUNDARY_SKIPS=4172
- BOUNDARY_FALSE_SKIPS=0
- BOUNDARY_NEAR_GATE=2511
- BOUNDARY_NEAR_REFERENCE=4608
- BOUNDARY_N_GT_2_CASES=233
- BOUNDARY_N_GT_2_SKIPS=0

The deterministic suite varies pressure head, water content/GFP, theta_r, theta_s, MvG alpha and n, temperature, current and z0 root dry mass, root and microbial respiration parameters, atmospheric ctop, root radius, root/microbial shape lengths and compartment depth. It explicitly bisects both the gate decision boundary and the full Reference no-stress transition, then samples densely around each.

## Production integration

The gate is now called only for `BARTHOLOMEUS_WATERFILM_REFERENCE`, before `evaluate_bartholomeus_waterfilm`. A proven skip allocates the existing factor result and returns factor 1. No accepted state, cache, checkpoint/restart field, solver ABI or physical option was added. All uncertain or unsupported states fall through to the PERF01 Reference route.

## Performance

Persisted benchmark run 37005289504 / job 110832018805 measured seven repetitions on the production-integrated postimage.

Median ns/evaluation:
- non-skipped stress regime: gated 47214.25 versus PERF01 comparator 46802.35; gate itself 166.61 ns;
- skipped no-stress regime 2: gated 497.15 versus PERF01 40971.68; gate 453.75 ns;
- skipped no-stress regime 3: gated 498.82 versus PERF01 40933.50; gate 454.41 ns;
- mixed 1:1:1 workload: gated 16092.98 versus PERF01 42800.11.

Thus the measured non-skip overhead is about 0.9%, while eligible no-stress calls are reduced to about 0.5 microseconds in this fixture. The synthetic mixed fixture is about 2.66x faster. These are microbenchmark results, not production skip-frequency or MultiSWAP speed claims.

## Preservation

Run 37005848039 / job 110833811019:
- corrected B1.11 assembled oracle O0/O2: PASS;
- maximum RWU difference: 2.3760167733755111e-5, unchanged and below 1e-4;
- active-chain harness: PASS after adding the new gate module to its explicit compile closure;
- typed production application: BLOCKED by SIGSEGV in `mod_fmr_serialized_reference_backend::fmr_serialized_storage`, reached through the current transaction/runtime stack before a production-preservation conclusion could be established.

The typed-application failure is outside the oxygen source files, but it is not classified away. A current-canonical control was added to the PERF02 qualification workflow. Until that control and a candidate typed-application replay establish the cause, PERF02 is not a production-admission candidate.

## Admission status

NOT YET PRODUCTION-ADMISSION CANDIDATE.

Boundary safety and B1.11 preservation are currently positive, and measured performance is substantial. The unresolved typed production-application preservation gate remains a blocker. No canonical admission is claimed.
