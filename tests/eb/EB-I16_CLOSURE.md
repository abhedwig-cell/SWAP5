# EB-I16 Closure

Decision: `QUALIFIED_DESIGN_BRANCH_CLOSED_PENDING_CANONICAL_ADMISSION` when, and only when, the EB-I16 qualification workflow succeeds on the exact unchanged branch head containing this file.

This conditional wording is intentional: no follow-up governance commit is required after the exact-head workflow turns green.

## Qualified scope

EB-I16 freezes a source-agnostic runtime/coupler contract for external bottom liquid-water donor-temperature provenance. It establishes that external temperature is supplemental metadata bound to an already accepted bottom-transfer sample by opaque accepted-candidate lineage plus sample ordinal.

The accepted bottom water transfer remains the sole mass authority. EB-I16 does not duplicate or alter the groundwater coupling contract, groundwater exchange service, or EB-I13 thermal carrier.

## Frozen safety properties

A valid external thermal binding:

- resolves exactly one external-inflow sample of one accepted candidate;
- carries finite donor temperature and optional opaque provenance;
- owns no water amount or flux;
- is source-agnostic to MODFLOW, deep-vadose, tile composition, and other external components;
- cannot be matched solely by numeric interval, transfer amount, sign, or donor class;
- is invalid if missing, duplicate, stale, foreign-lineage, wrong-ordinal, nonfinite, or attached to a non-external sample;
- never falls back to local bottom temperature, T_ref, zero, hydraulic state, neighboring samples, or a silent window average.

Exact zero transfer requires no donor temperature. Thermal incompleteness keeps the energy total unavailable but, while energy remains diagnostic/non-governing, cannot retroactively reject or mutate accepted conservative hydrology.

## Authority preservation

The qualification gate requires byte-identical preservation relative to the EB-I15 base for:

- `src/runtime/mod_fmr_bottom_thermal_carrier.f90`;
- `src/runtime/mod_groundwater_coupling_contract.f90`;
- `src/runtime/mod_groundwater_exchange_service_contract.f90`.

It also forbids every production-source delta in this workunit.

## Hard nonclaims

This closure does not claim a production binding data type, automatic external-temperature retrieval, MODFLOW thermal physics, publication of accepted energy, restart persistence of energy, governing thermal feedback, higher-order time integration, whole-system energy closure, or canonical admission.

## Next boundary

The next admissible implementation step is a compact candidate-scoped binding bundle plus EB-I15 evaluator extension. It must preserve water ownership, enforce lineage/ordinal identity, remain optional and source-agnostic, and obtain independent exact-head qualification before publication or governing-physics integration.