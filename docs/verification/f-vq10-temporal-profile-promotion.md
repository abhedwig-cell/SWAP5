# F-VQ10 — Temporal profile qualification and promotion contract

F-VQ10 is qualification-only and starts from exact qualified F-VQ09 head `7af5b30ec1707ac064a93f3af84bff403a203a6d`. It changes no production SWAP source, physics, solver convergence policy, hard mass tolerance or canonical temporal profile.

## Purpose

F-VQ09 qualified the real-run harness contract but produced no admitted real B1.10 temporal observations. F-CI14 therefore still has eight `null` production temporal limits. F-VQ10 defines how future real observations may be used to propose and independently validate a candidate temporal profile without turning characterization data, solver tolerances or mass tolerances directly into production acceptance limits.

## Calibration versus validation

A promotion candidate must name nonempty calibration and validation observation sets. Observation identifiers are unique and the sets are disjoint. Calibration evidence may be used to formulate candidate limits; validation evidence may only test a candidate that was already frozen.

The complete candidate profile—including all eight limits, units, declared workload/process scope and execution-environment scope—must have an immutable hash before validation. If any limit or declared scope changes after validation starts, all prior validation evidence for that candidate is invalid and a fresh held-out validation set is required.

This prevents a nominal validation dataset from silently becoming calibration data.

## Numeric limits are not inferred by this work unit

F-VQ10 introduces no numeric temporal limits. A future limit for each metric requires an explicit independent scientific or accuracy rationale plus evidence references. The following are explicitly insufficient as the sole justification:

- a solver convergence tolerance;
- the hard mass-conservation tolerance;
- the largest observed characterization delta from one dataset;
- tuning a limit until held-out validation happens to pass.

The metric contract remains exactly `h_cm`, `theta`, `pond_cm`, `gwl_cm`, `volact_cm`, `ldwet_cm`, `spev_cm`, and `saev_cm`. Lagged `hm1_cm`, `thetm1`, `pondm1_cm`, and `gwlm1_cm` remain diagnostic-only.

## Validation semantics

For a frozen candidate profile, held-out validation uses the already qualified F-CI14 semantics: per metric `delta_i / limit_i`, aggregate by `max`, and require `normalized_error <= 1`. A zero limit requires exact equality. Every admitted validation observation must pass.

Passing validation is necessary but is not by itself permission to promote the profile. A separate qualification decision must bind the immutable candidate-profile hash, calibration IDs, validation IDs, declared scope and the exact validation evidence.

## Hard mass conservation

Every raw observation admitted into either calibration or validation must independently pass the absolute hard-mass gate for both the full and two-half paths. The mass gate is separate from temporal accuracy and is never normalized, relaxed or substituted as a temporal limit.

## Optional-process scope

A water-only candidate cannot claim complete temporal coverage when active crop, irrigation, heat, solute or WOFOST state is not explicitly compared. Such configurations remain fail-closed until their temporal state coverage is separately implemented and qualified.

## Qualification result

The pre-test postimage `95bccf47dfaf40fa725e376708b8597429ad3656` passed VQ reference qualification run `34123210957`, F-VQ10 job `101745783626`, with GNU Fortran 13.3.0 and 10/10 F-VQ10 unit tests passing. Documentation run `34123210944` also passed.

The qualified decision is `QUALIFIED_TEMPORAL_PROFILE_PROMOTION_CONTRACT_ONLY`. Claims FVQ10-C01 through FVQ10-C05 are qualified. Claims C06 through C10 remain blocked fail-closed.

No physical temporal limits were introduced, the F-CI14 production profile remains unchanged with all eight values `null`, no real B1.10 temporal characterization dataset was admitted, and production reference execution remains `BLOCKED_FAIL_CLOSED`.
