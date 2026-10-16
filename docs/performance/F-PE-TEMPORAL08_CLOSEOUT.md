# F-PE-TEMPORAL08 closeout — production admission of frozen c=0.65 temporal budget

Date: 2026-09-27

Status: `CLOSED_PRODUCTION_ADMITTED_C0P65_BOUNDED_GROUNDWATER_PROFILE`

PR:

`#655 — F-PE-TEMPORAL08: production admit history-aware c0.65 temporal budget`

Parent evidence stack:

- F-PE-TEMPORAL05 — blind physical qualification;
- F-PE-TEMPORAL06 — production-shaped repeated-corrector performance;
- F-PE-TANGENT01 — same-policy accepted-trajectory tangent authority;
- F-PE-TEMPORAL07 — MODFLOW-facing response/cache/live coupling qualification;
- F-PE-ENDPOINT01 — direct q-space independent endpoint authority.

## Admitted production policy

For the bounded fixed-interface groundwater profile:

`budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`

Coefficient:

`c = 0.65`

Floor:

`1e-5 cm`

The coefficient is not recalibrated in TEMPORAL08.

## Production ownership

Temporal-history information remains inside FMR.

Ownership path:

`accepted committed FMR continuation state -> origin capture -> scalar history scale -> participant-local trial config -> backend`

The MODFLOW/application layer does not receive or interpret predecessor hydraulic derivatives.

The generic canonical numerical configuration is not mutated.

## Bounded activation

The production bootstrap enables the policy only for the already admitted groundwater profile when:

- all tiles are `bottom_mode=5`;
- Richards temporal-history continuation is active;
- model-certificate temporal acceptance is active;
- a finite predecessor right-derivative seed is present.

The following remain outside the admission:

- standalone mode 7;
- prescribed-qbot mode 2;
- root-extraction-active groundwater;
- drainage-active groundwater;
- macropore, snow, frost and other unqualified active-process composition;
- profiles without admitted temporal-history continuation.

Missing or nonfinite history fails closed.

## Performance ownership

The predecessor derivative is reduced once at accepted-origin capture to:

`||h_dot_previous||_inf`

Repeated corrector trials perform only scalar budget evaluation.

No committed-state snapshot is performed in the temporal-policy hot path.

TEMPORAL06 production-shaped performance evidence therefore remains attributable:

- c=0.65: 768/768 complete;
- retries = 384;
- c=0.50 retries = 768;
- solver rejections = 0;
- median repeated-sequence runtime ratio c=0.65/c=0.50 = `0.73525`.

This corresponds to approximately 26.5% median trial-runtime reduction on that qualified sequence.

## Physical and numerical evidence

### TEMPORAL05

Blind holdout:

- 24/24 complete;
- mass complete;
- max |dh| = `6.565e-3 cm`;
- max |dtheta| = `6.282e-6`;
- max relative terminal flux error = `0.72%`;
- max relative integrated exchange error = `0.17%`.

### TANGENT01

The published c=0.65 tangent is the derivative of the actual c=0.65 response map.

- 8/8 directional matches;
- maximum same-policy relative mismatch approximately `2.8e-9`.

No tangent repair was required.

### TEMPORAL07

- MODFLOW-facing local linear response: PASS;
- tangent-cache behavior: PASS;
- live production-shaped coupling invariants: PASS;
- historical endpoint blocker shown not to be c=0.65-specific.

### ENDPOINT01

Direct constant-flux q-space endpoint authority:

- c=0.65 direct residual at production endpoint = `1.45082847230370757e-17 m/s`;
- production/direct head error = `2.22044604925031308e-16 m`;
- both inside unchanged frozen gates;
- historical closeout preservation: PASS.

## TEMPORAL08 admission evidence

Current-head authority run:

`36300393644`

Production-code head exercised:

`d97b607ec36457e9b9ebaf9b798b7fe672421a98`

All five TEMPORAL08 jobs pass.

### P0 — policy/default-off

PASS.

- exact frozen budget formula;
- floor behavior;
- missing history fail closed;
- default-off behavior preserved;
- F-GC49B lifecycle preserved.

### P1 — registry equivalence

PASS.

Policy-controlled and manually configured frozen-budget arms are exactly equal in:

- q;
- integrated exchange;
- accepted-trajectory tangent.

Registered base config remains immutable.

### P2 — bounded bootstrap

PASS.

- c=0.65 binding is confined to the qualified groundwater profile;
- seeded history is required;
- history scale is cached at accepted-origin capture;
- PPA-WU01 production ownership/default profiles remain green at O0 and O2.

### P3 — live production

PASS.

Historical live preservation route:

- iterations = 5;
- max residual = `1.0983254090277951e-20 m/s`.

New seeded c=0.65 production-bootstrap route:

- iterations = 8;
- max residual = `5.9811775732484325e-20 m/s`;
- live MODFLOW6 6.8.0: PASS;
- one prepared solve: PASS;
- per-cell convergence: PASS;
- MODFLOW -> SWAP -> ledger publication: PASS;
- exactly-once publication: PASS;
- missing history seed rejection: PASS.

## What changed

Production source changes are limited to:

- an optional FMR groundwater temporal-budget policy carrier;
- registry storage/forwarding of that policy;
- origin-capture reduction of predecessor history to one scalar;
- participant-local trial budget override;
- bounded production-bootstrap activation for the qualified profile.

## What did not change

No change to:

- Richards equations;
- hydraulic constitutive relations;
- BALTOL02;
- retry scale;
- temporal-indicator definition;
- physical acceptance bounds;
- tangent mathematics;
- tangent-cache defaults;
- MODFLOW coupling equations;
- groundwater storage semantics;
- publication ownership;
- mass accounting;
- coefficient c=0.65 after blind selection.

## Admission decision

The frozen c=0.65 history-aware temporal budget is admitted for production use in the bounded fixed-interface groundwater profile defined above.

Admission status:

`PRODUCTION_ADMITTED_C0P65`

Scope:

`BOUNDED_GROUNDWATER_PROFILE_ONLY`

Default behavior outside that scope:

`UNCHANGED`

## Closure

F-PE-TEMPORAL08 is closed.

The temporal-performance line has now progressed from blind policy selection through response/tangent/endpoint qualification to an explicit production binding without changing the coupling contract or the physical acceptance gates.
