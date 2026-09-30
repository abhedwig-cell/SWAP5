# F-PE-NLGLOB14Z43E result — revised heterogeneous production-admission candidate

Date: 2026-09-30

Status:

`QUALIFIED_Z43E_PRODUCTION_ADMISSION_CANDIDATE_READY`

Qualification authority:

- workflow run: `36779179196`;
- job: `110104641032`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z43e-revised-admission-candidate@77f44adb07a7953e3f824715cc47883f3f3e40e7`

## Aggregate result

All frozen candidate gates pass.

Aggregate classification:

`QUALIFIED_Z43E_PRODUCTION_ADMISSION_CANDIDATE_READY`.

The explicit moving-interface manager route is therefore ready for a separate canonical-admission workunit while remaining non-default.

## Reference preflight

All four frozen reference trajectories complete 4,000 intervals under the unchanged explicit MAXIT16 test profile:

- H1 O05_N64_T49 — PASS;
- H2 B12_N64_T49 — PASS;
- H3 O05_N32_T25 — PASS;
- H4 B01_N64_T49 — PASS.

No reference retry occurs.

Maximum accepted per-interval ledgers remain approximately:

- O05/N64: `7.42e-17 cm`;
- B12/N64: `1.19e-15 cm`;
- O05/N32: `1.96e-16 cm`;
- B01/N64: `8.90e-16 cm`.

## Adaptive physical and operational result

All 4/4 adaptive holdouts pass.

For every case:

- reduced route: 4,000 / 4,000 intervals;
- reduced fraction: 100%;
- fallback count: 0;
- bypass count: 0;
- accepted-origin leak: 0;
- final full/adaptive tail: identical;
- ownership-event count: identical;
- theta difference: zero at reported precision;
- pressure-head difference: effectively machine zero;
- full/adaptive physical ledgers: identical at reported precision;
- manager diagnostics and persistent buffers remain explicit.

Active dimensions:

- N64 cases: n=49 throughout;
- N32 case: n=25 throughout.

## Performance result

Wall-clock ratios:

- H1 O05_N64_T49: `0.91581`;
- H2 B12_N64_T49: `0.90228`;
- H3 O05_N32_T25: `0.93993`;
- H4 B01_N64_T49: `0.92871`.

All 4/4 are below 0.95.

Geometric-mean wall ratio:

`0.92158`.

Equivalent aggregate trajectory timing gain is about 7.8%.

Deterministic work ratios:

- N64 cases: `0.765625`;
- N32 case: `0.78125`.

Geometric-mean work ratio:

`0.76950`.

Equivalent aggregate deterministic work reduction is about 23%.

All frozen Z43E performance gates pass.

## Configuration/default boundary

The manager remains explicit opt-in/non-default.

Qualified behavior retained from the candidate configuration seam:

- unset/default does not select moving-interface manager;
- legacy profile remains available;
- manager route requires explicit selection;
- exact full fallback remains part of the manager contract;
- full-column accepted state remains sole physical authority;
- reduced state/workspace remains scratch/reconstructible;
- `LEGACY_NUMERICS` remains production default.

The MAXIT16 profile used in this admission-candidate evidence is an explicit non-default test profile. Z43B remains authority that MAXIT is input/profile-owned rather than a universal repository constant.

## Qualified claim boundary

Qualified:

- 4/4 reference-valid heterogeneous trajectory holdouts;
- 4/4 adaptive physical equivalence under frozen practical gates;
- 100% reduced-route use in the frozen set;
- zero fallback/bypass incidence in the frozen set;
- explicit non-default configuration;
- approximately 7.8% aggregate trajectory wall-clock gain;
- approximately 23% aggregate deterministic work reduction;
- production-admission candidate readiness.

Not yet qualified:

- canonical production admission;
- production default change;
- whole-MultiSWAP speedup;
- BOFEK-wide portability;
- universal MAXIT or universal manager accuracy tolerance.

## Consequence

Open a separate canonical-admission workunit.

That workunit must reconcile the complete manager implementation/evidence to current canonical, preserve default-off semantics, run focused admission CI, document the qualified scope and test-profile boundary, and admit only the explicit non-default manager route.

## Production boundary

Candidate qualified; not yet canonically admitted.

`LEGACY_NUMERICS` remains production default.
