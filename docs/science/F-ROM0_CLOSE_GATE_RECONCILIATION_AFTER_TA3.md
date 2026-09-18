# ROM-0 close-gate reconciliation after F-ROM0TA3

## Purpose

This reconciliation binds the live ROM-0 evidence to the original close gates and prevents successful sub-capabilities from being mistaken for ROM-0 closure.

## Current gate state

### Ownership

**PASS_WITH_RESEARCH_SCOPE.**

F-ROM0TA3 uses the separate F-KT Reference-floor sample/candidate/commit path. Research does not directly publish arbitrary solver candidates. Lineage, revision and committed time remain kernel-owned.

### Reproducibility

**PASS.**

F-ROM0TA4 qualified the retained 0.0008 d candidate under exact restart/replay:
- run 35372014491;
- executed head 0037635443454ce6b7e6d4fe56534874451f8a92;
- 4/4 B01/B14 TOP_PLUS/TOP_MINUS cases;
- all 32 post-restart replay points bit-identical;
- wrong-parameter restore fails closed;
- no worker/solver scratch persistence required.

### Conservation

**PASS for all retained Reference-floor samples.**

TA3, TA4, TA5, R3 diagnostics and the R3R1 candidate-policy experiment preserve the independent hard transaction mass gate. The R3R1 candidate full-horizon matrix reached a maximum absolute transaction mass residual of only 8.673617379884035e-19 cm.

### Prescribed-head sample binding

**PASS.**

F-ROM0TA5 qualified mode-5 prescribed-head Reference-floor sampling for B01 and B14 without changing the kernel sample core, canonical interval runtime or Reference solver.

### Bidirectional reachability

**NOT CLOSED.**

The original frozen R3 matrix remains PRESSURE_BOUNDARY_REFERENCE_SAMPLE_NO_GO.

Under the original 0.0008 d / 16-iteration / 1e-12 convergence controls:
- B14 rise and fall both complete and show the preregistered directional separation;
- B01 rise requests legacy-reference-retry at perturbation step 11;
- B01 fall requests legacy-reference-retry at perturbation step 10.

R3D1 classified both B01 failures as **RETRY_TOTAL_ONLY**:
- zero local compartment-balance flags;
- zero head-convergence flags;
- max absolute local residuals remain below 1e-12 cm/day;
- only the signed total residual exceeds the fixed 1e-12 cm/day criterion.

R3D2 then showed, without changing any solver control, that both integrated total residuals lie inside the independently derived prospective representation bound:
- representation bound: 8.881784197001252e-15 cm;
- B01 rise integrated residual: 8.4821039081362e-16 cm (0.0955 of bound);
- B01 fall integrated residual: 1.2569500995596178e-15 cm (0.14152 of bound).

This explains the R3 no-go numerically but does not reclassify it.

### Candidate representation-bounded Reference policy

**NO-GO: ENDPOINT NEUTRALITY.**

R3R1 preregistered a separate research candidate policy:
total_balance_rate_tolerance = max(1e-12, representation_bound_cm / dt_day).

The candidate:
- completed all 64 perturbation intervals in all four B01/B14 rise/fall cases;
- reproduced the original B01 failure locations in the control trajectory;
- preserved the hard mass gate;
- was O0/O2 and repeat bitwise deterministic;
- produced the required directional response for both materials.

However, the preregistered endpoint-neutrality gate failed:
- 51 original-control accepted endpoints required comparison;
- only 8 remained bit-identical;
- 43 changed under the candidate policy.

Decision: CANDIDATE_POLICY_ENDPOINT_NEUTRALITY_NO_GO.

The bit-identity gate may not be relaxed after observing this result.

### Reference floor

**PARTIAL / BLOCKED BY PRESCRIBED-HEAD REFERENCE POLICY.**

The temporal fixed-resolution component exists (0.0016 versus 0.0008 d) and restart/replay is qualified. The planned 16x10 cm versus 32x5 cm vertical-resolution diagnostic remains unexecuted.

It must not be run as if the prescribed-head R3 domain were already admitted. The lower-boundary reachability gate is still open.

### Production semantic mutation

**PASS_WITH_SCOPE.**

TA5 only widened the research sample admission guard from bottom mode 2 to already-supported bottom mode 5. R3D1, R3D2 and R3R1 are test/evidence work only and mutate no production or Reference source.

## Current bounded-execution stop

ROM-0 cannot proceed to ROM-1A.

The remaining blocker is now sharply identified as a **Reference numerical-policy governance choice**, not unknown physics or a generic solver instability.

Without new authority, the following are forbidden:
- relaxing the R3R1 bit-identity neutrality gate;
- adopting the failed always-on representation-bounded candidate;
- introducing a conditional second-solve/retry policy;
- changing dt, iteration limits, tolerances or perturbation amplitudes;
- treating the vertical-resolution diagnostic as sufficient to bypass R3;
- proceeding to ROM-1A.

A future continuation therefore requires explicit authority for a new prescribed-head Reference-floor policy, or an explicit decision that the original R3 no-go closes ROM-0 negatively.
