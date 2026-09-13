# F-KT18 - Fail-Closed Mass Completeness Transaction Admission Closure

Date: 2026-09-13

## Decision

`QUALIFIED_MASS_COMPLETENESS_FAIL_CLOSED_TRANSACTION_ADMISSION_READY_FOR_INDEPENDENT_QUALIFICATION`

F-KT18 closes the F-KT17-G01 implementation gap on its candidate branch. It does not claim independent qualification, current-canonical admission, or 100 percent completion of the frozen F-RG01 D01 scope.

## Authority and frozen scope

Direct finding authority:

- F-KT17 branch: `work/f-kt17-kernel-transactions-generic-time-mass-v1-completion-audit`
- F-KT17 authority commit: `c14bd8c7f67e015bf1bd4bdcfa88eb97470194da`
- F-KT17 authority tree: `fbf1fe0b6cc853de5ce375830a98251753a598b3`
- blocking gap: `F-KT17-G01`
- primary class: `MASS_GAP`
- secondary class: `IMPLEMENTATION_GAP`

The frozen requirement is unchanged: an interval with explicitly incomplete water-mass accounting must never become physically accepted or committable, even when the residual formed from the known terms is within tolerance.

No denominator was changed. No 99.x completion percentage is introduced.

## Start and current canonical authority

F-KT18 started from and, at owner closeout, current canonical remained:

- branch: `integration/f-ci-canonical`
- SHA: `c19a04721a05c6a00ba264e7477969807dcb258f`
- tree: `5342833575484452b34606f8854ff3f5a542e452`
- message: `F-CI56: finalize predictor-corrector canonical admission closeout`

The F-KT18 qualified candidate source head is:

- branch: `work/f-kt18-fail-closed-mass-completeness-transaction-admission`
- qualified source/evidence head: `623e633b1f8451bd849f590f796806f11e1ecbdf`
- tree: `47826cb69e04c46b8739bcf953ac26db80b5ff3e`
- production remediation commit: `29af8fa9b62f3b87fe8703f2a1726ba8daad1b44`

## Defect reproduced from current canonical

Both production transaction admission routes in `src/transaction/mod_transaction_reference.f90` could pass the mass gate from residual magnitude alone before completeness, missing-contribution mask, and numerical validity became hard admission conditions:

1. external full versus two-half-step route;
2. model temporal-certificate route.

The canonical code already propagated both half-step outcomes into its diagnostic accounting. F-KT18 does not claim a missing half1 diagnostic bug. The defect was that completeness, a zero missing mask, and finiteness were diagnostic rather than mandatory for physical acceptance.

Consequently, the generic transaction contract could admit an interval with an incomplete ledger if its known-term residual happened to satisfy the mass tolerance. That violates SWAP architecture invariant 13 even if downstream runtime diagnostics later report incomplete accounting.

## Production remediation

Exactly one production file differs from the frozen canonical base:

- `src/transaction/mod_transaction_reference.f90`

Canonical-to-qualified-candidate production diff for that file:

- additions: 65
- deletions: 23
- changed lines: 88

No production source changed under runtime, kernel, solver, process, adapter, legacy, or reference.

The remediation makes mass admission fail closed in both transaction routes. A mass-acceptable trial now requires all relevant conditions before acceptance:

- mass accounting completeness is true;
- aggregate missing-contribution mask is `MASS_MISSING_NONE`;
- relevant storage, mass-input, mass-output, and residual values are finite;
- absolute mass residual is within the configured mass tolerance.

For the external full-versus-two-half route the hard gate covers start storage, full-trial end storage/outcome, accepted half-path end storage, and both half-step outcomes. Nonfinite accounting is represented with `MASS_MISSING_NONFINITE`. The model-certificate route applies the same fail-closed rule to its accepted path.

Incomplete accounting now follows the existing mass-rejection path, bounded retry policy, and checkpoint rollback semantics. No reverse-physics rollback was introduced. No new physics, API, ledger architecture, solver policy, coupling policy, or denominator was introduced.

A kernel commit-level defense was not added because the transaction admission seam now prevents the incomplete-ledger state from becoming an accepted candidate. Adding a second generic mass contract at commit would have expanded scope without evidence that the transaction-level repair was insufficient.

## Owner regression qualification

Exact source qualification run:

- GitHub Actions run: `34752638317`
- job `fail-closed-mass-completeness`: `103711635575`
- conclusion: `SUCCESS`
- exact qualified head at job start and end: `623e633b1f8451bd849f590f796806f11e1ecbdf`
- compiler: GNU Fortran 13.3.0 on Ubuntu 24.04
- modes: O0 and O2 with identical oracle output

Verified regression markers include:

- `FKT18_INCOMPLETE_ZERO_RESIDUAL_FAIL_CLOSED=PASS`
- `FKT18_RETRY_EXHAUSTION_AND_STATE_IMMUTABILITY=PASS`
- `FKT18_NONZERO_MISSING_MASK_FAIL_CLOSED=PASS`
- `FKT18_COMPLETE_LEDGER_WITHIN_TOLERANCE_ACCEPTS=PASS`
- `FKT18_COMPLETE_LEDGER_OUTSIDE_TOLERANCE_REJECTS=PASS`
- `FKT18_ALTERNATIVE_SOLVER_INCOMPLETE_LEDGER_FAIL_CLOSED=PASS`
- `FKT18_COMPLETE_MODEL_CERTIFICATE_ACCEPTS=PASS`
- `FKT18_NONFINITE_MASS_FAIL_CLOSED=PASS`
- `FKT18_MASS_COMPLETENESS_O0_O2_IDENTITY=PASS`
- `FKT18_MASS_COMPLETENESS_OWNER_GATE=PASS`

The retry-exhaustion case verifies exact committed-state immutability across repeated incomplete-ledger attempts and confirms that no rejected physical state accumulates. The accepted complete-ledger cases verify that valid accounting remains admissible. The alternative solver path verifies that the fail-closed rule is generic rather than restricted to one solver implementation.

## Preservation qualification on the changed transaction source

The same exact-head Actions run `34752638317` also completed job `current-preservation` (`103711635462`) with `SUCCESS` on `623e633b1f8451bd849f590f796806f11e1ecbdf`.

The preservation runner compiles the changed transaction source together with current production composition and re-executes the relevant established oracles under O0/O2. It produced:

- `FKT18_FKT15_SOLVER_SERVICE_PRESERVATION=PASS`
- `FKT18_RESTART_SERIALIZED_MULTISWAP_PRESERVATION=PASS`
- `FKT18_PRODUCTION_PARALLEL_RUNTIME_PRESERVATION=PASS`
- `FKT18_FVQ64_INDEPENDENT_SEQUENCE_O0=PASS`
- `FKT18_FVQ64_INDEPENDENT_SEQUENCE_O2=PASS`
- `FKT18_FVQ64_COUPLING_SEMANTICS_PRESERVATION=PASS`
- `FKT18_CURRENT_PRESERVATION_OWNER_GATE=PASS`

The preserved authorities include:

- F-KT15 solver-service/reference-model composition: `48336cb7f14e9246b03c23e549fe7354a93f9e6b`
- F-KT15R recomposition authority: `1b3d8ba6cc70d74a124f20f01f0c47a102763ae0`
- F-KT15R canonical merge: `9465be74c01fe6455466e5ba7f62a761986ad450`
- F-KT16 state/persistence/restart: `37a91f16078badaa675235f1230d225a21c9e010`
- Serialized MultiSWAP R1 authority: `c70b3c7ad8267e7eb77b98cf142fa66e7e506cee`
- F-VQ64 independent predictor-corrector authority: `466119889a3f09b33ede638322e897bded2472a3`

For F-VQ64, the frozen independent program is assertion-driven and emits only its final success marker. It was re-executed against the F-KT18 transaction source under O0 and O2. Its embedded assertions cover rejected-window retry from unchanged committed origin, generic noncalendar windows, accepted exchange versus ledger exchange, exclusion of rejected mass, one accepted commit boundary, rejected-state nonpublication, and `q_groundwater = -q_swap`. This is valid preservation evidence, but because F-KT18 itself is authored and qualified in this workunit, it is not counted as new independent qualification of F-KT18.

## Architecture invariant assessment

For the qualified F-KT18 candidate:

- invariant 7, transactional time steps: PASS at owner qualification level;
- invariant 8, cheap recalculation and correct committed origin: PASS at owner qualification level;
- invariant 9, generic time: preserved;
- invariant 11, coupling as core functionality: preserved by F-VQ64 replay;
- invariant 12, explicit groundwater interface contract: preserved by F-VQ64 replay;
- invariant 13, mass conservation absolute: PASS for the F-KT17-G01 candidate closure at owner qualification level;
- invariant 14, interface sensitivities: preserved through unchanged solver-service composition;
- invariant 16, MultiSWAP primary use case: preserved by serialized and production-parallel requalification;
- invariant 23, physics versus solver policy separation: preserved;
- invariant 25, reference mode: preserved;
- invariant 26, diagnostics: preserved;
- invariant 29, no silent dependencies: preserved.

For current canonical `c19a04721a05c6a00ba264e7477969807dcb258f`, invariant 13 remains open/failed under F-KT17 because the F-KT18 production fix has not been admitted there.

## Mass gate and candidate reachability

Candidate mass hard gate: PASS at owner qualification level.

Current-canonical mass hard gate: FAIL under F-KT17-G01 until admission of independently qualified remediation.

The new incomplete-ledger rejection cannot reach an accepted transaction result, so normal candidate materialization and physical commit are unreachable from that rejection path. Existing rollback restores the checkpoint and bounded retries restart from the committed physical origin. No reverse calculation is used to undo a rejected physical trial.

## Independent qualification and canonical admission

Independent F-KT18 qualification: **NOT YET PERFORMED**.

Current-canonical admission of F-KT18: **NOT PERFORMED**.

Historical independent evidence such as F-VQ64 remains an important preservation oracle, but it is not relabeled as independent qualification of this new transaction-source modification.

Therefore the stronger status `QUALIFIED_KERNEL_TRANSACTIONS_GENERIC_TIME_MASS_V1_100_PERCENT_COMPLETE` is not authorized by this workunit.

## F-RG01 D01 completion accounting

Frozen denominator: 8.

Historical pre-audit authority recorded D01 as 8/8, 100 percent, but F-KT17 explicitly suspended the qualified 100 percent claim after discovery of F-KT17-G01. F-KT18 does not change that denominator and does not invent an intermediate percentage.

At this closeout:

- F-KT17-G01 implementation gap: CLOSED ON F-KT18 CANDIDATE;
- independent qualification hard gate: OPEN;
- current-canonical admission hard gate: OPEN;
- D01 qualified 100 percent: NO.

D01 may return to 8/8, 100 percent only after the F-KT18 source is independently qualified against the then-current canonical composition, admitted to current canonical, and no new hard gate is open.

## Remaining closure gaps

There are no known remaining production implementation gaps inside the frozen F-KT17-G01 remediation scope on this candidate.

Two governance gates remain:

1. independent qualification of the F-KT18 candidate using qualification-owned evidence rather than owner acceptance of this report;
2. current-canonical admission and post-admission reconciliation, including a live confirmation that invariant 13 and the frozen D01 mass gate are closed on canonical.

These are not permission to expand scope, redesign the API, change the frozen denominator, or weaken mass conservation.

## Final F-KT18 workunit status

`QUALIFIED_MASS_COMPLETENESS_FAIL_CLOSED_TRANSACTION_ADMISSION_READY_FOR_INDEPENDENT_QUALIFICATION`
