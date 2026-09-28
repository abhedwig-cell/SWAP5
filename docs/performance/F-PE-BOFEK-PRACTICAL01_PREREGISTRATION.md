# F-PE-BOFEK-PRACTICAL01 preregistration — bounded coupling-mode numerical policy

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@1113eb11966f3e5a5ced5c6e14f243d6de79a3b5`

Parent authority:

- F-PE-BOFEK00: corrected fixed-K dynamic-top `SWKIMPL=0`;
- F-PE-BOFEK01/02: `CLOSED_NO_POLICY_GAIN` for STRICT Reference;
- BALTOL02: dt-scaled balance floor remains fixed;
- no production numerical-policy change is inherited from the strict workunit.

## Purpose

Test whether a deliberately bounded PRACTICAL / COUPLING mode can reduce exact solver/timestep work enough to matter for MultiSWAP/MODFLOW-style workloads while keeping physical deviations controlled and explicit.

This workunit does not redefine scientific Reference accuracy.

Possible outcome is research-only unless separately admitted.

## Baseline

Comparator is the current corrected adaptive Reference policy on current canonical:

- DTMIN = 0.001 d;
- DTMAX = 0.02 d;
- initial dt = sqrt(DTMIN*DTMAX);
- NUMBIT_CRIT = 4;
- MAXIT = 8;
- max backtracking = 8 in the screening harness;
- increase factor = 2;
- accepted-step decrease factor = 0.5;
- failure reduction divisor = 2;
- strict head tolerance = 1e-9 in the hydraulic/regime harness;
- BALTOL02 effective balance floor;
- SWKIMPL=0.

The existing 20-case hydraulic/regime bank from F-PE-BOFEK01 is reused.

Selection uses the 16 screening cases. The four frozen holdouts remain:

- B12/POND;
- O14/MOIST;
- O14/WET;
- O14/POND.

## Practical accuracy class P-C1

P-C1 is a bounded coupling-oriented accuracy class.

A candidate passes a screening case only if all of the following hold relative to the current corrected adaptive Reference baseline:

- cumulative runoff:
  - absolute difference <= 0.01 cm when baseline runoff < 1 cm;
  - otherwise relative difference <= 1.0%;
- terminal storage:
  - absolute difference <= 0.01 cm when baseline storage change is small;
  - otherwise relative difference <= 0.5% of baseline terminal storage;
- terminal ponding absolute difference <= 0.02 cm;
- terminal top, middle and bottom pressure-head absolute difference <= 2.0 cm each;
- maximum per-step combined water-ledger residual <= 5e-8 cm;
- no solver failure;
- rejected attempts <= max(2 times baseline rejected attempts, 25% of candidate attempts).

Mass conservation is not relaxed. Only trajectory equivalence is relaxed.

## Performance gate

Primary metric remains deterministic work:

`work_index = nonlinear iterations + backtracks + Jacobian builds + linear solves`.

A candidate advances only if:

1. P-C1 passes on at least 15/16 screening cases;
2. median deterministic work reduction >= 15%;
3. no wet/ponding screening case fails;
4. no new retry pathology appears.

The higher 15% threshold is intentional: practical mode should buy a material speed benefit to justify its extra policy surface.

Wall-clock remains secondary until holdout. Final timing requires at least five paired repetitions per holdout case.

## Candidate set

Only levers showing a plausible speed/accuracy tradeoff in the strict screen advance:

### Timestep candidates

- `DTMAX_X2`;
- `DTMAX_X4`;
- `DT0_HALFMAX`;
- `DT0_MAX`.

### Head convergence candidates

- `HEAD_X10`;
- `HEAD_X100`.

No re-screen of:

- MAXIT;
- max backtracking;
- NUMBIT_CRIT;
- increase/decrease factor;
- failure-reduction divisor;
- balance tolerance.

Those families produced no useful strict work signal or are already owned by other authority.

## Interaction gate

Only independently advancing candidates may interact.

Permitted first interactions:

- best advancing timestep candidate x HEAD_X10;
- best advancing timestep candidate x HEAD_X100.

No other interaction may be introduced without a preregistered amendment.

## Holdout qualification

An interaction or single candidate may be called a practical-mode candidate only if all four holdouts pass P-C1 and:

- median deterministic work reduction on holdout >= 15%;
- median paired wall-clock improvement >= 10%;
- no individual holdout wall-clock regression > 10% unless deterministic work is non-inferior and timing spread overlaps;
- BOFEK00 wet/ponding route remains stable;
- no dry-case failure occurs.

## Policy complexity rule

Prefer a global practical policy.

A regime split is considered only if:

- no global candidate qualifies;
- at least one candidate clearly qualifies in one regime family and clearly fails another;
- the split improves median work by at least 10 percentage points versus the best global practical candidate.

No BOFEK-ID-specific policy may be claimed without an authoritative BOFEK catalogue.

## Production boundary

This workunit initially changes only docs/tests/workflow.

Any production binding requires a separate admission step after:

- successful holdout;
- repeated wall-clock confirmation;
- current-canonical preservation;
- explicit practical-mode opt-in/default-off semantics.

Possible final statuses:

- `PRACTICAL_MODE_CANDIDATE_RESEARCH_ONLY`;
- `QUALIFIED_GLOBAL_PRACTICAL_POLICY`;
- `QUALIFIED_REGIME_AWARE_PRACTICAL_POLICY`;
- `CLOSED_NO_PRACTICAL_POLICY_GAIN`;
- `BLOCKED_<reason>`.

