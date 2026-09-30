# F-PE-NLGLOB14Z44 closeout — heterogeneous reference-validity fixture selection

Date: 2026-09-30

Final status:

`Z44_REFERENCE_FIXTURES_UNAVAILABLE`

Qualification authority:

- workflow run `36776149865`;
- job `110094433147`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z44 closes negatively on reference-fixture availability.

No O14 or B12 candidate in the frozen 16-case reference-only matrix completes the 4,000-interval trajectory.

The failures occur in the full Heritage/reference solve itself, while:

- physical ledger remains near roundoff up to the stop;
- accepted-origin mutation remains zero;
- no adaptive manager route is involved.

Therefore Z44 does not constitute evidence against the moving-interface manager.

## Strategic conclusion

The current synthetic dry/hydrostatic heterogeneous admission trajectories are not suitable admission holdouts for O14/B12.

Further ad-hoc search over tail start, dt or forcing would weaken governance and is not justified.

The next step should make the admission scope explicit before more computation:

- either define a narrow, non-default, fail-closed candidate scope using already reference-valid states/trajectories;
- or derive future heterogeneous holdouts from independently reference-qualified representative trajectories rather than from the failed synthetic family.

## Direct successor

Open:

`F-PE-NLGLOB14Z45 — admission scope and eligibility contract`.

Z45 should be an architecture/governance workunit first, not another expensive trajectory campaign.

It should:

1. define the manager's explicit eligibility boundary;
2. preserve exact full fallback outside that boundary;
3. distinguish qualified manager scope from unqualified material/trajectory scope;
4. determine whether existing O05 / Z42 evidence is enough for a narrow non-default production-admission candidate;
5. specify what additional reference-qualified holdouts would be required before broadening scope.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z44

BRANCH: `research/f-pe-nlglob14z44-reference-fixture-selection`

RESULT POSTIMAGE BEFORE CLOSEOUT: `2f120a75bd6222ab1e044798bc32963efec553bb`

QUALIFICATION STATUS: `Z44_REFERENCE_FIXTURES_UNAVAILABLE`

NEXT SAFE STEP: Z45 admission scope and eligibility contract.

## Production boundary

No production admission is authorized by Z44.

`LEGACY_NUMERICS` remains production default.
