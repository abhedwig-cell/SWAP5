# EB-I15 Candidate-Scoped Bottom Sensible-Energy Evaluator Closure

## Decision

`QUALIFIED_IMPLEMENTATION_BRANCH_CLOSED_PENDING_CANONICAL_ADMISSION`

This decision is effective only when the `EB-I15 bottom sensible energy evaluator` workflow succeeds on the exact branch HEAD containing this document. A green workflow on any earlier SHA is supporting evidence only.

EB-I15 implements the narrow production evaluator frozen by EB-I14. It converts an already-qualified EB-I13 accepted bottom water-thermal candidate into an outward-positive liquid-water sensible-energy result. It does not invoke the serialized runtime, commit an energy ledger, publish accepted energy, supply external groundwater temperature, or alter the governing soil-temperature equation.

## Production scope

The production delta contains exactly two modules.

`src/process/mod_liquid_water_sensible_enthalpy.f90` is the exact source blob previously qualified by EB-I04, SHA `2247370ee34fac73a0e2d0b9fa15e171467aded3`. EB-I15 requalifies that exact primitive on its current base rather than duplicating the algebra in runtime code.

`src/runtime/mod_fmr_bottom_sensible_energy.f90` performs candidate-scoped composition only. It depends on the public EB-I13 bottom thermal carrier contract and the generic liquid-water sensible-enthalpy primitive. It has no dependency on F-KT internals, Full Richards, HeadCalc, MODFLOW or file I/O.

## Qualified semantics

For every thermally complete local-outflow sample, the evaluator uses the EB-I14 reference rule:

`E_i = 0.01 * rho_w * c_p_w * Q_i * (T_bottom,end,i - T_ref)` [J/m2].

The complete candidate result is the sum over selected accepted-route samples. The implementation does not use an outer aggregate water transfer multiplied by one final outer temperature and does not use the local start temperature in the frozen current-reference rule.

Exact zero transfer contributes exactly zero without requiring a donor temperature.

For a nonzero inward sample, current EB-I13 provenance identifies the donor as external but does not contain an external donor temperature. EB-I15 therefore returns `FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR`, exposes no complete total, and never substitutes local SWAP temperature or zero enthalpy. A local-outflow subtotal may remain available as explicit diagnostics, but it cannot be queried as the complete bottom-energy total.

Invalid candidates, invalid thermodynamic parameters, invalid sample semantics and nonfinite arithmetic fail closed.

## Qualification

The EB-I15 gate proves at both `-O0` and `-O2`:

- exact EB-I04 source-blob reuse;
- sample-wise terminal-donor algebra;
- an adversarial difference from aggregate-water-times-final-temperature;
- independence from the stored local start temperature;
- exact-zero behavior;
- fail-closed external inward provenance;
- explicit unavailability of an incomplete total;
- diagnostic local subtotal without total masquerading;
- invalid-input failure semantics;
- the reference-temperature shift identity;
- exact O0/O2 output identity;
- dependency direction away from kernel/solver internals;
- all thirty architecture invariants;
- an exact changed-path allowlist for the workunit.

The workflow additionally reruns the full EB-I13 carrier/hydrology qualification and FPM08D7 runtime compile, transactional-owner and restart-owner preservation gates. Therefore the energy evaluator is not accepted merely because its isolated arithmetic tests pass.

## Architecture disposition

`tests/eb/EB-I15_ARCHITECTURE_AUDIT.json` records PASS or PRESERVED for all thirty SWAP architecture invariants.

In particular:

- no second kernel or solver path exists;
- no persistent per-column energy history is introduced;
- carrier and evaluation scratch remain worker/call local;
- generic time and arbitrary coupling windows remain intact;
- water mass is never recomputed or rebooked;
- evaluation requires no extra physical solve;
- alternative soil-water solvers can in principle provide the same public accepted-route carrier contract;
- MODFLOW-cell mapping, tile fractions and deep-vadose composition remain outside the SWAP kernel;
- optional energy accounting has zero cost when it is not invoked.

## Hard nonclaims

EB-I15 does not qualify:

- automatic evaluator invocation by the serialized runtime;
- accepted energy commit, rollback or publication;
- an energy ledger with restart semantics;
- external groundwater or deep-vadose donor-temperature physics or binding;
- complete energy evaluation for inward bottom water;
- advective-energy feedback into the physical soil-temperature solve;
- internal soil-face advective heat transport;
- energy terms for drainage, roots, irrigation, precipitation, runoff, ponding, evaporation, vapor, snow or ice;
- higher-order temporal advective-energy accuracy;
- a closed soil or land-column energy balance;
- canonical admission.

## Next boundary

The next scientific/runtime gap is not another local-outflow formula. It is explicit external donor-temperature ownership for inward water.

That capability must remain generic. A runtime/coupler may obtain donor temperature from groundwater, a deep-vadose transfer component or another external component, but SWAP must not learn MODFLOW-cell identity, deep-vadose routing or tile composition. Any external temperature must be bound to the same accepted transfer/sample identity and must remain fail closed when unavailable.

Accepted energy commit/publication is a separate transactional integration boundary and should not be conflated with the external-donor science unless a later workunit explicitly qualifies both.
