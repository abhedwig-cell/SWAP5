# F-PE-TIMEINT15 authority reconciliation

Date: 2026-09-29

Status: `PRE_RESULT_SCOPE_RECONCILED`

Original branch base:

`integration/f-ci-canonical@295a13b83ac44efa7b2ff0e0d2fb7c86e6b31e70`

Current canonical before TIMEINT15 result exposure:

`integration/f-ci-canonical@a5f127e2f42329914826a835d760102be6fee71f`

## Canonical change

Canonical advanced after the first TIMEINT15 preregistration through an expanded TIMEINT14 architecture closeout.

No Richards production source changed in that canonical delta.

The new closeout makes a stronger algebraic decision than the earlier TIMEINT14 handoff:

- standard BDF2 is algorithmically conservative in a history-dependent storage;
- a recursive BDF2 flux quadrature necessarily imports prior-interval history into the current interval;
- therefore it cannot satisfy the existing exact physical accepted-interval mass contract while retaining ordinary component-wise physical flux meaning;
- an unchanged-BDF2 reconstruction that forces interval closure is not an admissible physical transaction ledger.

## Consequence

The original TIMEINT15 candidate, all-storage BDF2 plus recursive physical-flux quadrature, is withdrawn before any candidate result exposure.

No result from that formulation exists.

TIMEINT15 is re-scoped to the preferred successor explicitly identified by current canonical authority:

a conservative second-order one-step temporal method whose natural balance is

`physical_storage_end - physical_storage_start = physical_interval_flux_integral`.

The first candidate family is trapezoidal / Crank-Nicolson style integration with weak conductivity coupling.

This is a preregistration correction caused by new canonical authority, not a post-result gate change.
