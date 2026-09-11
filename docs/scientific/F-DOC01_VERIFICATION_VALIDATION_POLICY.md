# F-DOC01 verification and validation policy

Verification, validation, legacy comparison and cross-solver qualification are separate evidence classes.

## Verification

Question: **did SWAP5 correctly implement the chosen equations, discretisation, algorithm and contracts?**

Evidence can include analytical identities, derivative checks, manufactured solutions, discrete conservation, temporal/spatial refinement, transaction/restart identity, O0/O2 identity, deterministic replay and cross-implementation checks.

A verification node names the scientific/algorithmic claim it tests, case/test ID, oracle, tolerances, source authority, result authority and qualified scope.

## Validation

Question: **does the model describe the real system sufficiently well for a specified application?**

Validation evidence uses observations, experiments, independent datasets or defensible application benchmarks. It always names target outputs, scales, conditions, metrics, data provenance, version and application class. Unvalidated components and outputs remain explicit.

## Evidence that is not validation by itself

- SWAP5 versus SWAP 4.3.1 is `LEGACY_COMPARISON`;
- RossFast versus Full Richards is `CROSS_SOLVER_QUALIFICATION` unless independently connected to observations;
- passing mass balance is `VERIFICATION_CONSERVATION`, not empirical validation;
- code review is software assurance, not physical validation.

## Qualification

Qualification decides whether evidence is sufficient for a narrowly defined scope. F-DOC01 references the exact F-VQ/F-MQ/F-CI/F-TB authority and does not replay or relabel its decision. Validation breadth and qualification scope are both required in fitness-for-purpose records.
