# F-VQ03 — F-CI13 Recoverable Status Admission

F-VQ03 consumes the exact qualified F-CI13 production basis without modifying production source.

## Exact basis

- B1.10 oracle
- F-CI13 source `538d51df4be3780a5bb092767304749dfc800899`
- F-CI13 qualification commit `f56c5fe7cdbca36c3403fcd027c5998b0c7578f4`
- canonical workflow `34104845258`, job `101687946143`
- qualified F-VQ02 verifier layer carried forward from `0a042426a83fc8bfbc31f36b67c0d8e49447724c`

## What changes in qualification state

The F-VQ blocker that previously said a recoverable production solver-failure status was absent can now be removed for the declared source-bound contract.

F-CI13 qualifies three status classes on the canonical worker path: success, retryable numerical failure, and fatal contract/configuration failure. Persistent Richards nonconvergence at minimum internal timestep is intercepted before postprocessing, failed-trial physical state is restored, and unrounded trial mass is invalidated before the status is returned as retryable.

This is enough to qualify the status seam and its transaction semantics. It is not enough to claim that a naturally occurring B1.10 hydrological terminal-failure trajectory has been regression-qualified. The executable retryable path was forced with a deterministic legacy testdouble.

## Fail-closed boundary

F-VQ03 therefore keeps these claims blocked:

- a real B1.10 terminal minimum-dt failure qualification fixture;
- scalar temporal-error metric and acceptance tolerance;
- `execute_reference_interval` for B1.10;
- real end-to-end canonical reference execution and production result routing;
- complete snow/macropore storage and failure accounting;
- reentrant parallel legacy-backend qualification.

The synthetic transaction/time harness remains verifier-only and cannot qualify production physics or production mass tolerances.

## Architecture invariants

This work unit directly checks invariants 3, 7, 8, 9, 13, 23, 24, 25, 26, 29 and 30. It preserves the hard separation between physical configuration and numerical policy and does not relax mass-conservation requirements.
