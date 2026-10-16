# F-PE-ELASTIC09 — production application bootstrap result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Current canonical authority:
`integration/f-ci-canonical@f73372ec97e431e10d03b1cf6eb9db4368dfb97f`

Current candidate:
`work/f-pe-elastic09-application-bootstrap-clean@a6b776f6cb32ce01cc509e2352bd1cff03653987`

PR:
`#758`

## Scope

F-PE-ELASTIC09 lifts only the production-application bootstrap rejection for
the already admitted serialized Reference/default-MvG ELAS route.

The application already owns:

- `elasticity_active`;
- node-local `cofgen(24,:)=ELAS(:)`.

No new parameter field, parser syntax, default value, timestep policy,
convergence policy or transaction semantic is introduced.

Production source scope is exactly:

`src/runtime/mod_fmr_production_application_bootstrap.f90`.

## Production behavior

For `elasticity_active=.true.`, bootstrap admission requires:

- row 24 exists;
- `cofgen(24,:)` is finite;
- `cofgen(24,:)` is nonnegative;
- KSATEXM is inactive;
- direct retention/AHL is inactive;
- tabulated hydraulics is inactive;
- hysteresis is inactive;
- all pre-existing application-profile restrictions remain in force.

The application then uses the already admitted ELASTIC08 runtime
materialization path. No ELAS value transformation occurs in the application
bootstrap.

## Qualification evidence

Dedicated workflow:
`F-PE-ELASTIC09 application bootstrap`

Qualified code/test head:
`083a602596b96c732c2ea34aa99a3340fd1009c9`

Workflow run:
`36527206646`

Job:
`109272764791`

Conclusion:
PASS.

Named evidence:

- `F_PE_ELASTIC09_A1_BOOTSTRAP=PASS`;
- `F_PE_ELASTIC09_A3_HETEROGENEOUS=PASS`;
- `F_PE_ELASTIC09_A4_FAIL_CLOSED=PASS`;
- `F_PE_ELASTIC09_A5_DYNAMIC_IDENTITY=PASS`;
- `F_PE_ELASTIC09_O0_O2=PASS`;
- `F_PE_ELASTIC09_SOURCE_SCOPE=PASS`;
- `F_PE_ELASTIC09=PASS`.

The same dedicated gate also replays the complete existing PPA-WU01
application-bootstrap owner gate for A2 default-off preservation.

## A1 — application admission

A production application tile with active ELAS initializes successfully through
the normal `fmr_production_application_bootstrap_t` owner.

The active test uses positive pressure head so saturated ELAS storage is
constitutively exercised rather than merely transported as inactive metadata.

The application run completes and commits with the hard mass gate retained.

## A2 — default-off preservation

The existing PPA-WU01 production application bootstrap owner gate is replayed
unchanged before focused ELASTIC09 qualification.

Default-off application semantics remain preserved.

## A3 — heterogeneous ownership

The focused fixture uses node-varying `cofgen(24,:)`.

The direct prepared-parameter authority verifies:

`specific_elastic_storage(:) == cofgen(24,:)`.

No first-node/global homogenization is introduced by application bootstrap.

## A4 — fail-closed composition

Bootstrap rejection is explicitly qualified for:

- negative ELAS;
- non-finite/NaN ELAS;
- ELAS + KSATEXM;
- ELAS + direct retention/AHL;
- ELAS + tabulated hydraulics;
- ELAS + hysteresis.

The bootstrap remains fail closed before active runtime ownership is created.

## A5 — dynamic identity

The production application path is compared with a direct call to the same
serialized MultiSWAP runtime using the same:

- typed template;
- physical parameter object;
- forcing;
- committed initial state;
- numerical configuration;
- fixed-flux top-boundary provider.

Identity checks include:

- admitted/completed/committed class;
- kernel status;
- accepted substeps;
- solver iteration counters;
- nonlinear iterations;
- internal retries;
- HeadCalc calls;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- mass storage start/end;
- total input/output;
- mass residual.

The compared mass values are bit-identical in the focused oracle.

## Current-head reconciliation

After the successful run, canonical advanced from
`7d4aa0cb6790f293ff486f716c6c4eadd7d18eb8` to
`f73372ec97e431e10d03b1cf6eb9db4368dfb97f`.

The complete intervening canonical delta was inspected before reconciliation.
It consists only of F-PE-TIMEINT16 documentation, tests and workflow files.

It does not touch:

- production application bootstrap;
- serialized Reference runtime;
- typed ELAS provider/materialization;
- ELASTIC09 focused test/runner/workflow;
- PPA-WU01 application bootstrap qualification;
- mass/transaction interfaces used by this workunit.

The branch was then reconciled without force-push by merge commit onto the
current canonical authority.

Therefore the qualified ELASTIC09 evidence is inherited by the current
candidate under the repository dependency-surface rule.

## Architecture/invariant assessment

F-PE-ELASTIC09 preserves the architecture invariants relevant to this change:

- ELAS remains a physical soil/material option, separate from numerical policy;
- Full Richards Reference remains the production route;
- transactional commit/rollback ownership is unchanged;
- rejected trials do not gain new authority;
- hard water-balance qualification is retained;
- application bootstrap does not own or generate ELAS values;
- no external coupling ownership contract changes.

## Scientific boundary

F-PE-ELASTIC09 does not:

- choose an ELAS value;
- make `1e-6 cm^-1` a default;
- derive ELAS from MvG parameters;
- expose a legacy file keyword;
- qualify ELAS + KSATEXM/AHL;
- change timestep or convergence policy;
- use performance as physical parameter evidence.

## Decision

F-PE-ELASTIC09 is a qualified bounded production admission candidate.

The admitted capability, if merged, is only:

`application soil/material parameters`
-> `elasticity_active + cofgen(24,:)`
-> admitted ELASTIC08 runtime materialization
-> admitted ELASTIC05 constitutive ELAS.

Physical ELAS parameter generation remains a separate research line.


## Clean-extraction inheritance

PR #758 is a clean extraction on
`integration/f-ci-canonical@f73372ec97e431e10d03b1cf6eb9db4368dfb97f`.

The following files are byte-identical to qualified head
`083a602596b96c732c2ea34aa99a3340fd1009c9`:

- production bootstrap source;
- focused ELASTIC09 application test;
- ELASTIC09 runner;
- ELASTIC09 workflow;
- preregistration.

The canonical delta reconciled before this clean extraction does not intersect
the recorded ELASTIC09 dependency surface. Under the repository recovery and
qualification-inheritance rules in `AGENTS.md`, run `36527206646` therefore
remains valid evidence for this clean postimage.

The queued duplicate current-head run is not required to re-establish an
unchanged numerical result solely because the branch was cleanly re-extracted.
