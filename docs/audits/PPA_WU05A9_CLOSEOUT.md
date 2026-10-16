# PPA-WU05-A9 closeout — canonical FMR macropore top input

Date: 2026-10-01

Status: `CLOSED_CANONICAL_ADMITTED`

Decision: `CANONICALLY_ADMITTED_SOURCE_FAITHFUL_FMR_MACROPORE_TOP_INPUT`

## Canonical evidence

- qualified code/test postimage: `3e0b0a94512183efbbe0cc1aff997e60d38296ae`
- focused qualification run: `36827295266` — SUCCESS
- preservation-workflow postimage: `dd897aab23d16e1084988240aca7631de4dceae0` — SUCCESS in run `36827442545`
- admission PR: #926
- canonical admission merge: `243f43cccd817c1bb175f14faa64efd574d6d3ca`
- post-merge preservation run: `36827754384` — SUCCESS on that exact canonical merge

## Closed capability

The canonically admitted serialized single-column Reference-Richards macropore route now accepts a separate source-faithful dynamic top-input carrier for:

- net rainfall;
- net irrigation;
- melt;
- separately owned lateral overland/infiltration-excess supply corresponding to the B1.11 `QMpLatSs` role.

Direct vertical input is partitioned by current accepted macropore top-area fraction. The lateral receipt is distributed over domains by current top-area share. The existing A6 limiter remains owner of capacity limitation, redistribution and returned-surface receipt.

Matrix `top_flux` and macropore top input remain separate ownership channels. A9 does not infer source components from `top_flux`. Only accepted macropore top input is added once to whole-column external mass.

## Preserved contracts

A9 preserves the A8 contract:

- inner Reference Richards remains `macropore_active=.false.`;
- macropore coupling remains outer and transactional;
- rejected/discarded candidates do not mutate committed physical state;
- the seven admitted macropore continuation fields remain the persisted state;
- restart/replay reproduces the next candidate;
- A8 zero-top-input behaviour remains available;
- rapid drainage remains disabled in this route.

The A9 qualification additionally demonstrated active top-input candidate isolation, discard/replay, persistence/restore and restart continuation.

## Explicit non-admitted scope

This closeout does not admit:

- reconstruction of rainfall, irrigation, melt or lateral overland input from generic FMR `top_flux`;
- ponding or runon as independent direct macropore source terms;
- covering-layer `IcTopMp > 1` physics;
- perched-zone macropore physics;
- rapid drainage;
- dynamic crack-geometry displacement feedback inside one corrector;
- RossFast macropore execution;
- parallel/concurrent MultiSWAP macropore execution;
- simultaneous A9 top-input ownership with FMR Snow, Black evaporation, Boesten evaporation, or fixed-weir surface-water routes.

Those are future bounded workunits, not defects in A9.

## Lifecycle

`implemented -> persisted -> tested -> qualified -> canonically admitted -> closed`

PPA-WU05-A9 is closed. Further expansion must use a new workunit.

The frozen Status-A review denominator is unchanged; A9 is a post-Status-A canonical capability.
