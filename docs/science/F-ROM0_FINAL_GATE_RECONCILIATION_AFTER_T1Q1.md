# F-ROM0 final close-gate reconciliation after ROM-0T1Q1

## Current decision

**PROCEED_TO_ROM1A under the qualified successor ROM research Reference authority.**

This is not a reclassification of either historical negative result:

- the original fixed-control ROM-0 closeout remains `NO_GO_REFERENCE_AUTHORITY`;
- ROM-0T1 remains `ORIGINAL_TEMPORAL_REFERENCE_FLOOR_NOT_MEASURABLE_UNDER_FROZEN_CONTROL`;
- the original prescribed-head R3 remains `PRESSURE_BOUNDARY_REFERENCE_SAMPLE_NO_GO`.

Those results remain valid for their frozen numerical propositions.

The current decision is based on later, separately preregistered Reference-authority workunits whose numerical-policy constants and formulas were independently established before the T1 outcomes were observed.

## Why the earlier V1 closeout was premature

The previous file `F-ROM0_FINAL_GATE_RECONCILIATION_AFTER_V1.md` treated the TA3
0.0016-versus-0.0008 result as if it filled the original ROM-0 observation-interval
matrix.

That was incorrect.

TA3 used the later R1 gravity-consistent seed and TOP_PLUS/TOP_MINUS perturbations.
The original ROM-0 preregistration requires the exact temporal floor on:

- B01:E1_NOMINAL_FLUX;
- B01:E2_DRYING_FLUX;
- B14:E1_NOMINAL_FLUX;
- B14:E2_DRYING_FLUX.

ROM-0T1 explicitly executed that exact matrix and proved that the original strict
fixed-rate policy cannot complete three of the four refined 0.0008-day trajectories.
That T1 no-go is retained as immutable evidence.

ROM-0T1Q1 is the separately preregistered successor authority that finally makes
the exact required temporal matrix reproducibly measurable.

## Successor Reference-authority chain

### Lower-boundary reachability: R3D4

The original R3 B01 prescribed-head rise/fall trajectories fail under the frozen
fixed total-rate control. R3D1 classified both failures as total-column-only, and
R3D2 showed that their integrated residuals lie inside the independently derived
prospective floating-point representation bound.

R3D4 then qualified a strict-first, fail-closed research Reference policy:

1. the original strict interval is always attempted first;
2. a strict pass is committed unchanged;
3. a failed strict attempt must leave committed state, lineage, revision and time unchanged;
4. fallback is permitted only for the independently classified total-only failure and
   only when its integrated defect lies inside the pre-solve representation bound;
5. the same physical interval is retried once on a fresh backend;
6. dt, forcing, local balance criterion, head criteria, iteration/backtracking limits
   and the independent 1e-12 cm transaction mass gate remain unchanged.

Qualification:

- 51/51 original accepted overlap states are bit-identical;
- B01 uses exactly two fallbacks, one in each prescribed-head direction;
- B14 uses zero fallbacks;
- 4/4 full prescribed-head trajectories complete;
- lower-storage and bottom-exchange directional ordering pass for both materials;
- maximum absolute committed transaction mass residual is
  8.673617379884035e-19 cm.

This closes bidirectional reachability under the successor **research** Reference authority.
The original R3 no-go is not rewritten.

### Vertical Reference floor: ROM-0V1

ROM-0V1 measured the exact original vertical-resolution row under strict fixed-flux
controls:

- B01:E1_NOMINAL_FLUX, 16x10 cm versus 32x5 cm;
- B14:E2_DRYING_FLUX, 16x10 cm versus 32x5 cm;
- same 160 cm profile;
- dt = 0.0016 day;
- 32 common endpoints over 0.0512 day;
- no representation-policy import;
- no post-result threshold construction.

Both required pairs complete, all metrics are finite, O0/O2 and repeated execution
are bit-identical, and every accepted step passes the independent 1e-12 cm mass gate.

Decision: `VERTICAL_REFERENCE_FLOOR_MEASURED`.

### Original temporal proposition: ROM-0T1

ROM-0T1 executed the exact original observation-interval matrix under the frozen
strict fixed-rate controls.

All four 0.0016-day trajectories complete. At 0.0008 day:

- B01:E1 fails at refined step 18;
- B01:E2 fails at refined step 4;
- B14:E1 completes 64/64;
- B14:E2 fails at refined step 4.

The three failures are genuine `legacy-reference-retry` outcomes at 16 nonlinear
iterations.

Decision:
`ORIGINAL_TEMPORAL_REFERENCE_FLOOR_NOT_MEASURABLE_UNDER_FROZEN_CONTROL`.

This negative remains immutable.

### T1D1 failure diagnosis

T1D1 reconstructed the three exact accepted predecessor states and reproduced each
failure without giving the diagnostic candidate any commit authority.

It found:

- B01:E1 — `RETRY_TOTAL_ONLY`;
- B01:E2 — `RETRY_TOTAL_ONLY`;
- B14:E2 — `RETRY_LOCAL_BALANCE`, one local flag, zero head flags.

The B01 total defects are inside the P2E21 prospective total representation bound.
The B14:E2 local defect is approximately 8.04e-16 cm integrated over the 0.0008-day
step, below the 1.6e-15 cm integrated compartment allowance that P2E19/P2E20 had
already frozen independently before T1.

Thus the R3D4 total-only policy could not simply be copied to T1, but an independently
defined successor balance policy already existed.

### Independent pre-T1 numerical-policy authority

P2E19 preregistered and tested a dimensionally integrated balance policy before T1:

- integrated allowance: 1.6e-15 cm per substep;
- applied to both compartment and total convergence;
- rate tolerance = 1.6e-15 / dt;
- all head, iteration, backtracking and physical controls unchanged;
- 72/72 overlapping fixed/scaled endpoints passed the frozen neutrality budgets.

P2E20 formalized that policy in a candidate-blind Reference construction.

P2E21 retained the same compartment allowance and prospectively defined the total
allowance as:

`max(1.6e-15, 0.5 * sum((spacing(theta_s)+spacing(theta_base))*dz))`.

The formula uses only pre-solve accepted state/material information. It uses no
current or failed residual, no empirical safety factor and no observed T1 result.

This authority is research Reference policy only, not a production tolerance change.

### Exact temporal floor: ROM-0T1Q1

T1Q1 preregistered the P2E19/P2E21 policy as a new strict-first, fail-closed Reference
successor on the exact T1 matrix.

For every 0.0008-day interval:

1. compute the prospective P2E21 total bound from the accepted pre-solve state;
2. execute the original strict T1 interval first;
3. commit a strict pass unchanged;
4. after a strict retry, require state/lineage/revision/time immutability;
5. diagnose the same failed interval;
6. allow fallback only for `RETRY_TOTAL_ONLY` or `RETRY_LOCAL_BALANCE`;
7. require the local integrated defect, when flagged, to be <= 1.6e-15 cm;
8. require the total integrated defect to be inside the pre-solve P2E21 total bound;
9. retry the same interval once on a fresh backend with the already frozen integrated
   compartment/total balance criteria;
10. retain the independent 1e-12 cm transaction mass gate and forbid dt subdivision.

Run 35377103955 qualified this successor:

- all four untouched strict 0.0016-day base trajectories complete;
- the original strict refined provenance is reproduced exactly;
- **87/87** original strict-accepted refined overlap states are bit-identical,
  including profiles, boundary exchange, transaction mass and solver work;
- all four successor 0.0008-day trajectories complete;
- 25 strict-first fallbacks occur:
  - B01:E1 — 9;
  - B01:E2 — 14;
  - B14:E1 — 0;
  - B14:E2 — 2;
- every fallback is an allowed balance-only class and every local/total integrated
  defect lies inside the independently pre-existing P2E19/P2E21 bounds;
- no head, mixed or other-class fallback is used;
- maximum absolute committed transaction mass residual is
  2.173319846570515e-14 cm, below the 1e-12 cm hard gate;
- O0, O2 and repeat stdout are byte-identical;
- no source or Reference tree mutation is involved.

Decision:
`T1_SUCCESSOR_REFERENCE_POLICY_QUALIFIED_AND_TEMPORAL_FLOOR_MEASURED`.

The exact original temporal matrix now has 32 common-time comparisons for all four
required cases. The measurement is retained per output; no scalar ROM acceptance
threshold is derived from it.

The maximum measured head differences over the 0.0512-day horizon are:

- B01:E1: 0.02109512745959563 cm;
- B01:E2: 0.02080887384689234 cm;
- B14:E1: 0.00010395926022965796 cm;
- B14:E2: 0.00010239594908512117 cm.

These values are numerical Reference-floor evidence, not ROM error tolerances.

## Final Q0.1–Q0.6 adjudication

### Q0.1 Ownership — PASS

Accepted states enter the research trajectory authority only through the governed
F-KT sample/candidate/commit path.

Strict failed attempts cannot mutate committed authority. Direct diagnostic solves
have no commit authority. Successor reattempts must independently produce a valid
F-KT candidate before commit.

Rejected attempts remain diagnostic evidence and are never silently promoted.

### Q0.2 Reproducibility — PASS

- TA4 proves exact restart/replay of the retained F-KT Reference state;
- R3D4 is deterministic on its frozen qualification surface;
- V1 is O0/O2 and repeat bit-identical;
- T1 is O0/O2 and repeat bit-identical, including its negative outcome;
- T1D1 is O0/O2 and repeat bit-identical;
- T1Q1 O0, O2 and repeat stdout have the identical SHA-256
  `60d484cb3c9d77f62e8ad19eb23f5428bf4bc12c21231f30d377b58564625ec9`.

The measuring instrument is therefore reproducible inside its declared deterministic
boundary.

### Q0.3 Conservation — PASS

Every retained accepted sample remains protected by the independent 1e-12 cm
transaction mass gate.

Representative maxima:

- R3D4: 8.673617379884035e-19 cm;
- T1Q1: 2.173319846570515e-14 cm;
- V1: below 3.64e-14 cm.

Failed strict attempts are never committed.

### Q0.4 Bidirectional reachability — PASS under successor research Reference authority

R3D4 completes the preregistered prescribed-head rise and fall trajectories for both
B01 and B14 and passes the preregistered directional lower-storage and
bottom-exchange ordering.

The original fixed-control R3 no-go remains historical evidence and is not reclassified.

### Q0.5 Reference floor — PASS / MEASURED

The **exact original required matrix** is now complete:

- observation interval:
  - 0.0016 versus 0.0008 day;
  - B01:E1, B01:E2, B14:E1, B14:E2;
  - 32 common times per case;
  - measured by the qualified T1Q1 successor Reference authority after the original
    strict T1 proposition was retained as a no-go;
- vertical resolution:
  - 16x10 versus 32x5 cm;
  - B01:E1 and B14:E2;
  - measured by V1 under strict fixed-flux controls.

All differences are retained per requested output and horizon.

The original preregistration rule is respected:
**MEASURE_ONLY — no post-result ROM accuracy threshold is derived from these floors.**

### Q0.6 No production semantic mutation — PASS WITH RESEARCH-REFERENCE SCOPE

Relative to the already qualified TA5 sample-binding head, the current ROM-0
successor branch has **no changes in `src/` or `reference/`**.

ROM work after TA5 changes only tests, research authority, evidence and per-experiment
numerical inputs.

No production Richards equation, production solver selection, canonical transaction
ownership, application temporal budget or production fallback semantics are changed.

TA5 itself only admitted already-supported bottom mode 5 to the governed research
Reference-floor sample seam and was independently qualified.

Neither the R3D4 nor T1Q1 fallback policy is production-admitted.

## Close decision

All six original ROM-0 close gates are satisfied under the strongest current
non-conflicting successor **research Reference authority**.

`ROM0_DECISION = PROCEED_TO_ROM1A`

`ROM1A_AUTHORIZED = true`

This authorization is limited to ROM-1A state-identification preparation and
trajectory-library/data-split design under the qualified ROM research Reference
authority.

It does **not** authorize:

- a production reduced solver;
- a production Reference fallback/tolerance policy;
- ROM closure;
- production application admission;
- reuse of the measured Reference floors as post-hoc ROM tolerances.

## Next bounded workunit

ROM-1A must start with a new preregistration of:

- discovery histories;
- held-out histories;
- discovery future probes;
- held-out future probes;
- material-transfer challenge;
- output/observation schema;
- rules for propagating the measured numerical Reference floor into interpretation.

No reduced coordinate, POD basis, memory variable or closure model may be selected
before that preregistration.
