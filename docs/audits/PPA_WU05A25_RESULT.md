# PPA-WU05-A25 result — bounded RFM runtime orchestrator

Date: 2026-10-01
Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE
Baseline: integration/f-ci-canonical@2a0b23a2c4e547f6de2613884207d10b2fce462e
Qualified postimage: d1e33f8867887ca6f1e57e52853ee83b8332650f
Qualification run: 36878318797 — SUCCESS

## Qualified scope
A25 composes the canonically admitted RFM primitives into a deterministic trial-local candidate orchestrator.

It produces:
- candidate dedicated RFM state;
- endpoint and MB wall-to-matrix source rates mapped to explicit matrix nodes;
- explicit MB deep receipt;
- exact A23 whole-column ledger;
- A13 tau_surface candidate history.

Accepted RFM state is not mutated. Replay from the same accepted origin is bit-identical.

## Dependency requalification
The exact-head gate also requalified:
- A19 RFM state semantics;
- A20 carrier/checkpoint semantics;
- A25 node sorptivity/hydraulic derivation;
- A25 orchestrator composition.

The earlier run 36876920069 failed before the node-sorptivity oracle because of test-harness source-path/interface declaration errors. Production physics was not falsified. Those harness defects were repaired; exact head d1e33f... then passed.

## Surface-regime boundary
A25 does not reopen A15/A16 surface ownership. Their unchanged canonical qualification remains authoritative:
- only flux-controlled, unponded, runoff-free composition is eligible;
- ponded/head-controlled/runoff-active cases fail closed to the Reference-owned route.

## Zero-RFM boundary
A25 does not change the ordinary matrix route. RFM execution remains an explicit optional layout/configuration. With no admitted RFM dispatch, the canonical Reference path remains unchanged.

## Important admission boundary
A25 qualifies the orchestrator primitive, not backend dispatch.

The A20 backend guard must remain in place until a separate workunit wires this orchestrator into run_trial and proves the full transaction/commit path. Removing the guard without dispatch would be a false admission.

## Decision

    RFM_RUNTIME_ORCHESTRATOR = QUALIFIED
    ACCEPTED_STATE_IMMUTABILITY = QUALIFIED
    REPLAY_IDENTITY = QUALIFIED
    WHOLE_COLUMN_LEDGER = QUALIFIED
    NODE_HYDRAULIC_BINDING = QUALIFIED
    A15_A16_UNSUPPORTED_SURFACE_FAIL_CLOSED = INHERITED_UNCHANGED
    BACKEND_RFM_DISPATCH = NOT YET ADMITTED
    A20_RUNTIME_GUARD = KEEP
    NEXT = PPA-WU05-A26 backend dispatch and guard replacement
