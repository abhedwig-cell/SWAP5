# PPA-WU05-C3A-PERF02 interim qualification record

Date: 2026-10-02
State: IMPLEMENTED_NOT_YET_PRODUCTION_ADMISSION_CANDIDATE

## Reconciliation

Current canonical checked during the latest qualification: `6f52733173d1909ff1027771f0d737d4face0323`.
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

Latest corrected independent boundary run 37008132584 / job 110841160071, with the oracle explicitly bypassing PERF02 and the deterministic sweep expanded to 4096 parameter cases:
- BOUNDARY_TOTAL=119591
- BOUNDARY_SKIPS=25443
- BOUNDARY_FALSE_SKIPS=0
- BOUNDARY_NEAR_GATE=15507
- BOUNDARY_NEAR_REFERENCE=34452
- BOUNDARY_N_GT_2_CASES=2283
- BOUNDARY_N_GT_2_SKIPS=0

The deterministic suite varies pressure head, water content/GFP, theta_r, theta_s, MvG alpha and n, temperature, current and z0 root dry mass, root and microbial respiration parameters, atmospheric ctop, root radius, root/microbial shape lengths and compartment depth. It explicitly bisects both the gate decision boundary and the full Reference no-stress transition, then samples densely around each.

## Production integration

The gate is now called only for `BARTHOLOMEUS_WATERFILM_REFERENCE`, before `evaluate_bartholomeus_waterfilm`. A proven skip allocates the existing factor result and returns factor 1. No accepted state, cache, checkpoint/restart field, solver ABI or physical option was added. All uncertain or unsupported states fall through to the PERF01 Reference route.

## Performance

Latest persisted benchmark run 37008132642 / job 110841159936 measured seven repetitions on the PR merge postimage.

Median ns/evaluation:
- non-skipped stress regime: gated 75178.68 versus PERF01 comparator 74890.36; gate itself 294.55 ns;
- skipped no-stress regime 2: gated 903.44 versus PERF01 64832.68; gate 811.14 ns;
- skipped no-stress regime 3: gated 901.67 versus PERF01 64801.37; gate 809.67 ns;
- mixed 1:1:1 workload: gated 25677.54 versus PERF01 68152.60.

Thus the latest measured non-skip overhead is about 0.39%, while eligible no-stress calls are reduced to about 0.9 microseconds in this fixture. The synthetic mixed fixture is about 2.65x faster. These are microbenchmark results, not production skip-frequency or MultiSWAP speed claims.

## Preservation

Latest qualification run 37008132642:
- corrected B1.11 assembled oracle O0/O2: PASS;
- maximum RWU difference: 2.3760167733755111e-5, unchanged and below 1e-4;
- active-chain harness: PASS after adding the new gate module to its explicit compile closure;
- typed production application: BLOCKED by SIGSEGV in `mod_fmr_serialized_reference_backend::fmr_serialized_storage`, reached through the current transaction/runtime stack before a production-preservation conclusion could be established.

The candidate typed application failed in job 110841159885 with a SIGSEGV in `mod_fmr_serialized_reference_backend::fmr_serialized_storage`. The explicit current-canonical control, job 110841160176, checked out canonical `6f52733173d1909ff1027771f0d737d4face0323` and failed with the same SIGSEGV at the same storage routine. This establishes that the present typed-application blocker exists on canonical independently of PERF02. It must not be reported as a PERF02 regression. However, because the required typed production-application preservation gate cannot currently complete on either baseline, PERF02 remains blocked from production-admission-candidate status until that upstream canonical defect is repaired or the owning authority supplies an accepted replacement preservation gate.

## Admission status

NOT YET PRODUCTION-ADMISSION CANDIDATE.

Boundary safety and B1.11 preservation are currently positive, and measured performance is substantial. The unresolved typed production-application preservation gate remains a blocker. No canonical admission is claimed.


## Dependency-surface reconciliation against current canonical

A direct compare from the PERF02 merge-base `a89990169fb8429a0fd143df9e3d28b9a35d28b8` to current canonical `6f52733173d1909ff1027771f0d737d4face0323` shows 36 canonical commits but only the F-MIG431-LOW08-A/P0 lower-boundary family on the scientific/runtime source surface: `src/legacy/b1_10_port/headcalc.f90` and `src/adapter/mod_reference_richards_legacy_binding.f90`, plus its tests/evidence and publication documentation. No Bartholomeus oxygen source, parameter contract, waterfilm, factor provider, MICRO/MACRO equation, crop oxygen carrier, or oxygen execution binding changed in that canonical delta.

Therefore the latest PR merge-postimage boundary and B1.11 evidence already exercise PERF02 composed with the current lower-boundary source changes. The typed-application SIGSEGV is independently reproduced by the canonical-only control and is not attributable to a changed oxygen dependency. The research branch remains historically behind canonical and must still be reconciled before admission, but the 36-commit count must not be misreported as 36 unknown PERF02 scientific dependencies.


## Upstream canonical blocker classification

The canonical-control backtrace reaches `fmr_serialized_storage`. In the current canonical implementation the storage routine checks that `physical%water_content` is allocated and then immediately evaluates an element-wise product with `self%soil_parameters%dz`. It does not first enforce equal extent. The adjacent `fmr_serialized_storage_accounting_status` routine does enforce `size(physical%water_content) == physical%active_nodes` and checks the state/parameter node counts.

This asymmetry is a concrete fail-closed contract gap on current canonical and is consistent with the observed raw SIGSEGV. It is not yet proof that this missing guard is the unique root cause: the malformed extent may originate earlier in state/configuration ownership. PERF02 therefore records the canonical defect as an upstream runtime blocker rather than patching `mod_fmr_serialized_reference_backend` on the oxygen-performance branch.

No repository search found an existing persisted finding for this exact storage SIGSEGV/shape-contract failure. The owning runtime line should reproduce it with a minimal storage/state fixture, identify where the inconsistent extent is introduced, and repair at the earliest correct ownership boundary. PERF02 should then rerun only the required typed production-application preservation against the repaired canonical postimage.
