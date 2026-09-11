# F-TB01 — Oracle Policy

## Purpose

Every scientific assertion SHALL identify an oracle class, its provenance and its scope. Reproducibility alone does not make a result scientifically authoritative.

## Hierarchy

Highest applicable authority wins:

1. `O1_MATHEMATICAL_EXACT` — exact analytical identity or exact discrete invariant.
2. `O2_MANUFACTURED_SOLUTION` — manufactured solution with controlled forcing/source terms and known target.
3. `O3_INDEPENDENT_NUMERICAL_REFERENCE` — independent implementation/reference computation whose numerical uncertainty is bounded.
4. `O4_QUALIFIED_FULL_RICHARDS_REFERENCE` — qualified SWAP5 Full Richards reference within its admitted scope.
5. `O5_LEGACY_SWAP431_SOURCE_BOUND` — frozen SWAP 4.3.1 result only where provenance is exact and the legacy behaviour is scientifically acceptable.
6. `O6_PROPERTY_INVARIANT` — conservation, monotonicity, bounds, finiteness, transaction immutability, determinism or other invariant/property oracle.
7. `O7_CROSS_SOLVER_CONSISTENCY` — agreement between solvers within an independently governed tolerance.

A lower oracle SHALL NOT override a contradiction from a higher applicable oracle. Cross-solver agreement cannot prove both solvers correct when an exact/manufactured/reference oracle disagrees.

## Oracle requirements

Each registered oracle binding records:

- oracle class and version;
- physical/numerical scope;
- source/provenance authority;
- generation method where relevant;
- uncertainty or exactness statement;
- applicable tolerance IDs;
- known exclusions/defects;
- evidence lineage.

## Legacy oracle restrictions

`O5_LEGACY_SWAP431_SOURCE_BOUND` is not a generic golden-output authority. Each legacy comparison SHALL carry one classification:

- `EXACT_EQUIVALENCE_EXPECTED`
- `NUMERICAL_EQUIVALENCE_EXPECTED`
- `INTENTIONAL_PHYSICS_CHANGE`
- `LEGACY_DEFECT_CORRECTED`
- `NOT_COMPARABLE`

Known legacy defects must be documented and excluded from golden preservation unless the purpose is explicitly defect characterization. Legacy `.swp` or other file parsing belongs in an adapter/harness, never in the SWAP5 kernel.

## Independent-reference discipline

An `O3` oracle must be meaningfully independent of the code path under test. Reusing the same formula, lookup table, derivative or factorization without an independent derivation is not an independent oracle. Finite-difference checks can independently challenge an analytical derivative when step-size convergence is demonstrated and discontinuities are classified.

## Alternative soil-water solvers

Full Richards is the default scientific reference oracle (`O4`) when no higher oracle applies. Alternative solvers qualify only for explicitly bounded scopes and retain a hard mass gate. Allowed scope outcomes are `ADMITTED`, `ADMITTED_WITH_BOUNDED_FALLBACK`, `UNSUPPORTED`, and `FAIL`. An alternative solver may outperform the reference but may not silently alter physics to obtain performance.

## Oracle versioning

A semantic change in target values, generation method, physical interpretation, uncertainty or accepted domain creates a new oracle version. Previously frozen historical evidence remains bound to its old oracle version; moving-current preservation requires an explicit current binding.