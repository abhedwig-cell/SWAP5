# EB-I17 Closure

Decision: `QUALIFIED_IMPLEMENTATION_BRANCH_CLOSED_PENDING_CANONICAL_ADMISSION` when, and only when, the EB-I17 qualification workflow succeeds on the exact unchanged branch head containing this file.

No post-qualification status commit is required. This avoids moving the authority after exact-head CI succeeds.

## Qualified implementation scope

EB-I17 implements the EB-I16 source-agnostic external bottom thermal binding contract as:

- a compact candidate-scoped runtime binding bundle keyed by positive opaque candidate lineage plus one-based sample ordinal;
- finite external donor temperature in degrees Celsius;
- optional non-negative opaque provenance token;
- duplicate, invalid-lineage, invalid-ordinal, nonfinite, and capacity failure statuses;
- zero-capacity bundle support without record allocation;
- an opt-in external-aware sensible-energy evaluator route.

The existing `evaluate_fmr_bottom_sensible_energy(candidate, parameters, result)` route remains public and retains its EB-I15 fail-closed behavior for unresolved external inflow. The new route calls that evaluator first and resolves only the external-donor gap.

## Water and transaction ownership

The binding bundle owns no water amount or flux. Accepted `bottom_outward_exchange_native` in the EB-I13 thermal carrier remains the sole water-transfer authority used by energy accounting.

Candidate lineage is provided by the runtime/coupler caller. EB-I17 does not invent lineage from time or flux values and does not yet implement the runtime association that supplies the authoritative lineage identity.

Bindings are candidate-scoped provenance only. They are not committed SWAP physical state and are not added to restart state.

## Source independence

The binding module has no dependency on MODFLOW, groundwater exchange types, deep-vadose components, HeadCalc, Richards internals, files, or tile composition. The external component or coupler remains responsible for supplying an already-qualified donor-temperature scalar for the exact accepted sample.

## Fail-closed behavior

A missing required binding preserves the EB-I15 incomplete-external-donor result and exposes no total energy. A foreign lineage, wrong-class binding, extra binding, duplicate insertion, or nonfinite donor temperature cannot produce a complete total.

Exact-zero and local-outflow samples require no external binding. An external binding attached to such a sample is invalid rather than silently ignored.

No thermal binding failure mutates accepted hydrologic state or water exchange.

## Hard nonclaims

EB-I17 does not claim:

- automatic runtime/coupler creation of the binding bundle;
- automatic association between the thermal candidate and an authoritative runtime candidate lineage;
- MODFLOW-specific thermal coupling;
- accepted energy publication;
- energy-ledger or restart persistence;
- governing heat or soil-water feedback;
- higher-order temporal quadrature;
- whole-system energy closure;
- canonical admission.

## Next boundary

The next admissible workunit is the runtime association seam: compose or obtain the authoritative accepted-candidate lineage, accept optional provider-supplied external thermal bindings, and invoke the external-aware evaluator for the matching completed thermal candidate. Publication and governing-physics integration remain separate later boundaries.