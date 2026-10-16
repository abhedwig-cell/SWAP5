# F-PE-BOFEK01/02 closeout — strict numerical-policy optimization

Date: 2026-09-28

Final status:

`CLOSED_NO_POLICY_GAIN`

Canonical authority:

`integration/f-ci-canonical@50ee9dc2acbc9847807d3fd98d0553f9862d428b`

Primary evidence:

- preregistration: `docs/performance/F-PE-BOFEK01_02_PREREGISTRATION.md`;
- test bank: `docs/performance/F-PE-BOFEK01_TESTBANK.json`;
- final screen: `docs/performance/F-PE-BOFEK01_02_RESULT.md`;
- supplemental screen record: `docs/performance/F-PE-BOFEK01_SCREEN_RESULT.md`;
- screening Actions run: `36413271282`;
- independent fixed-step oracle run: `36413551568`;
- oracle-solvability run: `36413798107`;
- P1/P1R result: `docs/performance/F-PE-BOFEK01_P1R_RESULT.md`.

## Decision

No tested strict Reference numerical-policy candidate satisfies the frozen advancement rule.

The workunit therefore does not qualify:

- a new global numerical policy;
- a BOFEK/hydraulic-class numerical policy;
- a regime-aware strict numerical policy;
- any production timestep or convergence-default change.

No production `src/**` change is made by this workunit.

## Why interaction and holdout stop here

The preregistration allowed interactions only for parameters that independently showed at least 8% median deterministic solver-work reduction while passing all strict physical gates.

None did.

Accordingly:

- interaction tuning is not authorized;
- the four holdout cases remain unused for candidate selection;
- no failed screening candidate is rescued post hoc by widening gates or adding interactions.

This is a negative result, not an incomplete run.

A separately preregistered independent fixed-step oracle was also attempted because the current adaptive Reference trajectory is not itself temporal truth. That oracle resolved only 1/16 screening cases at dt=0.0005/0.00025 d. Increasing Reference MAXIT from 8 to 20 and 48 still resolved exactly 1/16. The oracle limitation therefore does not rescue any P0 candidate and does not justify post-hoc finer-step chasing.

## Main findings

1. Larger `DTMAX` and larger initial dt can reduce exact solve work materially in isolated cases, but the resulting accepted-dt trajectory changes terminal head/runoff/ponding beyond the strict Reference gates in most cases.
2. `NUMBIT_CRIT`, increase/decrease factors and failure-reduction factor do not provide a robust strict work reduction.
3. `MAXIT` tuning does not reduce work and lower caps introduce failures.
4. Backtracking-cap changes preserve all screening cases but do not reduce deterministic work.
5. Head-convergence relaxation shows the only broad nonlinear-effort signal, but x10 gives about 3% median work reduction and x100 about 6%, both below the frozen 8% gate and with strict runoff failures.
6. BALTOL02 remains fixed authority and is not reopened.
7. The independent fixed-step oracle is not broadly usable under current Reference solver authority: 1/16 resolved at MAXIT 8, 20 and 48. This limits stronger claims about temporal truth, but does not create an advancing candidate.

## BOFEK interpretation boundary

The repository currently lacks a complete BOFEK profile catalogue/mapping.

The exercised B01/B12/O05/O14 hydraulic archetypes are adequate to reject the tested simple global strict-policy hypotheses, but they do not support a BOFEK-ID-specific production mapping.

Therefore this closeout must not be cited as proof that every BOFEK profile has individually been optimized.

## Preserved authority

BOFEK00 remains unchanged and preserved:

- fixed-K dynamic-top;
- `SWKIMPL=0`;
- corrected wet Jacobian;
- corrected analytical linear-runoff branch selection.

No correctness surface is retuned.

## Parked successor questions

These are useful but outside this strict workunit:

1. `F-PE-BOFEK-PRACTICAL01`: preregister a bounded PRACTICAL / COUPLING mode that deliberately trades some trajectory accuracy for fewer/larger timesteps. The current screen shows this is where the actual speed/accuracy tradeoff exists.
2. BOFEK catalogue authority: add or bind an authoritative BOFEK-ID to hydraulic-profile mapping before any BOFEK-class-specific production policy claim.
3. If practical mode is opened, start from the observed levers `DTMAX/initial-dt` and head tolerance rather than re-screening MAXIT/backtracking/failure factors.
4. A future strict temporal-oracle line would need a different independently justified construction, not post-hoc smaller fixed dt values under this workunit.
5. `SWKIMPL=1` remains separately gated and is not inferred from this work.

## Final classification

`CLOSED_NO_POLICY_GAIN`

Meaning:

Within the strict corrected Reference surface and preregistered screening domain, no simple numerical-policy change provides enough solver-work reduction while preserving the required trajectory equivalence to justify production tuning.

