# F-PE-ELASTIC58 — physical temporal head-budget qualification preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC57 — QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN`

Parent branch head:
`research/f-pe-elastic57-controller-robustness@b09ab27c7e5cd1027975f42ad61511500e180d53`

Canonical authority at start:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Frozen global conservative scaling from ELASTIC54/55:

`alpha = 0.17320259355765216`.

Frozen controller pattern from ELASTIC57:

`observe -> test -> refine if needed`

without any monotonicity assumption.

## Question

Can an explicit model temporal head budget of

`H_budget = 0.01 cm`

be independently qualified for the bottom-mode-7, swkimpl=0 defect-indicator
envelope while preserving the already qualified physical temporal-error limits?

## Budget provenance

The value `0.01 cm` is not selected from ELASTIC53-57 results.

It is the pre-existing frozen pressure-head error bound from the independent
TEMPORAL04/TEMPORAL05 physical qualification envelope:

- terminal |dh| versus refined oracle <= 0.01 cm;
- terminal |dtheta| <= 1e-5;
- relative terminal bottom-flux difference <= 1%;
- relative integrated bottom-exchange difference <= 0.5%;
- complete mass accounting.

ELASTIC58 therefore tests whether the conservative certificate condition

`alpha * Binf <= 0.01 cm`

is sufficient to preserve that complete physical envelope for mode 7.

No alternate H_budget is selectable inside ELASTIC58.

## Independent profile holdout

Use the same frozen BRO GeoPackage authority as ELASTIC55.

Exclude:
- profile 90116260;
- ELASTIC55 profiles 11060, 10260, 8016, 3030.

Apply the ELASTIC55 eligibility and diversity-key rules.

For each of the first four horizon-count classes used by ELASTIC55
(1,2,3,4 horizons), choose the smallest eligible profile id not previously used.

If any class lacks an independent profile, fail closed.

The selected profile ids are outputs of this preregistered algorithm and may
not be changed after numerical results are observed.

## Materialization

For every selected profile preserve the ELASTIC55 materialization contract:
- explicit BRO profile retrieval;
- 16-node horizon-proportional grid;
- admitted Staringreeks-2018 wcr,wcs,alpha,npar by source block;
- parent-fixture Ksat/lambda frozen;
- profile-specific GENERATED Ss;
- bottom mode 7;
- swkimpl=0;
- explicit fixed-flux top boundary.

## Physical bank

Per selected profile:

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

Initial heads:
- -75 cm;
- -20 cm;
- +2 cm;
- +10 cm.

Flux perturbations:
- -0.05;
- -0.035;
- +0.035;
- +0.05 cm/day.

Requested candidate dt ladder:
- 0.015625 day;
- repeated factor 0.5;
- 9 values total.

For each state/forcing/regime sequence C-SAFE chooses the first full-converged,
indicator-available dt satisfying:

`alpha * Binf <= 0.01 cm`.

If none satisfies, classify EXHAUSTED.

## Refined physical oracle

For every C-SAFE accepted case, independently reconstruct the same requested
physical interval from the same initial state using 32 equal direct
Reference-Richards substeps:

`dt_oracle = dt_accepted / 32`.

The oracle uses:
- the same forcing throughout the interval;
- the same bottom mode 7 free-drainage physics;
- the same constitutive parameters;
- the same hard nonlinear/mass tolerances;
- no temporal certificate or transaction retry policy.

If any oracle substep fails, the accepted case is not physically qualified and
ELASTIC58 fails closed for that case.

## Physical comparisons

Compare the C-SAFE accepted direct solve against the 32-substep oracle endpoint.

Primary frozen gates:

A. max |dh| <= 0.01 cm.

B. max |dtheta| <= 1e-5.

C. relative terminal bottom-flux difference <= 1%.

Use denominator:
`max(abs(qbot_oracle), 1e-12 cm/day)`.

D. relative integrated bottom-exchange difference <= 0.5%.

For the backward-Euler/direct Reference route define discrete integrated
bottom exchange as:
- accepted candidate: `qbot_candidate * dt`;
- refined oracle: sum over 32 substeps of `qbot_j * dt_oracle`.

Use denominator:
`max(abs(exchange_oracle), 1e-12 cm)`.

E. both candidate and oracle remain finite and mass-complete within
`1e-12 cm` absolute residual.

The comparison is intentionally stricter than merely checking
`H_INF <= alpha*Binf`.

## Holdout meaning

All selected profiles are independent of the profile/material bank used to
derive and hold out alpha in ELASTIC54/55.

H_budget is frozen before this holdout and may not be changed in response to
results.

## Gates

A1. Exactly four independent profiles selected, one each from the 1-,2-,3-,4-
horizon classes.

A2. All physical candidate sequences execute.

A3. C-SAFE uses exactly the ELASTIC57 refine-without-monotonicity rule.

A4. Every C-SAFE accepted case completes the 32-substep physical oracle.

A5. Every accepted/oracle pair satisfies all five frozen physical gates.

A6. No EXHAUSTED sequence is silently converted to acceptance.

A7. O0/O2 candidate selection semantics agree.

A8. Frozen alpha and H_budget remain exact constants.

A9. Zero `src/**` production changes.

## Decision

If any accepted case violates any physical gate, classify
`PHYSICAL_BUDGET_FALSIFIED`.

If all accepted cases pass, classify only as a qualified research physical
budget candidate.

No production admission, default budget, mode-7 production indicator change,
or transaction-policy change is authorized by ELASTIC58.
