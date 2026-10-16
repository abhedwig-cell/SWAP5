# F-PE-NLGLOB14Z43F result — canonical admission of non-default moving-interface manager

Date: 2026-09-30

Status:

`QUALIFIED_Z43F_CANONICAL_ADMISSION_READY`

Qualification authority:

- focused admission workflow run: `36780284943`;
- admission-smoke job: `110108520096`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Admission branch postimage before result persistence:

`work/f-pe-nlglob14z43f-canonical-admission-v2@5b613f257afa6254498c352aeac7363ec579d28c`

## Aggregate result

The selective canonical reconciliation passes all frozen Z43F admission gates.

Classification:

`QUALIFIED_Z43F_CANONICAL_ADMISSION_READY`.

## Selective admission diff

Z43F starts from live canonical and admits only the qualified production-facing seam:

- `src/runtime/mod_moving_interface_manager.f90`;
- explicit moving-interface profile support in `src/runtime/mod_timestep_numerical_profile.f90`;
- focused manager/profile admission tests;
- focused admission workflow and documentation.

The historical Z20-Z43E research harness/workflow lineage is not merged wholesale.

## Profile/default boundary

Focused smoke reports:

- default/unset profile remains invalid and does not select the manager;
- legacy profile remains execution-ready;
- manager profile requires explicit construction;
- manager profile is not execution-ready unless explicitly marked admission-ready.

Observed:

`DEFAULT_INVALID=1`
`LEGACY_READY=1`
`MANAGER_OPT_IN=1`
`MANAGER_NOT_DEFAULT=1`

Therefore `LEGACY_NUMERICS` remains the production default.

## Manager seam

Focused smoke confirms:

- full accepted state remains 16-node;
- reduced active view uses 13 nodes;
- reduced workspace uses active dimension 13;
- reduced candidate materializes back to a full 16-node candidate;
- reduced route is selected explicitly when valid;
- forced reduced failure selects exact full fallback;
- fallback reason remains typed/explicit;
- ineligible full-dimension view selects explicit bypass;
- failed reduced trial does not mutate accepted h/theta.

Observed smoke aggregate:

`QUALIFIED_Z43F_MANAGER_SEAM_READY`.

## Candidate evidence carried into admission

The canonical seam is backed by Z43E candidate authority:

`QUALIFIED_Z43E_PRODUCTION_ADMISSION_CANDIDATE_READY`.

Frozen candidate evidence includes:

- 4/4 reference-valid heterogeneous trajectories;
- 4/4 adaptive physical/operational passes;
- 100% reduced-route use in the frozen set;
- zero fallback/bypass incidence in the frozen set;
- geometric-mean wall ratio `0.92158`;
- geometric-mean deterministic work ratio `0.76950`;
- full-column accepted state remains sole physical authority;
- exact full fallback remains part of the manager contract.

## Numerical-profile boundary

Z43F does not admit MAXIT16 as a universal default.

MAXIT remains input/profile-owned.

The explicit MAXIT16 profile used by Z43E is evidence scope only.

## Qualified production claim

Ready for canonical admission as:

**explicit non-default moving-interface manager capability with full-state authority and exact fallback**.

Not admitted by Z43F:

- production-default replacement;
- universal accuracy tolerance;
- universal MAXIT policy;
- whole-MultiSWAP speedup claim;
- BOFEK-wide portability claim.

## Production boundary

`LEGACY_NUMERICS` remains production default.

The moving-interface manager is explicit opt-in only.
