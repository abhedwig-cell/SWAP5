# F-PE-PROFILE05 A2C reproducibility preregistration

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

## Trigger

The current PROFILE05 postimage produced a live SWAP + MODFLOW6 failure in the existing A2C control runner at the first SWAP corrector trial:

- participant status: `6 (TRIAL_FAILED)`;
- exact control arm completed far enough to enter the same coupled test;
- A2C arm failed before a valid coupled endpoint was available.

This is the same failure class that previously rejected the looser APPROX02 candidates.

## Source reconciliation

The current PROFILE05 source tree has no `src/**` differences relative to the source head used by the successful final A2C production qualification:

`5525971b20c07fad87e536aa45fa245eff1c84ff`

Therefore this experiment tests reproducibility of the already-qualified A2C route. It is not a test of intervening production-code changes.

## Question

Does the A2C `1e-8` practical Richards envelope reproducibly pass the existing live FGC44 SWAP + MODFLOW6 gate?

## Protocol

Run six independent replicas of the existing, unchanged:

`tests/fpe/run_fpe_approx02_a2_modflow_e2e.sh`

with:

`APPROX02_CANDIDATE_TOL=1E-08`

Use the same pinned xmipy/flopy dependencies as the APPROX02 production qualification.

No source implementation changes are allowed.

## Required observations

For each replica classify:

- exact arm success/failure;
- A2C arm success/failure;
- failure class when present;
- final MODFLOW head when available;
- final SWAP groundwater exchange when available;
- interface ledger exchange when available;
- coupled iteration count;
- measured coupled-loop runtime when available.

## Decision rule

A2C coupled robustness is considered reproduced only if all six new replicas pass.

Any new A2C-only `TRIAL_FAILED` result is evidence that the earlier 3/3 gate did not establish a sufficiently reproducible robustness envelope.

This is a robustness decision, not a timing decision. A successful majority cannot override a candidate-only transaction failure.

If reproducibility fails, PROFILE05 must not form an A1+A2C production-stack performance claim. A separate workunit must determine why nominally identical A2C runs cross the trial-failure boundary.

## Default authority

A2C remains default OFF.

Exact production behavior is unchanged.
