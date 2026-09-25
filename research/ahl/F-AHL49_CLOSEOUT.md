# F-AHL49 — production-shaped direct-retention extraction status

Date: 2026-09-25

Status: `QUALIFICATION_PENDING_RUNNER_CAPACITY`

Parent authority: F-AHL48 closed shared immutable ownership, 64 intervals per decade.

PR: #619.

Current head: `ce358bf43cab29d6c647a400078df55d80d11f2b`.

## Production-shaped architecture

F-AHL49 extracts the F-AHL48 direct-retention architecture into production modules.

Representation:

- 64 intervals per decade over |h| = 1..1e6 cm;
- direct decade selection;
- direct interval arithmetic;
- cubic Hermite theta representation;
- C is the exact derivative of the same interpolant;
- full hydraulic evaluation remains analytical;
- K and point conductivity remain analytical;
- analytical fallback outside the represented head domain.

Routing is explicit opt-in and default OFF.

## Ownership lifecycle

The production-shaped representation pool is shared by exact hydraulic authority.

Build/acquire occurs during parameter preprocessing. The persistent parameter object stores only the prepared representation slot. Trial-time provider binding receives that slot directly and performs no authority lookup or representation build in the solve hot path.

The first production extraction supports one active direct-retention application owner at a time:

`single application owner -> serial acquire/build -> freeze -> immutable reads -> close`

A second opt-in application while the first owner is alive must fail closed.

The public research/test reset cannot clear the pool while an application owner is active.

Application close releases the owner and clears the pool, after which a later application may initialize safely.

This singleton-owner boundary is explicit and intentional. Multi-application shared ownership is not admitted by F-AHL49.

## Initial envelope

Direct-retention routing is admitted for qualification only when all of the following hold:

- default B1.10 MvG hydraulic authority;
- hydraulically homogeneous active profile;
- prescribed-head bottom mode 5;
- SWKIMPL = 0;
- no tabulated hydraulics;
- no hysteresis;
- no KSATEXM extension.

The following remain outside the F-AHL49 envelope:

- prescribed qbot;
- standalone mode 7;
- layered/heterogeneous hydraulic authorities;
- SWKIMPL = 1;
- KSATEXM composition;
- tabulated hydraulics;
- hysteresis;
- default-on behavior;
- analytical K replacement.

Unsupported opt-in preprocessing must return not-prepared and leave `prepared_direct_retention_slot = 0`.

## Inherited evidence

F-AHL47 research provider:

- 12/12 B01/B12/O05/O14 × wet/mid/dry path-identical;
- 12/12 speed-positive;
- median current-postimage solver ratio about 0.737.

F-AHL48 shared immutable ownership:

- 64 intervals/decade passes the same 12-case matrix;
- raw theta+C payload = 6,240 bytes per unique hydraulic authority;
- 10,000 same-authority providers share one table;
- frozen OpenMP reads qualified;
- shared-provider 12-case median ratio about 0.725.

These are prerequisite research authorities, not substitutes for F-AHL49 production-module qualification.

## F-AHL49 gates

The following current-head workflows are authoritative once executed:

1. `F-AHL49 provider extraction`
   - production provider semantics and pool ownership.

2. `F-AHL49 default-off preservation`
   - existing production application behavior remains unchanged with the feature OFF.

3. `F-AHL49 application opt-in`
   - production bootstrap can initialize, execute, commit and close the bounded direct-retention profile.

4. `F-AHL49 production provider matrix`
   - production modules replay the 12-case fidelity/path matrix and paired timing.

5. `F-AHL49 fail-closed envelope`
   - unsupported compositions do not retain prepared slots.

6. `F-AHL49 application scale qualification`
   - paired analytical/direct application initialization and interval timing at N=1,100,1000,10000;
   - solver counters and mass remain aligned;
   - same-authority opt-in uses exactly one 6,240-byte representation.

7. `F-AHL49 multi-application ownership`
   - active-owner reset protection;
   - second direct-retention owner rejected;
   - first owner slot remains stable;
   - new owner allowed after close.

8. Existing PPA-WU01 and relevant inherited integration gates
   - manual compile closures include the new production modules;
   - no default-off or application-owner regression.

## Current blocker

The current-head qualification jobs are queued in GitHub Actions and have not started.

This is a runner-capacity blocker only. It is not numerical evidence and must not be treated as a pass or failure.

No additional production-code changes are justified until these current-head gates execute.

## Admission rule

F-AHL49 may become a production admission candidate only when:

- all F-AHL49-specific gates pass on the same current head;
- the large-N application gate confirms ownership and bounded setup cost;
- the production 12-case matrix retains path/fidelity and material timing benefit;
- default-off preservation passes;
- inherited integration failures, if any, are reconciled as either F-AHL49-caused or external.

Until then:

`F-AHL49 = NOT_ADMITTED_QUALIFICATION_PENDING`

## Next decision

If all gates pass:

`F-AHL49 -> READY_ADMISSION_CANDIDATE`

If any gate fails:

repair only the demonstrated failure and rerun the affected qualification boundary. Do not broaden physics or routing scope.
