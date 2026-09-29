# F-PE-NLGLOB14U result — accepted-state moving-interface split evolution

Date: 2026-09-29

Status:

`NLGLOB14U_ACCEPTED_SPLIT_EVOLUTION_WITHOUT_INTERFACE_MOTION`

Qualification authority:

- workflow run: `36603872043`;
- job: `109527798184`;
- conclusion: SUCCESS.

An earlier run `36603790536` failed only because the Python harness used the undefined Fortran intrinsic name `nint`. Commit `36a6cddd1a0a018f945f90c6852d004f1c539992` repaired that instrumentation error without changing hypotheses, gates or numerical formulation.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

## Frozen question

Can the qualified NLGLOB14T split endpoint be repeatedly accepted in a private research trajectory, using the existing dry-phase dynamic-top semantics and ownership derived only from the accepted physical saturated set?

## Coverage

PASS.

All 12 HEAD/RUNOFF x six-dt fixtures reach the frozen `0.05 d` horizon.

Observed totals:

- valid fixtures: 12/12;
- accepted split intervals: 13,148;
- rejected split intervals: 0;
- process failures: 0;
- chatter events: 0;
- interface changes beyond the initial 3/4 face: 0;
- saturated-block disappearance cases: 0.

All endpoint top-boundary evaluations remain on the existing `surface-flux` route.

## Transaction and mass behavior

All accepted intervals satisfy the frozen transaction gates.

Observed maxima across the bank:

- absolute physical mass ledger: about `6.88e-10 cm`;
- nonlinear residual: about `6.74e-11`;
- rollback difference: 0.

Thus the repeatedly accepted split sequence remains finite, conservative and transaction-safe over thousands of intervals.

## Ownership behavior

Every fixture starts NLGLOB14U with:

- upper TG-owned domain: nodes 1:3;
- lower saturated-owned block: nodes 4:16;
- ownership face: 3/4.

At the frozen `0.05 d` horizon every fixture still has exactly:

- saturated nodes 4:16;
- ownership face 3/4.

No reverse motion or oscillation occurs.

Therefore the preregistered positive moving-interface class is not reached, because that class requires at least one accepted interface retreat beyond 3/4.

The frozen classification is:

`NLGLOB14U_ACCEPTED_SPLIT_EVOLUTION_WITHOUT_INTERFACE_MOTION`.

## Dynamic-top preservation

The multi-interval split trajectory does not replay the persistent-KLAG control top-flux sequence.

Instead it reconstructs the current dry, unponded B110 dynamic-top provider semantics from the accepted research state:

- frozen potential evaporation demand from NLGLOB14G/L;
- atmospheric hydraulic evaporation capacity;
- SWKIMPL=0 fixed origin top-node conductivity within each interval;
- current surface-flux selection.

The route remains `surface-flux` for every accepted interval in this bank.

## Control comparison

The split and persistent-KLAG trajectories remain close and the discrepancy decreases strongly with dt.

Maximum matched-state head difference over the remaining horizon:

HEAD:
- `1.17e-2 cm` at dt `2.5e-4 d`;
- `3.68e-4 cm` at dt `7.8125e-6 d`.

RUNOFF:
- `1.13e-2 cm` at dt `2.5e-4 d`;
- `3.54e-4 cm` at dt `7.8125e-6 d`.

Maximum theta differences show the same refinement trend:

- HEAD: about `4.32e-5` to `1.36e-6`;
- RUNOFF: about `3.96e-5` to `1.25e-6`.

This supports stable research accepted-state evolution and dt refinement toward the control trajectory. It does not constitute a separate formal temporal-order qualification.

## Scientific interpretation

NLGLOB14U removes a major uncertainty from NLGLOB14T: split ownership is not merely a one-interval construction.

It can be repeatedly accepted for the entire existing post-retreat horizon without mass drift, transaction leakage, upper-domain saturation re-entry or interface chatter.

However, the existing `0.05 d` horizon contains no second retreat event. This agrees qualitatively with the earlier NLGLOB14L control observation that the final saturated count at `0.05 d` remains 13.

Therefore NLGLOB14U neither qualifies nor falsifies moving-interface motion itself. It qualifies stable accepted split evolution while leaving the interface-motion question observationally unresolved at this horizon.

## Consequence

The next bounded study may extend only the horizon under the same dry forcing and unchanged split formulation to seek the next accepted physical retreat of node 4.

Do not change forcing, thresholds, solver tolerances or ownership rules.

A fixed longer horizon must be preregistered before result exposure.

## Production boundary

Research only.

No production `src/**` change.

No production temporal-ownership policy changed.

`LEGACY_NUMERICS` remains production default.
