# F-PE-NLGLOB14Z43 preregistration — moving-interface manager production-admission candidate preparation

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z42: `QUALIFIED_Z42_TRAJECTORY_TIMING_GAIN`;
- Z41: real reduced HeadCalc scaling trend qualified through N=64;
- Z40: actual Heritage/reference HeadCalc reduced binding physically qualified;
- Z35: production-shaped manager physical binding smoke qualified;
- Z34: manager seam architecture qualified;
- Z31R/Z33: long-horizon moving-interface physics and practical bridge qualified in research scope.

## Purpose

Prepare and qualify a non-default production-admission candidate for the moving-interface manager without changing the production default.

Z43 is not canonical admission itself.

It must package the already-qualified manager/reduced-HeadCalc route behind an explicit configuration seam and demonstrate compact heterogeneous trajectory evidence sufficient for an admission decision.

## Frozen admission-candidate boundary

### Production default

`LEGACY_NUMERICS` remains the production default.

The moving-interface manager must be opt-in/non-default only.

### Accepted-state authority

Full-column accepted SWAP state remains sole physical authority.

Reduced active state/workspace remains reconstructible scratch.

### Fallback

Exact full-column fallback remains explicit and typed.

No silent repair of a reduced candidate is allowed.

### Transaction and mass

Existing transaction/rollback and physical mass authority remain unchanged.

No mass redistribution is allowed.

## Frozen compact trajectory holdout set

Use exactly four production-shaped trajectories.

All trajectories use the real compiled Heritage/reference HeadCalc route and the qualified manager seam.

### H1 — O05_N64_T49

- material: O05;
- full nodes: 64;
- initial tail: 49:64;
- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- qbot = 0;
- 4,000 nominal intervals.

This is the Z42 authority replay.

### H2 — O14_N64_T49

Same geometry/forcing as H1, material O14.

### H3 — B12_N64_T49

Same geometry/forcing as H1, material B12.

### H4 — O05_N32_T25

- material: O05;
- full nodes: 32;
- initial tail: 25:32;
- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- qbot = 0;
- 4,000 nominal intervals.

The N32 case ensures the candidate is not admitted only on the largest frozen profile.

## Frozen physical gates

For every holdout require:

- both full and adaptive trajectories complete;
- all states finite;
- adaptive per-interval physical ledger <= 5e-8 cm;
- no rollback/origin leak;
- contiguous saturated tail;
- ownership changes at most one face per interval;
- valid provider route;
- max |h adaptive-full| <= 5e-3 cm;
- max |theta adaptive-full| <= 5e-6;
- final tail identities equal or differ by at most one face with identical ordered event-direction sequence.

These are Z43 holdout gates only.

Historical Z30/Z31 strict-reference results remain unchanged.

## Frozen manager-route gates

Per holdout report:

- reduced-route fraction;
- fallback count;
- bypass count;
- fallback reasons;
- active-dimension histogram;
- request/candidate reallocations;
- mean active dimension.

Require:

- explicit route diagnostics present;
- no silent fallback;
- no fallback storm (>5% intervals);
- no fallback reason outside the declared manager contract.

## Frozen performance gates

Per holdout report:

- full trajectory wall time;
- adaptive trajectory wall time;
- adaptive/full wall ratio;
- deterministic work ratio.

Admission-candidate performance gate:

- no holdout wall ratio >1.05;
- geometric-mean wall ratio across H1-H4 <0.98;
- at least 2/4 holdouts wall ratio <0.95;
- geometric-mean work ratio <0.90.

This does not claim whole-SWAP end-to-end speedup.

## Frozen configuration seam

Add one explicit research/non-default manager configuration identity.

The configuration must:

- be off by default;
- preserve legacy default selection;
- select the moving-interface manager only when explicitly requested;
- expose manager route/active dimension/fallback diagnostics;
- fail closed to full reference where reduced eligibility is absent or solve fails.

Do not overload or reinterpret an existing production default.

## Frozen classifications

### `QUALIFIED_Z43_PRODUCTION_ADMISSION_CANDIDATE`

Require:

- 4/4 physical holdouts pass;
- manager-route gates pass;
- performance gates pass;
- explicit non-default configuration seam exists;
- default remains legacy;
- no transaction/mass authority change.

### `Z43_HOLDOUT_PHYSICAL_MISMATCH`

Any physical holdout gate fails.

### `Z43_HOLDOUT_PERFORMANCE_NOT_READY`

Physical/configuration gates pass but performance gates fail without >1.10 regression.

### `Z43_HOLDOUT_PERFORMANCE_REGRESSION`

Any holdout wall ratio >1.10 or aggregate geometric mean >1.05.

### `Z43_CONFIGURATION_OR_FALLBACK_FAILED`

Configuration/default/fallback semantics fail.

### `Z43_EXECUTION_INVALID`

Build/timer/checksum invalid.

## Positive consequence

A positive Z43 result authorizes preparation of a canonical production admission PR/workunit.

Canonical admission must remain a separate governance step.

## Stop rules

Do not:

- change `LEGACY_NUMERICS` default;
- broaden beyond H1-H4 after exposure;
- alter forcing or gates;
- repair adaptive state from full;
- add fitted corrections;
- add mass redistribution;
- add anti-chatter logic;
- infer whole-model speedup directly.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43

BASELINE: `4e0d267300963cce380c17500b3f381773bcc200`

BRANCH: `research/f-pe-nlglob14z43-production-admission-candidate`

NEXT SAFE STEP: add explicit non-default configuration seam and execute the frozen H1-H4 compiled holdout set.

## Production boundary

Admission-candidate preparation only.

No production default change.

`LEGACY_NUMERICS` remains production default.
