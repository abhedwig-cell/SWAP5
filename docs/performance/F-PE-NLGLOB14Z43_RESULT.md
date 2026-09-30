# F-PE-NLGLOB14Z43 result — moving-interface manager production-admission candidate preparation

Date: 2026-09-30

Status:

`Z43_HOLDOUT_PHYSICAL_MISMATCH`

Qualification authority:

- workflow run: `36775798082`;
- job: `110093253754`;
- workflow conclusion: SUCCESS.
- prior run `36775669605` failed before final classification only because the classifier expected a non-existent `STEPS` field; the parser was corrected to the frozen 4,000-step horizon without changing physics, timing or gates.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z43-production-admission-candidate@2934b65bb5f13515a43711eae3d57291feaa9953`

## Configuration seam

PASS.

The explicit non-default profile smoke reports:

- unset/default profile remains invalid rather than silently selecting the manager;
- legacy numerical profile remains execution-ready;
- moving-interface profile requires explicit construction;
- moving-interface profile is not execution-ready until explicitly marked admission-ready.

Observed:

`DEFAULT_INVALID=1`
`LEGACY_READY=1`
`MANAGER_OPT_IN=1`
`MANAGER_NOT_DEFAULT=1`

Thus the Z43 configuration seam preserves the existing legacy/default behavior.

## H1 — O05_N64_T49

PASS.

The Z42 authority replay remains strongly positive:

- 4,000 / 4,000 reduced-route intervals;
- fallback count: 0;
- bypass count: 0;
- mean active dimension: 49;
- final full/adaptive tail: 49 / 49;
- max h difference: effectively zero;
- max theta difference: 0;
- max physical ledger: about `7.42e-17 cm`;
- origin leak: 0;
- deterministic work ratio: `0.765625`;
- wall-clock ratio: `0.91833`.

Equivalent trajectory wall-clock gain is about 8.2%.

## H2 — O14_N64_T49

FAILS BEFORE ADAPTIVE MANAGER EVALUATION.

The full 64-node Heritage/reference solve does not converge under the frozen H2 configuration.

The harness emits:

`F_PE_NLGLOB14Z43_PHYSICAL_FAIL full solve failed`

Therefore H2 cannot serve as a valid adaptive-vs-full production holdout under the frozen Z43 setup.

This is not evidence that the moving-interface manager failed:

- the failure occurs in the full reference path;
- the adaptive candidate is not the cause of the failed holdout;
- no fallback or manager-route conclusion can be drawn for H2.

## H3 / H4

Not executed after the frozen H2 physical failure.

The Z43 aggregate may already be classified negatively once a frozen holdout physical gate fails, so the runner stops the compact campaign.

## Frozen aggregate classification

`Z43_HOLDOUT_PHYSICAL_MISMATCH`.

The production-admission candidate is therefore **not qualified** by Z43.

## Interpretation

Z43 does not reverse the positive moving-interface evidence through Z42.

It identifies a holdout-design/reference-solvability blocker:

- O05/N64 remains physically exact and materially faster;
- the opt-in configuration seam is valid;
- O14/N64 with the frozen tail/forcing/max-iteration configuration is not solvable by the full reference route.

Before an admission candidate can be judged across heterogeneous materials, the holdout set itself must be reference-solvable.

## Qualified claim boundary

Qualified:

- explicit non-default moving-interface numerical profile exists;
- legacy/default semantics remain unchanged;
- H1 reproduces trajectory-level gain with zero fallback and exact physics;
- H2 full-reference solvability fails under the frozen Z43 setup.

Not qualified:

- 4/4 heterogeneous admission holdouts;
- admission-candidate performance aggregate;
- production admission;
- canonical merge;
- production default change.

## Consequence

Open a separately preregistered reference-solvability attribution workunit.

It must diagnose H2 and, before opening another admission campaign, verify the full-reference first-step/short-trajectory solvability of:

- O14_N64_T49;
- B12_N64_T49;
- O05_N32_T25.

Do not change Z43 gates retroactively.

Any successor may consider a revised holdout geometry or numerical configuration only after establishing why the full reference failed.

## Production boundary

Admission-candidate attempt only.

No canonical admission is authorized.

`LEGACY_NUMERICS` remains production default.
