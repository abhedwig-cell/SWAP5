# F-PE-MIQUAL11 preregistration — zero-source/sink invariant optimization

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent authority:

- MIQUAL10: `MIQUAL10_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`.

## Frozen candidate B

Optimize only zero-source/sink handling:

1. validate the zero source/sink invariant once in serialized `prepare_interval`;
2. store that interval-owned eligibility bit in the runtime model;
3. include the bit in moving-interface runtime eligibility;
4. remove repeated zero-array scans from each manager solve;
5. initialize reduced source/sink scratch to zero only on allocation/shape change;
6. do not recopy known-zero arrays on each full/half/half solve.

No manager physics, reconstruction, tolerances, boundaries, eligibility envelope or fallback semantics may change.

## Qualification

Require:

- MIQUAL06 serialized seam gate remains green;
- unchanged MIQUAL09 paired benchmark;
- exact physical equivalence;
- 100% reduced route on benchmark;
- zero fallback/bypass.

Classification:

- `QUALIFIED_MIQUAL11_ZERO_SOURCE_RUNTIME_RECOVERY` if median wall and CPU ratios <1.00;
- `MIQUAL11_OVERHEAD_REDUCED_BUT_NOT_RECOVERED` if improved but still >=1.00;
- `MIQUAL11_ZERO_SOURCE_NO_BENEFIT`;
- `MIQUAL11_SEMANTIC_REGRESSION`;
- `MIQUAL11_EXECUTION_INVALID`.

Production default remains `LEGACY_NUMERICS`.
