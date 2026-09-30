# F-PE-NLGLOB14Z43C result — revised explicit-profile production-admission holdout

Date: 2026-09-30

Status:

`Z43C_REFERENCE_PROFILE_NOT_VIABLE`

Qualification authority:

- workflow run: `36777542398`;
- job: `110099141593`;
- workflow conclusion: SUCCESS.
- prior run `36777356585` failed before result exposure because the generic MAXIT16 materializer did not recognize the holdout source spacing; the syntax-tolerant Z43C materializer changed only `max_iterations=8 -> 16`.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z43c-explicit-profile-admission@a28df01d2d3f4c7e7313f7f13d7930080ab5202f`

## Configuration seam

PASS.

The moving-interface manager remains explicit opt-in and non-default:

- default/unset profile does not select it;
- legacy profile remains execution-ready;
- manager profile requires explicit construction;
- manager profile is not execution-ready unless explicitly marked admission-ready.

## Mandatory MAXIT16 full-reference preflight

### H1 — O05_N64_T49

PASS through all 4,000 intervals.

Final diagnostic:

- nonlinear iterations: 3;
- Jacobian builds: 3;
- linear solves: 3;
- retry: false;
- max physical ledger: about `7.42e-17 cm`;
- tail: 49.

### H2 — O14_N64_T49

FAIL.

- first failing interval: 286;
- last accepted interval: 285;
- solver status: retry advised;
- nonlinear iterations: 16;
- Jacobian builds: 16;
- linear solves: 16;
- backtracking attempts: 16;
- internal retries: 1;
- route: `legacy-reference-retry`;
- max accepted physical ledger before failure: about `1.19e-15 cm`;
- tail remains 49.

This is the same interval at which MAXIT8 failed in Z43A, but the full reference now consumes 16 iterations before advising retry.

Therefore O14/N64/T49 is not rescued by the single frozen MAXIT16 profile.

### H3 — B12_N64_T49

PASS through all 4,000 intervals.

At final interval:

- nonlinear iterations: 2;
- Jacobian builds: 2;
- linear solves: 2;
- retry: false;
- max physical ledger: about `1.19e-15 cm`;
- tail: 49.

Thus the Z43A B12 ceiling failure was resolved by the frozen MAXIT16 test profile.

### H4 — O05_N32_T25

PASS through all 4,000 intervals.

At final interval:

- nonlinear iterations: 3;
- Jacobian builds: 3;
- linear solves: 3;
- retry: false;
- max physical ledger: about `1.96e-16 cm`;
- tail: 25.

## Frozen aggregate classification

Because the mandatory 4/4 full-reference preflight fails on H2:

`Z43C_REFERENCE_PROFILE_NOT_VIABLE`.

Per preregistration, the adaptive admission holdout phase is not used as admission evidence.

## Interpretation

The reference-solvability blocker has now split cleanly:

- O05/N64 is stable;
- B12/N64 is stable under the frozen explicit MAXIT16 profile;
- O05/N32 is stable;
- O14/N64 remains a reference-solver problem at the identical trajectory location even when the iteration ceiling doubles.

This is not evidence against the moving-interface manager.

It means O14/N64/T49 under this synthetic forcing/geometry is not a valid reference authority for the compact production-admission holdout.

No further MAXIT value is tested in Z43C.

## Qualified claim boundary

Qualified:

- explicit MAXIT16 test profile is valid as a non-default legacy numerical profile;
- H1/H3/H4 are full-reference solvable for 4,000 intervals;
- B12 reference solvability is recovered relative to MAXIT8;
- O14 failure persists at step 286 even at MAXIT16.

Not qualified:

- O14 repair;
- another iteration ceiling;
- 4/4 adaptive admission holdout;
- production admission.

## Consequence

Do not tune O14 further inside the admission line.

Open a separate holdout-replacement workunit that selects a reference-solvable heterogeneous material independently of manager timing.

A suitable replacement candidate should come from an already-used pre-admission material family, and must pass a full-reference-only preflight before any adaptive timing is observed.

## Production boundary

No production admission.

No production default change.

`LEGACY_NUMERICS` remains production default.
