# PPA-WU05-A20 preregistration — dedicated RFM optional-state carrier

Date: 2026-10-01

Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS

Baseline:

    integration/f-ci-canonical@100704c5a7283ae592bfa2104928ac16cd7ba32d

Prerequisite:

    PPA-WU05-A19 CLOSED_CANONICAL_ADMITTED

## Purpose

Integrate the A19 dedicated RFM physical state with the canonical FMR physical
optional-state carrier/checkpoint architecture without yet admitting live RFM
execution.

## Candidate scope

Add a distinct physical layout identity:

    FMR_OPTIONAL_STATE_LAYOUT_RFM = 505002

and a dedicated serialized-backend carrier:

    fmr_b110_rfm_state_t
      extends fmr_b110_physical_state_t
      owns rfm_physical_state_t

The carrier must support:

    committed-state initialization
    polymorphic clone
    committed snapshot
    kernel checkpoint snapshot
    physical storage accounting
    exact temporal identity for identical states

## Storage contract

For an RFM carrier:

    total storage
      = matrix profile storage
      + surface ponding storage
      + A19 RFM fast-domain storage

where:

    RFM storage = mb_water_cm + sum(endpoint_water_cm).

The standard SWAP macropore storage must not be allocated simultaneously.

## Runtime admission boundary

Registering a physical layout ID must not activate a physical execution mode.

A20 SHALL add an explicit run-trial guard:

    optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_RFM
      -> KERNEL_STATUS_NOT_ADMITTED

until a later workunit admits a complete RFM runtime composition.

Thus A20 qualifies carrier/checkpoint semantics only.

## Compatibility boundaries

The initial RFM layout is exclusive of:

    standard SWAP macropore optional state
    fixed-weir surface-water optional state
    snow optional state
    restricted soil-temperature optional state
    Black/Boesten evaporation optional state
    numerical temporal-history continuation

Combined optional physical layouts require separate future contracts.

## Qualification gates

1. runtime-core registry recognizes layout 505002;
2. unknown nearby layout remains rejected;
3. dedicated RFM carrier constructor initializes a committed state;
4. committed snapshot preserves base matrix state and A19 RFM state bitwise;
5. kernel checkpoint snapshot preserves the same values bitwise;
6. mutating caller-owned source objects after construction cannot alter the
   committed/checkpoint carrier;
7. backend source compiles with the new carrier;
8. storage-accounting branch explicitly includes rfm%storage_cm();
9. temporal-identity branch explicitly compares rfm%same_values();
10. run_trial explicitly rejects the RFM layout with KERNEL_STATUS_NOT_ADMITTED.

## Explicit non-claims

A20 does not qualify:

- live RFM stepping;
- external encoded restart-file compatibility;
- RFM + snow/temperature/surface-water combined layouts;
- RFM wall-exchange state;
- preferential outflow/release.

## Exit criteria

One of:

    QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE_RFM_OPTIONAL_STATE_CARRIER
    CLONE_CHECKPOINT_FALSIFIED
    STORAGE_ACCOUNTING_BINDING_FALSIFIED
    RUNTIME_REJECT_GUARD_FALSIFIED
    TRUE_BLOCKER
