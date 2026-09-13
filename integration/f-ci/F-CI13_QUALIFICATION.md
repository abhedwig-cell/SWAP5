# F-CI13 Qualification — Recoverable Physical Trial Status Contract

## Qualified source

Source head: `538d51df4be3780a5bb092767304749dfc800899`.

Canonical workflow run `34104845258`, job `101687946143`, GNU Fortran 13.3.0, reported `FCI13_GATE_PASS`. The complete sequential F-CI03 through F-CI13 dependency chain passed on the same source head.

## Qualified behavior

F-CI13 admits an explicit physical-trial status contract with three categories: success, retryable numerical failure and fatal contract/configuration failure.

The exact legacy HeadCalc terminal route is source-pinned. Nonconvergence above `dtmin` remains an internal SWAP timestep retry. Persistent Richards nonconvergence at minimum timestep is observed through the existing worker-local terminal marker and, on the canonical worker path only, returns before postprocessing and is mapped to retryable numerical failure. The trial physical state is restored and unrounded trial mass is invalidated. Standalone execution continues to use the qualified legacy behavior.

Fatal configuration and `swap_error` routes remain fail-fast and are not reclassified as numerical retries. This avoids wasting retry cycles on invalid model contracts.

The focused O0/O2 executable gate proves success handling, retryable state isolation, fatal status classification and continued fail-closed scalar temporal behavior. No physical formula, convergence tolerance, mass tolerance, calendar rule or retry scaling policy was changed.

## Qualification boundary

This is a qualification of the source-bound status seam and transaction behavior, not yet a hydrological regression of a naturally occurring B1.10 terminal failure. The gate uses a deterministic legacy testdouble to force the retryable outcome. A real B1.10/Hupsel terminal minimum-`dt` case has not yet been deliberately induced.

`execute_reference_interval` therefore remains not admitted. The remaining principal blocker is the scalar temporal-error acceptance policy; optional process temporal characterization and snow/macropore qualification also remain open.

## Formal status

`PASS_RECOVERABLE_TRIAL_STATUS_CONTRACT_REFERENCE_TEMPORAL_POLICY_BLOCKED`
