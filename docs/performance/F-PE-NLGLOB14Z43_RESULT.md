# F-PE-NLGLOB14Z43 result — moving-interface manager production-admission candidate preparation

Date: 2026-09-30

Status:

`Z43_HOLDOUT_PHYSICAL_FAILURE`

Qualification authority:

- workflow run: `36775559850`;
- job: `110092451445`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z43-admission-candidate@5ea0b0275b23ef1590ee329b387b2779f6a08bd4`

## Aggregate result

Z43 classifies:

`Z43_HOLDOUT_PHYSICAL_FAILURE`.

The failure is caused by the frozen O14 full-reference trajectory itself, not by a reduced-manager mismatch.

The compact admission holdout therefore cannot qualify as an admission candidate under the frozen Z43 case set.

## Configuration seam

PASS.

The new typed runtime/application configuration is explicitly default-off.

Observed config smoke:

- missing config -> manager disabled;
- explicit `DISABLED` -> manager disabled;
- explicit `ENABLED` -> manager enabled;
- unsupported value -> fail closed with manager disabled.

No existing production route is selected implicitly.

`LEGACY_NUMERICS` default behavior is unchanged.

## O05 trajectory

PASS.

The first frozen holdout reproduces the positive Z42 behavior:

- N = 64;
- active n = 49 throughout;
- 4,000 / 4,000 intervals on reduced route;
- fallback count: 0;
- bypass count: 0;
- full/adaptive final tail: 49 / 49;
- physical differences effectively zero;
- max ledger about `7.42e-17 cm`;
- origin leak: 0;
- deterministic work ratio: `0.765625`;
- wall-clock ratio: about `0.93255`.

Equivalent wall-clock gain:

about `6.74%`.

## O14 holdout failure

The next frozen holdout terminates immediately with:

`F_PE_NLGLOB14Z42_PHYSICAL_FAIL full solve failed`.

Therefore the full 64-node reference trajectory is not valid for the exact frozen O14 initial state / forcing / dt combination.

Because the full authority fails, no reduced-versus-full manager comparison is scientifically available for O14.

The runner consequently does not continue to B12, and the aggregate must remain the preregistered physical holdout failure.

## Interpretation

This is not evidence that the moving-interface manager fails on O14.

Relevant prior evidence remains:

- Z36 same-origin O14/B12 reduced physics passes;
- Z40 real compiled O14/B12 reduced HeadCalc binding passes;
- Z41 scaling physics remains exact;
- Z42 O05 trajectory timing gain remains qualified.

Z43 instead shows that the chosen heterogeneous trajectory holdout was not itself reference-valid for all frozen materials.

The admission question is therefore blocked on holdout construction/coverage, not on a detected adaptive-manager defect.

## Qualified claim boundary

Qualified:

- default-off configuration seam works and fails closed;
- O05 production-shaped trajectory again passes with favorable wall-clock timing;
- frozen O14 reference trajectory fails before adaptive comparison;
- Z43 admission-candidate criteria are not met.

Not qualified:

- heterogeneous trajectory portability;
- B12 trajectory result under Z43;
- production admission;
- canonical admission.

## Consequence

Do not reinterpret Z43 as a manager falsification and do not repair the exposed O14 fixture in place.

Open a separately preregistered reference-validity / heterogeneous-holdout construction successor.

That successor should first identify a small set of full-reference-valid N=64 trajectories for O14 and B12 using an independent reference-only feasibility grid.

Only after the reference fixtures are frozen as valid should the manager be compared on them.

The default-off configuration seam may be retained as candidate implementation evidence, but no admission claim is authorized by Z43.

## Production boundary

Candidate preparation remains incomplete.

`LEGACY_NUMERICS` remains production default.
