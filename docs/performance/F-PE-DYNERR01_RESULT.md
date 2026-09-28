# F-PE-DYNERR01 result — dynamic-top temporal defect indicator

Date: 2026-09-28

Status: `CLOSED_DYNAMIC_TOP_INDICATOR_NOT_PREDICTIVE`

Current canonical during closeout:

`integration/f-ci-canonical@94e265d18200b40d942184809e1e45694aea850f`

Primary mechanism authority:

- preregistration: `docs/performance/F-PE-DYNERR01_PREREGISTRATION.md`;
- successful Actions run: `36417846787`;
- later attribution run with explicit half-step regimes: `36418142458`;
- branch evidence head for attribution: `202393148e5cf9d67c67bae9f333367a7c3afd56`.

## Candidate

The production Reference temporal-defect operator was materialized test-only and extended at the dynamic top boundary with exactly the BOFEK00-qualified HeadCalc head-regime stiffness:

`K_surface / d_surface * (1 - dHsurf/dh_top)`.

Flux regime contributes zero top-head stiffness.

No production source was changed.

## Frozen mechanism result

Planned points: 64.

Complete full + two-half physical points:

`60/64`.

Every complete point produced a finite indicator and retained the water-ledger gate.

However:

- Spearman rank correlation between `head_inf_bound` and actual full-versus-two-half max head error: `0.4499`;
- required: >= `0.80`;
- strict safe classification at indicator <= 0.01 cm: `5/60`, only `8.3%`;
- required nontrivial safe fraction: >= `20%`;
- false-safe points: `1`;
- required: zero.

Therefore DYNERR01 does not qualify the indicator mechanism.

## Severe false-safe

The false-safe is:

`B01/POND, requested dt=0.02 d`.

Observed:

- indicator = about `0.006445 cm`;
- actual full-versus-two-half max head difference = about `33.806 cm`;
- full final dynamic-top regime = head;
- first-half final regime = flux;
- second-half final regime = head;
- full ponding = about `0.04961 cm`;
- first-half ponding = zero;
- second-half ponding = about `0.04961 cm`;
- water ledger remains roundoff-scale.

The candidate therefore linearizes the full-step endpoint in a head-boundary regime while the refined route explicitly traverses flux then head. The local endpoint defect operator does not represent that boundary-path discontinuity.

## DYNERR01A attribution

The known false-safe is the only observed `REGIME_PATH_MISMATCH` in the 60 complete points.

This satisfies the preregistered attribution condition for identifying dynamic-top regime transition as the cause of the severe false-safe.

The finding does not rescue the indicator. Even away from this mismatch the global rank correlation remains too weak and the strict 0.01 cm classifier is too conservative for useful timestep authority.

## Decision

Final classification:

`CLOSED_DYNAMIC_TOP_INDICATOR_NOT_PREDICTIVE`

Do not:

- production-admit the dynamic-top defect extension;
- fit a post-hoc multiplicative safety factor;
- grant the indicator direct timestep authority;
- claim the production fixed-flux temporal indicator generalizes to dynamic-top.

## Valid successor boundary

A successor may study a different question:

Can an explicit cheap dynamic-top regime-transition guard be combined with the defect indicator as a **bounded practical classifier**, where the target is the already preregistered P-C1 coupling envelope rather than a 0.01 cm scientific local-error bound?

That successor must be preregistered separately and validated on unexposed cases before any policy claim.
