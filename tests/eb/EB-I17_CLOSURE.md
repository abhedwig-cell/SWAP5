# EB-I17 Closure

Decision: `QUALIFIED_IMPLEMENTATION_BRANCH_CLOSED_PENDING_CANONICAL_ADMISSION` when, and only when, the EB-I17 qualification workflow succeeds on the exact unchanged branch head containing this file.

No post-qualification status commit is required. This avoids moving the authority after exact-head CI succeeds.

## Qualified implementation scope

EB-I17 implements the storage/evaluation portion of the EB-I16 source-agnostic external bottom thermal binding contract as:

- a compact runtime binding bundle keyed by a positive caller-supplied opaque binding token plus one-based sample ordinal;
- finite external donor temperature in degrees Celsius;
- optional non-negative opaque provenance token;
- duplicate, token-mismatch, invalid-ordinal, nonfinite, and capacity failure statuses;
- zero-capacity bundle support without record allocation;
- an opt-in external-aware sensible-energy evaluator route.

The existing `evaluate_fmr_bottom_sensible_energy(candidate, parameters, result)` route remains public and retains its EB-I15 fail-closed behavior for unresolved external inflow. The new route calls that evaluator first and resolves only the external-donor gap.

## Water and transaction ownership

The binding bundle owns no water amount or flux. Accepted `bottom_outward_exchange_native` in the EB-I13 thermal carrier remains the sole water-transfer authority used by energy accounting.

The binding token is supplied by the runtime/coupler caller. EB-I17 verifies consistency between the evaluator call and the bundle, but the thermal candidate itself does not yet carry or expose that token. Therefore EB-I17 does **not** prove that a caller-supplied token belongs to a particular thermal candidate. Authoritative candidate-token association is the next runtime boundary.

This distinction is intentional. Kernel candidate lineage plus origin revision plus interval is not by itself sufficient to distinguish every retry/trial candidate from the same committed origin, so EB-I17 does not manufacture an identity from those fields.

Bindings are temporary provenance only. They are not committed SWAP physical state and are not added to restart state.

## Source independence

The binding module has no dependency on MODFLOW, groundwater exchange types, deep-vadose components, HeadCalc, Richards internals, files, or tile composition. The external component or coupler remains responsible for supplying an already-qualified donor-temperature scalar for the exact accepted sample.

## Fail-closed behavior

A missing required binding preserves the EB-I15 incomplete-external-donor result and exposes no total energy. A caller-token mismatch, wrong-class binding, extra binding, duplicate insertion, or nonfinite donor temperature cannot produce a complete total.

Exact-zero and local-outflow samples require no external binding. An external binding attached to such a sample is invalid rather than silently ignored.

No thermal binding failure mutates accepted hydrologic state or water exchange.

## Hard nonclaims

EB-I17 does not claim:

- automatic runtime/coupler creation of the binding bundle;
- authoritative association between the thermal candidate and the caller-supplied binding token;
- a unique identity derived solely from kernel lineage, origin revision, or interval;
- MODFLOW-specific thermal coupling;
- accepted energy publication;
- energy-ledger or restart persistence;
- governing heat or soil-water feedback;
- higher-order temporal quadrature;
- whole-system energy closure;
- canonical admission.

## Next boundary

The next admissible workunit is the runtime association seam: provide a genuinely authoritative candidate-scoped identity or accepted-transaction identity, associate it with the completed thermal candidate and optional provider bundle, and invoke the external-aware evaluator through that proven association. Publication and governing-physics integration remain separate later boundaries.