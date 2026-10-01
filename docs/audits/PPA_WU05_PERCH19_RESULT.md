# PPA-WU05-PERCH19 result — source-faithful FrReduQ retry ladder

Date: 2026-10-01

Status: `CLOSED_QUALIFIED_CONTROLLER_AND_RUNTIME_RETRY / PERSISTENCE_FOLLOWUP_REQUIRED`

Research baseline:
`research/ppa-wu05-a18-perched-authority-fixture@77f47a7d98cece4b371fdf078525a7ade7daec4a`

Current canonical reconciliation:
`integration/f-ci-canonical@0bf4bc0aec1d1f5d157ba6b4a88f0117c854bf6b`

Qualified postimage:
`665258f5d31c023a4594f151060fcd00e62bb04f`

Qualification run:
`36874562748` — SUCCESS.

## Decision

`QUALIFIED_SOURCE_FAITHFUL_FREDUQ_CONTROLLER_AND_ACTIVE_RETRY_ROUTE`

Production admission remains blocked until the accepted reduction continuation is persisted
through an explicit FMR numerical-continuation/restart layout.

## Exact source semantics migrated

PERCH19 represents:

`FrReduQ = 0.1 ** IDecMpRat`

with bounded levels 0..3:

- level 0: 1.0;
- level 1: 0.1;
- level 2: 0.01;
- level 3: 0.001.

On retry-advised nonlinear failure:

- increment level if below 3;
- retain accepted physical state;
- retry the same trial from accepted authority.

On successful accepted execution while reduced:

- increment stable-step counter up to 10;
- reduce the level by one when either:
  - current `dt > dtold`; or
  - ten stable accepted steps have accumulated.

The controller is a typed numerical process and is not part of the seven-field physical
macropore continuation state.

## G1 — exact controller oracle: PASS

The focused oracle proves:

- factor identity at every level;
- 0→1→2→3 failure escalation;
- no escalation beyond 3;
- nine stable steps retain a reduced level;
- the tenth stable step recovers one level;
- a larger timestep recovers one level;
- deterministic state transition from the same input checkpoint.

Marker:

`PPA_WU05_PERCH19_CONTROLLER_ORACLE=PASS`.

## G2 — A18 source-backed active retry: PASS

The A18 Andelst perched authority is now executed through one runtime call.

The test no longer manually chooses factor 0.1.

The runtime begins at level 0 / factor 1.0. The first inner solve requests retry. The
controller advances to level 1 / factor 0.1, and that attempt converges.

Qualified physical result remains the A18 result:

- final exchange approximately `-0.25748894374328285 cm/d`;
- macropore storage gain approximately `5.149778874865657e-4 cm`;
- internal exchange residual = 0;
- macropore balance residual = 0.

The accepted reduction continuation is level 1 with one stable accepted step.

Marker:

`PPA_WU05_PERCH19_A18_RETRY_LADDER=PASS`.

## Preservation: PASS

The same run replays the original A18 source-backed baseline and active-inner evidence with
the PERCH19 controller disabled.

This caught and repaired an initial preservation defect: the first implementation
overwrote caller-supplied fixed `flow_reduction` even when the controller policy was
disabled.

Final behavior is fail-closed:

- `source_reduction_retry_enabled=false`: existing caller-supplied reduction remains
  authoritative;
- `source_reduction_retry_enabled=true`: PERCH19 owns the source ladder.

A18 preservation is green on the final postimage.

## Remaining production gap

PERCH19 currently returns the accepted numerical continuation as a runtime result, but the
serialized FMR transaction/restart contract does not yet persist it.

That matters because exact B1.11 does not reset `IDecMpRat` to zero every accepted
timestep.

Production requires explicit persistence of:

- reduction level / `IDecMpRat`;
- stable-step counter / `NStep`;
- previous timestep / `dtold`.

These are numerical continuation, not physical macropore state.

The repository already has a numerical-continuation layout mechanism
(`FMR_NUMERICAL_CONTINUATION_*`). The next workunit should use that mechanism rather than
adding fields to the seven-field macropore physical state.

## Next safe step

Open:

`PPA-WU05-PERCH20 — macropore reduction numerical-continuation restart layout`.

PERCH20 must prove:

- accepted continuation publishes only on commit;
- rejected/discarded candidates leave accepted continuation unchanged;
- restart restores level/counter/dtold exactly;
- next interval starts at the restored factor;
- recovery semantics survive restart;
- A18/PERCH19 physical result and A8-A10 default behavior remain preserved.

Any eventual canonical admission branch must still be reconstructed from then-current
canonical because of the historical namespace collision.
