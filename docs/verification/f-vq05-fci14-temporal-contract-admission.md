# F-VQ05 — F-CI14 Temporal Acceptance Contract Admission

## Decision boundary

F-VQ05 qualifies the **semantics and fail-closed admission behavior** of the F-CI14 temporal-acceptance contract. It does not invent, calibrate, infer or qualify a numerical B1.10 temporal profile.

Exact qualification basis:

- oracle: B1.10;
- F-CI14 qualified source head: `da5026d8b87ad2f3c7912360891839a120ecccb6`;
- F-CI14 qualified canonical postimage: `c226988ae0782a7d8d0818f5d4aeaab61b696de4`;
- canonical F-CI14 workflow: `34107845964`, job `101697462464`;
- F-CI16 `7e87f881af937836a517e2bb957bddd941b769ab` is carried only as the moving-canonical overlay and is not consumed as F-VQ05 qualification evidence.

## What the contract means

The full interval and the two-half trajectory are compared at the same requested endpoint `t1`. Endpoint quantities `h`, `theta`, `pond`, `gwl`, `volact`, `ldwet`, `spev` and `saev` participate in the acceptance norm. Lagged continuation variables `hm1`, `thetm1`, `pondm1` and `gwlm1` are retained as diagnostics but are excluded from acceptance because they can legitimately refer to different preceding internal time levels.

Each endpoint difference is divided by a same-unit metric-specific limit. The temporal score is the maximum of these eight dimensionless ratios. The contract accepts at normalized score `<= 1.0`. The value `1.0` is therefore only the normalized boundary after limits exist. It is **not** a physical head, theta, storage or flux tolerance.

A limit of zero has exact-equality semantics: a nonzero difference fails that metric. Negative/unconfigured limits fail closed.

## Numerical profile remains blocked

`integration/f-ci/F-CI14_TEMPORAL_POLICY_PROFILE.json` contains all eight production profile entries as `null`. This is deliberate. The deterministic F-CI14 executable test assigns example values such as `h_cm=0.01` and `gwl_cm=0.10` only to exercise contract branches. Those numbers have no production qualification provenance and must not be copied into the canonical profile by F-VQ.

A later numerical profile may only be admitted from independently qualified, source-bound real B1.10 evidence. At minimum that evidence must identify the workload/process scope, provide the real full-versus-two-half observations, justify each per-metric limit with units, preserve the separate hard mass gate and explicitly qualify any active optional process class.

## Policy separation

Temporal discretization accuracy is independent of nonlinear convergence policy. `CritDevBalCp`, `CritDevBalTot`, `CritDevh*`, `dtmin`, `MaxIt` or similar solver settings are not temporal error tolerances.

Mass conservation is also independent and remains a hard acceptance condition. A temporal score may never compensate for a mass-balance failure.

## Optional process scope

Thermal, solute, irrigation, crop and WOFOST state are not yet numerically characterized by this contract. If such state is active, temporal assessment remains incomplete and fails closed rather than silently omitting active physics.

## F-VQ05 executable gate

`tools/vq/fvq05_temporal_contract_gate.py` checks exact F-CI14 provenance, the eight-null profile, endpoint and normalization semantics, zero-limit behavior, optional-process fail-closed behavior, testfixture boundaries, continued reference-execution blocking, moving-canonical ancestry and absence of F-VQ05 production-source changes.

Its successful result can qualify only `FCI14_TEMPORAL_ACCEPTANCE_CONTRACT_ONLY`. Even on PASS it must report:

- `production_temporal_profile_qualified=false`;
- `real_b1_10_temporal_acceptance_qualified=false`;
- `canonical_reference_admission=BLOCKED_FAIL_CLOSED`.

This preserves the separation between a correct acceptance mechanism and the still-missing scientific/numerical evidence needed to choose its production limits.
