# F-PE-NLGLOB14Z44A result — canonical admission of non-default moving-interface manager

Date: 2026-09-30

Status:

`QUALIFIED_Z44A_CANONICAL_ADMISSION_READY`

Qualification authority:

- admission-candidate authority: Z43E `QUALIFIED_Z43E_PRODUCTION_ADMISSION_CANDIDATE_READY`;
- focused canonical-admission workflow run: `36780466787`;
- workflow conclusion: SUCCESS;
- admission branch pre-test head: `2430464258a343bc3134e54d44cb67a701034d6e`.

Canonical baseline:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Selective production payload

Z44A starts from live canonical and admits only:

1. `src/runtime/mod_moving_interface_manager.f90`;
2. the explicit moving-interface profile seam in `src/runtime/mod_timestep_numerical_profile.f90`;
3. focused admission smokes;
4. admission documentation.

The accumulated research branch history, long trajectory harnesses and MAXIT16 test materializers are not part of the production payload.

## Profile/default smoke

PASS.

Observed:

- default/unset profile remains invalid / not execution-ready;
- legacy profile remains execution-ready;
- manager profile requires explicit construction;
- manager profile is not execution-ready unless explicitly marked admission-ready;
- explicitly admission-ready manager profile becomes execution-ready.

Reported authority:

`DEFAULT_INVALID=1 | LEGACY_READY=1 | MANAGER_OPT_IN=1 | MANAGER_NOT_DEFAULT=1`.

Therefore the new manager profile is explicit opt-in and does not change legacy/default selection.

## Manager seam smoke

PASS.

The focused manager smoke confirms:

- full nodes = 16;
- reduced active nodes = 13;
- reduced workspace dimension is genuinely smaller;
- reduced candidate is rematerialized to full shape;
- valid reduced route is selected explicitly;
- forced reduced failure selects exact full fallback;
- fallback reason is typed and preserved;
- full-dimension/ineligible route uses explicit bypass;
- accepted origin h/theta remains exactly unchanged across the failed reduced trial.

Reported aggregate:

`QUALIFIED_Z34_MANAGER_SEAM_READY`

and Z44A aggregate:

`QUALIFIED_Z44A_CANONICAL_ADMISSION_READY`.

## Preserved production semantics

Qualified for canonical integration:

- full-column accepted physical state remains sole authority;
- reduced request/state/workspace is scratch/reconstructible;
- manager itself does not commit accepted state;
- full fallback remains exact and explicit;
- bypass remains explicit;
- route, dimensions, workspace generation and fallback reason remain typed diagnostics;
- failed reduced work cannot leak into accepted h/theta under the focused smoke;
- no mass redistribution, correction term, dwell or hysteresis is introduced.

## Numerical-profile boundary

The Z43E heterogeneous admission evidence used an explicit non-default MAXIT16 test profile.

Z44A does **not** set MAXIT16 as a repository or production default.

Under Z43B authority, MAXIT remains runtime/profile-owned.

`LEGACY_NUMERICS` remains production default.

## Admission evidence inherited from Z43E

The production-admission candidate already established:

- 4/4 heterogeneous reference-valid trajectory holdouts;
- 4/4 adaptive physical/operational passes;
- 100% reduced-route use on the frozen set;
- zero fallback/bypass incidence on the frozen set;
- effectively machine-zero full/adaptive physical differences;
- geometric-mean trajectory wall ratio about `0.92158`;
- geometric-mean deterministic work ratio about `0.76950`.

Z44A does not repeat those long trajectories; it verifies that the selectively admitted canonical payload preserves the required ownership/default/fallback seam.

## Qualified claim boundary

Qualified:

- selective canonical payload compiles;
- default-off / explicit-opt-in configuration passes;
- reduced/fallback/bypass/rollback-no-leak manager behavior passes;
- candidate is ready for a PR to `integration/f-ci-canonical`.

Not claimed:

- production default change;
- universal material/trajectory applicability;
- BOFEK-wide qualification;
- whole-MultiSWAP speedup;
- universal MAXIT policy.

## Consequence

Open a focused canonical integration PR from:

`work/f-pe-nlglob14z44a-canonical-admission`

to:

`integration/f-ci-canonical`.

The PR must preserve `LEGACY_NUMERICS` as production default and describe the manager as an explicit non-default admitted capability.
